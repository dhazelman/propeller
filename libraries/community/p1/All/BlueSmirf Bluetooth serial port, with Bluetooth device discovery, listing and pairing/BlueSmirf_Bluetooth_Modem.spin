{{
*****************************************
* BlueSmirf_Bluetooth_Modem.spin        *
* Author: Mathew Brown                  *
***************************************** 
* Allows for discovery, and connection  *
* to serial over Bluetooth using        *
* BlueSmirf Bluetooth Modem hardware    *
* Methods included for returning a list *
* of discovered devices, and pairing    *
* with a bluetooth device by 'name'     *
*****************************************   
* Has method dependencies & calls to    *
* FullDuplexSerial, for host comms for  *
* bluetooth modem configuration.        *
* Additionally, includes 'pass through' *
* serial methods, for native port access*
* Requires 1 cog for serial driver      *
*                                       *
* Also has method dependencies & calls  *
* to 'StringBuilder', for low level     *
* string assembly, through character or *
* 'string to be appended' concation     *
*                                       *
*                                       * 
* See end of file for terms of use.     *
*****************************************
}}

CON

  'A string array of 10 elements, each of 80 bytes
  InqReplyArrayElements = 10 
  InqReplyStringSize = 80

VAR 'Object scoped var space


  byte RxStrBuff[InqReplyStringSize] 

  byte BtAddrStrArray[InqReplyStringSize*InqReplyArrayElements]

  byte FoundDevices
  long SerialTimeOut
  
           
OBJ 'Included object referencing       
  BtSerial : "FullDuplexSerial"
  SB : "StringBuilder"

DAT 'Comms init and config routines...

PUB Init(IntMaster,StrPincode) 'Initialise Bluesmirf method, and hardware

  SerialTimeout := 2000
  
  WaitMS(2000)

  ''Put into command mode
  CommandMode

  ''Restore factory defaults (forgets prior pairing too!!)
  ''SendCmd(string("SF,1")) 'Send command for restore factory settings
    
  ''Disable configuration timer, on local (rs232 host) only .. (prevents $$$ accidently recieved via Bluetooth entering device into config mode)
  SendCmd(string("ST,253")) 'Send command for continious configuration local (rs232 host) only

  SendCmd(string("SU,57")) 'Send command for continious configuration local (rs232 host) only 
  SetMasterSlaveRole(IntMaster) 'Set as master/slave
  SetPinCode(StrPincode) 'Set pin code
  
  RebootDevice
  
DAT 'Command/data mode switching routines...

PUB CommandMode 'Put Bluesmirf into command (config) mode

  BtSerial.Str(string("$$$"))
  WaitMs(1200) 'Wait just over 1 sec to ensure no extra data can be transmitted to module within a 1 sec window
  ''Datasheet indicates data received in less than 1 sec cancels mode set request, so module stays 'data transparent'
  GetReply 

  'Send a couple of Cr terminated empty lines (device replies with '?') just to make sure we're talking
  repeat 2
    SendCmd(0)


   
PUB ExitCommandMode 'Put Bluesmirf into non-command (transparent data) mode

  SendCmd(string("---"))

PUB RebootDevice 'Force a hard reboot of device (settings changes on effective after rebooting)

  SendCmd(string("R,1")) 
  WaitMS(1500)
  ''BtSerial.Start(_RxPin,_TxPin,0,115200)
     
DAT 'Generic command sending methods..

PUB SendCmd(StrPtr) 'Send a command, passed by string pointer (if address passed is 0, send a plain Cr {wake-up} command with no preceeding parameter string

  BtSerial.RxFlush
  If StrPtr
    BtSerial.Str(StrPtr)
  BtSerial.Tx(13)
  result := GetReply
  WaitMs(50)
  
PUB SetMasterSlaveRole(EnumMSRole) 'Set module role as master or slave
'' Passed value for EnumMSRole..
'' 0 = Slave
'' 1 = Master
'' 2 = Trigger
'' 3 = Autoconnect Master
'' 4 = Autoconnect DTR  (default/out-of-box setting)
'' 5 = Autoconnect ANY
'' 6 = Pairing
''
'' See Bluesmirf datasheet for master/slave role explanations


  SB.New                                                'New blank string within string builder class
  SB.AddStr(string("SM,"))                              'Add Master/Slave role command and comma delimiter
  SendCmd( SB.AddChar(EnumMSRole+"0") )                 'Add passed value as an ASCII numeric digit, and send the command


PUB SetAuthenticationMode(EnumAuthMode) 'Set connection authentication moce
'' Passed value for EnumMSRole..
'' 0 = Open mode (no authentication)
'' 1 = SSP Keyboard (default/out-of-box setting) 
'' 2 = SSP 'Just works' mode
'' 4 = Force PIN code entry mode
''
'' See Bluesmirf datasheet for master/slave role explanations

  SB.New                                                'New blank string within string builder class
  SB.AddStr(string("SA,"))                              'Add Set authentication mode command and comma delimiter
  SendCmd( SB.AddChar(EnumAuthMode+"0") )               'Add passed value as an ASCII numeric digit, and send the command


