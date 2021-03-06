{{

┌──────────────────────────────────────┐
│ Kermit EEPROM Console_demo, program  │
│ to show use of serial console with   │
│ EEPROM loading via Kermit protocol   │
│ Author: Eric Ratliff                 │
│ Copyright (c) 2010 Eric Ratliff      │
│ See end of file for terms of use.    │
└──────────────────────────────────────┘

2010.2.22 by Eric Ratliff

Tested with XBee in 'transparent' mode, or with direct USB connection to Propeller Demo and Education boards
With "Process" called in a fast loop, such as this demo, speed is as follows with a 57,600 baud connection:
Hyperterminal on Win XP, 32K EEPROM file loaded in 68 seconds
ZTerm on Mac OSX, 32K EEPROM file loaded in 85 seconds (slower because ZTerm does not use RLE for Kermit protocol)
Programs that do other tasks between calls to "Process" will load EEPROM files more slowly.
}}

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  NumCommands = 2

OBJ
  ConsoleSerialDriver : "Kermit EEPROM Console"
  nums : "Numbers"

VAR
  ' console serial port variables
  long rxPin ' where Propeller chip receives data
  long txPin ' where Propeller chip outputs data
  long SerialMode ' bit 0: invert rx, bit 1 invert tx, bit 2 open-drain source tx, ignore tx echo on rx
  ' individual components of mode
  long InvertRx
  long InvertTx
  long OpenDrainSourctTx
  long IgnoreTxEchoOnRx
  long baud ' (bits/second)

  ' interface for command lines
  byte CommandBuffer[ConsoleSerialDriver#LineLengthLimit+1] ' room for command and null terminator
  long ByteCount ' how many bytes came back in the command
  long UseCommandLines,EchoInput

  long ProcessorResultFlags ' from input or receive file call
  long LastProcessorResultFlags ' history of previous loop

PUB main

  nums.Init ' prepare for formatted output

  ' console serial driver parameters
  rxPin := 31 ' 31 is for USB port
  txPin := 30

  'rxPin := 27 ' 27 is where I connected an XBee on an Education Board
  'txPin := 26

  InvertRx := FALSE   ' (works with Propeller clip)
  InvertTx := FALSE   ' (must be FALSE)
  OpenDrainSourctTx := TRUE
  IgnoreTxEchoOnRx := FALSE
  SerialMode := (%1 & InvertRx)
  SerialMode |= (%10 & InvertTx)
  SerialMode |= (%100 & OpenDrainSourctTx)
  SerialMode |= (%1000 & IgnoreTxEchoOnRx)
  'baud := 9600
  'baud := 19200 
  'baud := 38400  
  baud := 57600 ' (works with XBee)
  'baud := 115200 ' (XBee almost works with 128 bte rx buffer, runs, more retries, fails, sometimes works)
  'baud := 230400 ' (XBee fails)

  ' start seroal driver/console/EEPROM loader object
  ConsoleSerialDriver.start(rxpin, txpin, SerialMode, baud)
  ' set modes that control command handling
  UseCommandLines := true ' determines if we have single character input or line input
  EchoInput := true ' do echo characters as they are typed
  ConsoleSerialDriver.SetCommandMode(UseCommandLines,EchoInput)

  repeat 5  ' let user have time to switch on Hyperterminal or start ZTerm, in case USB port is in use
    waitcnt(clkfreq+cnt)' wait 1 second
    ConsoleSerialDriver.str(string("."))
  Prompt ' let user know that program is ready to accept a command

  ' set history to show we have not started a Kermit file receive
  LastProcessorResultFlags := false

  repeat
    ' user may add code here that needs to be regularly executed, such as a control algorithm
    ' object is designed to work well with control loops up to 100 Hz speed

    ProcessorResultFlags := ConsoleSerialDriver.Process

    ' were we NOT processing a Kermit receive?
    if not(LastProcessorResultFlags & ConsoleSerialDriver#KEC_ISM_KermitPacketDetected)
      ' is a command ready?
      if ProcessorResultFlags & ConsoleSerialDriver#KEC_ISM_CommandReady
        CommandBuffer[ByteCount] := 0 ' null terminate the command string
        ConsoleSerialDriver.ReadBytes(@CommandBuffer,@ByteCount)
        ' example of program responding to a command
        if STRCOMP(@CommandBuffer[0],STRING("reboot"))
          ConsoleSerialDriver.str(string("Rebooting"))
          waitcnt(cnt + clkfreq >> 8) ' wait about 5 ms sec for serial message to finish transmitting
          REBOOT ' let propeller start from program stored in EEPROM
        else ' report strings not recognized as a command
          ' describe the command line and show it again
          ConsoleSerialDriver.str(nums.ToStr(ByteCount,nums#dec))
          ConsoleSerialDriver.str(string(" bytes in "))
          ConsoleSerialDriver.str(string("---"))
          ConsoleSerialDriver.str(@CommandBuffer[0])
          ConsoleSerialDriver.str(string("---"))
        Prompt
    else ' we were processing a Kermit receive
      ' did Kermit process end?
      if not ProcessorResultFlags & ConsoleSerialDriver#KEC_ISM_KermitPacketDetected
        ' does file size equal declared or assumed size?
        if ProcessorResultFlags & ConsoleSerialDriver#KEC_ISM_KermitCompleted
          ConsoleSerialDriver.str(string("File Receive Finished"))
        else
          ConsoleSerialDriver.str(string("File Receive Stopped"))
        Prompt ' let user know that program is ready to accept a command

    LastProcessorResultFlags := ProcessorResultFlags ' record present status for next loop

PRI Prompt
' optional user supplied routine to provide consistent que to user that program is ready to accept a command
  ConsoleSerialDriver.CRLF ' a white space blank line
  ConsoleSerialDriver.str(string("Prompt> "))

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