PUB SetPinCode(StrPincode) 'Set pairing pin code

  SB.New                                                'New blank string within string builder class
  SB.AddStr(string("SP,"))                              'Add set pin command and comma delimiter
  SendCmd( SB.AddStr(StrPincode) )                      'Add pincode string, and send the command

    
DAT 'Inquiring, and pairing methods..

PUB InquireAllBtDevices(TimeOutSec)|DestPtr,Index  'Enquire all available bluetooth devices, populating address list


  '***********************************************************
  ''Limit passed parameters to sensible ranges

   TimeOutSec #>= 2 'Floor (min) value is 2
   TimeOutSec <#= 30 'Ceiling (max) value is 30    
    
  '***********************************************************
  ''Prepare buffers etc for inquiry...

  'Pointer initialised to begining of huge byte array (can be indexed as array elements, by offset multiplication)
  DestPtr := @BtAddrStrArray
    
  'Pre-fill the array with a full null string
  ByteFill (DestPtr, 0, (InqReplyStringSize*InqReplyArrayElements) )
   
  'Flush any errant responses from the Rx buffer
  BtSerial.RxFlush
  
  'Set method scoped variable found devices variable to zero, none found yet...
  FoundDevices := 0

  '***********************************************************
  ''Send Inquire command
  
  SerialTimeout := (TimeOutSec+3)*1000           'Set Comms Rx timeout 3 sec over inquiry time, to allow command to execute

  SB.New                                                'New blank string within string builder class
  SB.AddStr(string("I,"))                              'Add Master/Slave role command and comma delimiter
  SendCmd( SB.AddDec(TimeOutSec) )                 'Add passed value as an ASCII numeric digit, and send the command

  '***********************************************************
  ''Parse response 1st line (confirmation that an inquiry was requested)
  
  'Now match the 1st received reply string .. Should be 'Inquiry,COD=###' (###=number)
  If RxStrBuff[0] <> "I"
    Return 0 'Return 0 devices found as a failure state
    
  'Got here ... So ... Fairly confident that I'm dealing with correctly formatted reply

  '***********************************************************
  ''Parse response 2nd line (indicates how many Bluetooth devices found)
 ' Return @RxStrBuff 
  'Get second line of reply ...  should be either...
  ' .. 'No devices found' 
  ' .. 'Found #' (#= single digit number 0..9 ASCII)
  GetReply                                              'Receive this line of reply (into RxStrBuff byte array)
      
  If RxStrBuff[0] <> "F"  ' .. 'No devices found' .. no further lines will be recieved after this...
    FoundDevices := 0
    Return 0
        
  FoundDevices := RxStrBuff[6]-"0"                      'Char 7 (6th zero indexed!!) .. is numeric digit, store as literal in found devices variable

  '***********************************************************
    ''Parse number of devices found lines...

  'Parse Result (number of device found) reply lines, storing as array
  repeat FoundDevices
     
    ''Each reply line will be in format +INQ:Addr-NAP#:Addr-UAP#:Addr-LAP#,DeviceType,RSSI
    ''Only first three number fields are really of interest
        
      'Read reply into N'th element of array
    GetReply
    bytemove(DestPtr,@RxStrBuff,InqReplyStringSize-1)
     
    ''Each reply line will be in format ################,AAAA,$$$$
    ''################ is 16 Hex character FIXED WIDTH Bluetooth address (may be zero padded to 16 chars)
    ''AAAA after comma delimiter is variable length alphanumeric Bluetooth device name (1-30 chars)
    ''$$$$ after comma delimiter is variable length Hex character Bluetooth device class type (1-6 chars)
     
    'Update destination pointer + array index slice size, for next loop iteration
    DestPtr += InqReplyStringSize


  '***********************************************************
  ''Parse last reply line...
  
  'Get last line of reply (and ignore contents!!) ... should be 'Inquiry Done"
  GetReply  

  '***********************************************************
  ''All of the inquiry reply received ... 'Offline' reformat strings in array

  'Pointer initialised to begining of huge byte array (can be indexed as array elements, by offset multiplication)
  DestPtr := @BtAddrStrArray

  'Repeat for ALL bytes in byte array
  repeat InqReplyStringSize*InqReplyArrayElements

    'If comma found, replace with Z terminator, to delimit this field
      if byte[DestPtr] == ","
         byte[DestPtr] := 0

     'Increment pointer, for next loop iteration
     DestPtr++

  '**Something** received back in RxStringBuff... so set comms Rx timeout back to a sensible value
  SerialTimeout := 2000
  
  '***********************************************************
  ''Done.. return number of devices found (may be zero if nothing found)
  Return FoundDevices

PUB HowManyFound

   Return FoundDevices    
PUB ReadArrayData(ArrayIndex,Field) 'Read N'th field from M'th array element, returning pointer to string. Both values zero indexed
'' ArrayIndex is which found device this concerns..
''
'' Field = 0 returns Bluetooth address, as 16 char fixed width Hex string
'' Field = 1 returns variable length alphanumeric Bluetooth device name (1-30 chars)
'' Field = 2 returns variable length Hex character Bluetooth device class type (1-6 chars)
''
'' No values out of bounds error checking ... ArrayIndex must be 0..9, Field must be 0..2


  'Return result value points to  'ArrayIndex' element of array... indexed by offset multiplication)                            
  result := @BtAddrStrArray + (InqReplyStringSize*ArrayIndex)

  'Do field number of times (will not execute if field is 0)
  repeat while Field--

     'Move return result value past next found Z terminator (string is Z terminator padded by inquire method, so no danger of over-run)
     repeat while byte[result++] 'Traverse string until Z terminator found

PUB ConnectDeviceByName(FindNameStrPtr,PortBaudRate) |Ctr 'Connect and pair to device by name

  'Temporarily set baud rate to that of target port
  ''TempUartRate(PortBaudRate)
  CommandMode
   
  'Loop through all elements of the found devices string array..
  repeat Ctr from 0 to InqReplyArrayElements-1

    'If the stored Bluetooth name field matches the passed name string...
    if strcomp(ReadArrayData(Ctr,1) ,FindNameStrPtr)

      'Send a connect to address command to BlueSmirf
      SB.New                                                'New blank string within string builder class
      SB.AddStr(string("C,"))                               'Add Connect command and comma delimiter
      SendCmd( SB.AddStr( ReadArrayData(Ctr,0) ) )          'Add address string, and send the command

      return True

  'Failed...
  return False

DAT 'Serial passthrough functions..

PUB rxflush  'Passthrough function, for direct port access to child comm port driver

'' Flush receive buffer

  BtSerial.rxflush
  
    
PUB rxcheck  'Passthrough function, for direct port access to child comm port driver  

'' Check if byte received (never waits)
'' returns -1 if no byte received, $00..$FF if byte

  return BtSerial.rxcheck

PUB rx  'Passthrough function, for direct port access to child comm port driver  

'' Receive byte (may wait for byte)
'' returns $00..$FF

  return BtSerial.rx


PUB tx(txbyte) 'Passthrough function, for direct port access to child comm port driver  

'' Send byte (may wait for room in buffer)

  BtSerial.tx(txbyte) 


PUB str(stringptr) 'Passthrough function, for direct port access to child comm port driver  

'' Send string                    

  BtSerial.str(stringptr)
    

PUB dec(value)

'' Print a decimal number

  BtSerial.dec(value)


PUB hex(value, digits)

'' Print a hexadecimal number

  BtSerial.hex(value, digits) 


PUB bin(value, digits)

'' Print a binary number

  BtSerial.bin(value, digits)
   
DAT 'Private local methods...

PRI SerialGetStr(stringptr,BuffSize,Timeout) | index,char 'Read in <Cr> or NULL terminated string from serial port

    '' Gets <Cr> terminated string and stores it, starting at the stringptr memory address
    index~
    
    repeat

      repeat
      'Recieve byte from comm port, with optional timeout
        if TimeOut
           Char := BtSerial.RxTime(Timeout)
        else
           Char := BtSerial.Rx
      while Char == 10  'Ignoring <Lf>'s recieved from comm port!!!
      
      'If timed out, or <Cr> ... immediately quit getting chars from port
      If Char < 0 or Char == 13
        quit
        
      byte[stringptr][index++] := char 'Store char in string
      
       If index == BuffSize 'If RX string is full quit getting chars from port 
         quit
    
    byte[stringptr][index]~  'Add zero terminator

PRI GetReply

  SerialGetStr(@RxStrBuff,InqReplyStringSize-1,SerialTimeOut)  'Get reply

  return @RxStrBuff

PRI WaitMs(Value)|RefCnt,MsTicks  'Wait (delay) Value Milliseconds

  
  RefCnt := Cnt
  MsTicks := ClkFreq/1000
  
  repeat Value
    RefCnt += MsTicks
    WaitCnt(RefCnt)

PRI MatchPartialString(SrcStrPtr,MatchStrPtr)

   repeat StrSize(MatchStrPtr)

     'If either string Z terminator found, strings portions length mismatched
     if not byte[SrcStrPtr] or not byte[MatchStrPtr]
       return false

     'If bytes in the two strings differ, strings portions content mismatched  
     if byte[SrcStrPtr++] <>  byte[MatchStrPtr++]
       return False

   return True

DAT
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}