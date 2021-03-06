CON

  '_CLKMODE = XTAL1 + PLL16X
  '_XINFREQ = 5_000_000
  
  BitSyncSeqCountNorm = 5                               'Number of bit sync bytes to be transmitted
  BitSyncSeqCountMax = 15                               'Number of bit sync bytes to be transmitted
  TimeOutNormal = 25                                    'Signal check time out in ms
  TimeOutTxToRxTransition = 249                         'Signal check time out (in blocks of 256 uS)
  TxCountMax = 4                                        'Maximum number of packet (re)transmits (=< 4)
  IOBufferSize = 512                                     'Maximum size of packet that can be transmitted/received
  Dlay = 10                                             'Delay value
                                             'Default baud rate

'[Pin Input/Output Configuration]
{{
Config PortB = &B00001000                                   'Configure Port B pins for input & output
PortB = &B00001000                                          'Port B inputs tri-stated (HiZ) & outputs initialised
Config PortD = &B01000110                                   'Configure Port D pins for input & output
PortD = &B00000100                                          'Port D inputs tri-stated (HiZ) & outputs initialised
}}

'[ Pin & Register Identification ]

  RPCMode = 1                                        'RPC Mode select (0=Test; 1=Normal)
  RxMode = 1                                         'Rx Mode select (0 = Inactive; 1 = Active)                                    
  TxMode = 1                                         'Tx Mode select (0 = Inactive; 1 = Active)
  Receiver = 6                                       'Receiver enable/disable pin (1=Enabled; 0=Disabled)
  Transmitter = 3                                    'Transmitter enable/disable pin (1=Enabled; 0=Disabled)
'Transmitter Alias UCR.TXEN                          'UART Transmitter (1=Enabled; 0=Disabled)
  UARTTxBuffer = 4                                   'UART Tx Buffer Status
  SignalOut = 2                                      'RPC-to-Host IO handshake signal-out pin
  SignalIn = 3                                       'Host-to-RPC IO handshake signal-in pin
  
  ClockOut = 2                                       'Clock-out to host pin (shares pin with signal-out)
  ClockIn = 3                                        'Clock-in from host pin (shares pin with signal-in)
  
  DataLine = 4                                       'Data transfer Line
  SetDataLine = 4
  DataOut = 23                                        'Data-out to host (send packet) pin
  DataIn = 22                                         'Data-in from host (get packet) pin

  baud = 2400

  bitTime = 33333
ErrorInd = 3

'[ Constants Used in Preamble ]
  BitSyncSequence = %01010101                          'Bit synchronisation & DC balancing of receiver sequence
  ByteSyncSequence = $15451144                         'Start-of-byte synchronisation sequence. See ref [x]
  StartOfPacketSync = %00110011                        'Start-of-packet sync [=51] (transmitted unencoded)

'[Address Byte Constants]
  Broadcast = %11110000                                'Broadcast address
  PwrDownRPC = %00001111                               'Host instruction to power down RPC

'[Control Byte Constants]
  Hail = %00111011                                     'Hail another node to check if is is alive
  ThisIsMe = %00111100                                 '"This is me" - RPC declares node address to host
  ACKN = %00111101                                     'Acknowledge code
  NoACK = %00111110                                    '"No ack received" - RPC informs host
  PwrDown = %00111111                                  'Host instruction to power down RPC
  Reserved1 = %00110111
  Reserved2 = %00111000
  Reserved3 = %00111001
  Reserved4 = %00111010



'[ Constants - Descriptive (use of descriptive constants makes intention of code clearer) ]

  HiZ = 0
  Enabled = 1
  Disabled = 0
  Yes = 1
  No = 0
  Active = 1
  Available = 0
  None = 1
  Full = 0
  Empty = 1
  Rset = 1
  Accept = 1
  Reject = 0
  Busy = 0
  Free = 1
  HI = 1
  LO = 0
  StartNegotiation = 0
  RequestPacketTransfer = 0
  ReadyToRead = 1
  ClearToRead = 1
  ReadyForTransfer = 0
  RequestToSend = 1
  ClearToSend = 1
  EncodedByteSize = 2
  TempBufferSize = 2
  ControlPacketSize = 2                                 'Control packet is 2 bytes
  PacketControlByte = 2                                 '2nd byte of packet is control or packet size byte
  RetransmitCntrIncr = %01000000                       'Increment value for packet (re)transmit counter
  TestMode = 0

var
  
  Byte AddressSpace[115]' As Byte At $60                        'Total SRAM space available for variables

'[ Allocation of Contiguous SRAM Space to Pointer Groups]
  Byte GpA1' As Byte At $60 Overlay                             ')  Due to limited SRAM space, it has to be shared among
  Byte GpA2' As Byte At $61 Overlay                             ')  variables. Contiguous SRAM space is allocated to

  Byte GpB1' As Byte At $62 Overlay                             ')  pointer groups. For example, GpA1 & GpA2 form one
  Byte GpB2' As Byte At $63 Overlay                             ')  contiguous group; GpB1 & GpB2 form another.

  Byte GpC1' As Byte At $64 Overlay                             ')  By using these groups as pointers for variables via
  Byte GpC2' As Byte At $65 Overlay                             ')  the 'Overlay' directive, porting code from one AVR

  Byte GpD1' As Byte At $66 Overlay                             ')  controller to another becomes easy as it is only
  Byte GpD2' As Byte At $67 Overlay                             ')  necessary to allocate contiguous SRAM space to an
  Byte GpD3' As Byte At $68 Overlay                             ')  an appropriate pointer group.
  Byte GpD4' As Byte At $69 Overlay                             ')
  Byte GpD5' As Byte At $6A Overlay                             ')

  Byte RxB1' As Byte At $6B Overlay                             ')
  Byte RxB2' As Byte At $6C Overlay                             ')

  Byte TxB1' As Byte At $9F Overlay                             ')
  Byte TxB2' As Byte At $A0 Overlay                             ')


  Byte RxBuffer[IOBufferSize]' As Byte At RxB1 Overlay          'Receive Buffer (holds received packet)
  Byte RxBufferAddr' As Byte At RxB1 Overlay                    'Received packet address byte
  Byte RxPktType' As Byte At RxB2 Overlay                       'Received packet packet type byte
  Byte RxPacketSize' As Byte At RxB2 Overlay                    'Received packet size (same as control packet byte)

  Byte TxBuffer[IOBufferSize]' As Byte At TxB1 Overlay          'Transmit Buffer (holds host packet for transmission)
  Byte TxBufferAddr' As Byte At TxB1 Overlay                    'Transmitted packet address byte
  Byte TxPktType' As Byte At TxB2 Overlay                       'Transmitted packet packet type byte
  Byte TxPacketSize' As Byte At TxB2 Overlay                    'Transmitted packet size (same as control packet byte)

  Byte EncodedByte[EncodedByteSize]' As Byte At GpA1 Overlay
  Byte EncodedWord' As Word At GpA1 Overlay                     'Manchester-encoded "byte" is actually 2 bytes = word
  Byte EncodedWordLow' As Byte At GpA1 Overlay                  'Low byte of EncodedWord
  Byte EncodedWordHigh' As Byte At GpA2 Overlay                 'High byte of EncodedWord

  Byte ReceivedByte' As Byte At GpA2 Overlay                    'Byte extracted from receiver
  Byte PktType' As Byte At GpA2 Overlay                         'Packet type

  Byte ReceivedCRC8' As Byte At GpB1 Overlay
  Byte CalculatedCRC8' As Byte At GpB2 Overlay

  Byte ByteForTx' As Byte At GpB1 Overlay                       'Buffer to hold byte to be transmitted
  Byte TxPktTypeTemp' As Byte At GpB1 Overlay
  Byte BitSyncSeqCount' As Byte At GpB2 Overlay
  Byte DecodedByte' As Byte At GpB2 Overlay

  Byte TempWord' As Word At GpB1 Overlay                        'Temporary word variable
  Byte TempWordLow' As Byte At GpB1 Overlay                     'Low byte of TempWord
  Byte TempWordHigh' As Byte At GpB2 Overlay                    'High byte of TempWord

  Byte TempBuffer[TempBufferSize]' As Byte At GpC1 Overlay      'Temporary buffer
  Byte TempBufferAddr' As Byte At GpC1 Overlay                  'Temporary buffer address byte
  Byte TempBufferCtrl' As Byte At GpC2 Overlay                  'Temporary buffer control byte
  Byte RecipientAddr' As Byte At GpC1 Overlay                  'Packet recipient's node address

  Byte MyNodeAddr' As Byte At GpD1 Overlay                      'This node's address
  Byte TxCycleCounter' As Byte At GpD2 Overlay                  'Tx-cycle counter
  Byte PacketSize' As Byte At GpD3 Overlay                      'Actual size of received or transmitted packet in bytes
  Byte TimeOutListenBeforeTx' As Byte At GpD3 Overlay           'Signal scan timeout value used before packet Tx
  Byte TimeOut' As Byte At GpD4 Overlay                         'Time out variable

  Byte I' As Byte At GpD5 Overlay
  Byte J' As Byte At GpC2 Overlay


'[ Flags ]

  Byte SignalDetect' As Bit                                     'Signal-detect flag (Yes/No)
  Byte RxPacketStatus' As Bit                                   'Received packet status flag (Accept/Reject)
  Byte TxBufferStatus' As Bit                                   'Transmit buffer status flag (Empty/Full)
  Byte RxBufferStatus' As Bit                                   'Receive buffer status flag (Empty/Full)
  Byte PacketForHostStatus' As Bit                              'Packet for host status flag (Available/None)
  Byte AckInExpected' As Bit                                    'Expect-ackn-to-transmitted-packet flag (Yes/No)
  Byte AckOutReqd' As Bit                                       'Send-ackn-to-received-packet flag (Yes/No)

  'byte bitTime
  byte ms
  byte LastPacketSent

  Byte CogSpace[512]

OBJ
                         
  BS2 : "BS2_Functions"
  SS : "Simple_Serial"
  CRC : "CRC"

pub Start

  cognew(Main, @CogSpace)
  
pri Main | b
  
  Initialisation

  'bitTime := 33333 'clkfreq / baud
  
  {BS2.Start(31, 30, 9600, 1)
  BS2.pause(1000)

  BS2.Debug_Str ( String("Im here in the RPC", 13) )
    
  outa[13] := 0
  outa[4] := 0

  
  
  repeat
    b := ScanForSignal
    if (SignalDetect == No)
      outa[13] := 0
      outa[4] := 0
    elseif ReceivedByte == BitSyncSequence
      outa[13] := 1
        BS2.DEBUG_IBIN ( ReceivedByte, 8 )
        BS2.Debug_str ( string(13) )
    else
      outa[4] := 1 }

' Initial Start-up & Test Mode
  repeat                                                'Do following process once only on start-up
    'SendPacketToHost                                    'Send pre-loaded RPC node address packet to host
    CreateAndTxControlPacket                            'Broadcast RPC node address
  Until RPCMode <> TestMode                             'Repeat process if RPC is in test mode

' Normal Mode
  repeat                                                'While RPC is in normal mode
    ReceiveProcessScheduler                             'Receive packet & send to host cycle
    TransmitProcessScheduler                            'Get packet from host & transmit cycle
    
pub rxcheck : rxbyte

'' Check if byte received (never waits)
'' returns -1 if no byte received, $00..$FF if byte

  {{rxbyte--
  if rx_tail <> rx_head
    rxbyte := rx_buffer[rx_tail]
    rx_tail := (rx_tail + 1) & $F}}

pri Initialisation

  

  {
  dira[13]~~
  outa[13] := 1

  dira[4]~~
  outa[4] := 1
  }


  SS.Init(22, 23, 2400)
  
  dira[DataIn]~
  
  'outa[Transmitter] := Disabled                                    'Disable transmitter

  'Config := Timer
  'Prescale := 1024                   'Configure and start timer0 in free running mode

  'Waitcnt(cnt + $FFFF)                                             'Wait awhile for signals to settle after power-up/reset

  'MyNodeAddr := ina[PinB] And &HF0                                'Determine node address set from state of pins PB4,5,6,7
  MyNodeAddr := %10000 & $F0
   
  RxBufferAddr := MyNodeAddr | $0F                         'Load RPC & broadcast addr into Rx buffer address field
  RxPktType := ThisIsMe                                      'Packet type for sending to host

  TempBufferCtrl := ThisIsMe                                 'Packet type for transmitting
  PacketForHostStatus := None                                'Initialise Packet-For-Host status flag (signal to host)

  RxBufferStatus := Empty                                    'Initialise Receive Buffer status flag
  TxBufferStatus := Empty                                    'Initialise Transmit Buffer status flag
  TimeOut := TimeOutNormal                                   'Default time-out setting for signal detection

  
  ms := (clkfreq / 1_000)
  
pri ReceiveProcessScheduler                                    'Receive packet and send to host
  repeat                                                        'Start cycle
    ScanForSignal                                     'Scan for carrier signal
    If ReceivedByte == StartOfPacketSync                 'If start-of-packet sync byte is detected,
      TimeOut := TimeOutNormal
      ReceivePacket                                   '    then receive packet
      If RxPacketStatus == Accept                       '    If packet has been accepted,
        ProcessReceivedPacket                         '        process packet
  Until SignalDetect == No                              'Repeat cycle until no signal is detected
  
pri TransmitProcessScheduler                                   'Gets host packet if Tx buffer is empty, Else transmits

  If TxBufferStatus == Empty                             'If Tx buffer is empty &
    If ina[SignalIn] == RequestPacketTransfer                 'If Host has initiated communication,
      GetPacketForTx                                     'Get packet from host
      ProcessPacketForTx                                 'Process packet for transmission
  Else                                                      'If Tx buffer is full then,
    TransmitPacket                                    '    Transmit packet
    PacketRetransmitControl                           '    Packet retransmit control
    
pri ReceivePacket                                              'Receiving packet procedure
  
  RxPacketStatus := Accept                                   'Default is accept received packet
  PacketSize := IOBufferSize                                 'Set default received packet size to maximum

  I := 0
  repeat
    I++
    J := 0
    repeat
      J++
      ScanForSignal                                   'Scan for signal
      If SignalDetect := No                              'On loss of signal,
        RxPacketStatus := Reject                             '    Drop packet and
        quit
      EncodedByte[J] := ReceivedByte                         'Receive encoded "byte", i.e. 2 bytes
    Until J == EncodedByteSize                          'Encoded word size = 2 bytes

    If RxPacketStatus := Reject
      quit                 'On error, abort receive process

    ManchesterDecodeAndChkCRC                         'Manchester decode and CRC8 check

    If RxPacketStatus == Reject
      quit                'On error, abort receive process
  Until I > PacketSize                                 'Continue until CRC8 byte has been received

  If RxPacketStatus := Accept
    RxBufferStatus := Full     'If packet is accepted set Rx buffer status flag to full

pri TransmitPacket

  PacketSize := TxPacketSize                            'Initialise packet size
  GetPacketSize                                         'Get packet size

  'Set Preamble Duration:
  BitSyncSeqCount := BitSyncSeqCountNorm                'Initialise preamble duration
  TxPktTypeTemp := TxPktType & $3F                      'Extract packet type

  If TxPktTypeTemp == ACKN                              'If packet type is ACKN,
    BitSyncSeqCount := BitSyncSeqCountMax               '    maximise preamble to stabilise recipient's Rx

  'Listen Before Transmit:
  If RxMode == Active                                   'If Receive Mode is activated, then
    TimeOut := TimeOutListenBeforeTx                    '    Set signal scan time-out duration
    repeat
      ScanForSignal                                     '    Scan for carrier signal
    Until SignalDetect == No                            '    Start transmitting only if no signal is detected

  'Transmit Preamble:
  I := 0
  repeat                                                ')
    I++
    SS.tx ( BitSyncSequence )                           '} Transmit bit synch & DC balancing (of Rx) sequence;
                                                        '} includes time for sender's Tx to be ready for data
  Until I == BitSyncSeqCount                            ')

  SS.tx ( ByteSyncSequence )                            'Transmit byte synchronisation sequence (see ref 1) 
  SS.tx ( StartOfPacketSync )                           'Transmit start-of-packet sync byte (not encoded)
  
  'Encode And Transmit Packet:
  I := 0
  repeat                                                'For each byte in the packet to be transmitted,
    I++
    ManchesterEncodeAndGenCRC                           'Manchester encode byte (and CRC8 generation)
    SS.tx ( EncodedWord )                               'Transmit Manchester-encoded "byte" (word)
  Until I > PacketSize                                  'Repeat until CRC8 byte has been transmitted

  'Post Transmit Housekeeping:
  repeat
  Until UARTTxBuffer == Empty                           'Wait until all of UART Tx buffer have been transmitted  

  If RxMode == Active                                                    
    TimeOut := TimeOutTxToRxTransition

pri ProcessPacketForTx                                         'Process packet for transmission

  TxCycleCounter := TxCountMax                               'Initialise Tx-cycle counter to maximum (=< 4)

  If RxMode == Active
    AckInExpected := Yes               'If Rx Mode is Active, Ackn is expected 

  Case TxBufferAddr
    Broadcast:                                         'Packet type is "broadcast"
      AckInExpected := No                                    'No ackn expected
      TxCycleCounter := 1                                    'Transmit packet only once
    PwrDownRPC:
      outa[Receiver] := Disabled
      'PowerDown

  'Rotate TxBufferAddr , Left , 4                            'Rotate address byte before adding node address
  TxBufferAddr := TxBufferAddr Or MyNodeAddr                 'Add node address to packet's address byte
  'Rotate TxBufferAddr , Left , 4                          'Config addr field to "recipient-addr:sender-addr" format

pri ProcessRxPacketHeader                                      'Process received packet header

  RecipientAddr := RxBufferAddr & $F0                    'Extract recipient address

  Case RecipientAddr
    Broadcast :                                        'Broadcast or Test packet. Accept packet
    MyNodeAddr :                                       'This node's address. Accept packet
    Other : RxPacketStatus := Reject                     'Not this node's address or corrupted; Reject packet
  
  PacketSize := RxPacketSize                                 'Initialise packet size

  GetPacketSize                                       'Determine actual received packet size

                                                                  
pri ProcessReceivedPacket                                      'Determines what to do with received packet

  If RxBufferAddr < Broadcast
    AckOutReqd := TxMode      'If not broadcast packet then ack, depending on Tx mode

  PktType := RxPktType & $3F                              'Mask out transmit count number to extract packet type

  Case PktType
    ACKN:                                              'If received packet type is "Acknowledge",
      AckOutReqd := No                                       '    No need to acknowledge receipt
      AckInExpected := No                                    '    Transmitted packet acknowledged, so reset flag
      TxBufferStatus := Empty                                '    Flush Tx buffer (no need to re-transmit packet)
    Hail:                                              'If received packet type is "Hail",
      RxBufferStatus := Empty                                '    Flush Rx buffer (don't send to host,but acknowledge)
    ThisIsMe:                                          'If received packet type is "ThisIsMe",
      AckOutReqd := No                                       '    Do not acknowledge receipt
  
  If AckOutReqd == Yes                                  'If ack of received packet is required then
    TempBufferCtrl := ACKN                                   '    Set control byte to "Acknowledge" type
    CreateAndTxControlPacket                          '    Transmit "acknowledge" packet
    AckOutReqd := No                                         '    Reset Send-ackn-to-received-packet Flag
  
  If RxBufferStatus == Full
    SendPacketToHost      'If receive buffer is full, send packet to host
      
pri ManchesterDecodeAndChkCRC                                  'Manchester-decode and CRC check (see ref 2)

  EncodedWord := EncodedWord | $AA55                       'Prepare Manchester-encoded word for decoding
  DecodedByte := EncodedWordHigh & EncodedWordLow          'Decode Manchester-encoded "byte" (2 bytes=word)

  If I <= PacketSize                                    'If not all bytes of packet have been received, then

    RxBuffer[I] := DecodedByte                               '    continue receiving packet

    If I == PacketControlByte                            '    If current byte is the packet control byte, then
      ProcessRxPacketHeader                           '        Process packet header

  Else                                                      'Else

    ReceivedCRC8 := DecodedByte                              '    receive CRC8 byte
    CalculatedCRC8 := CRC.CRC8_bin(@RxBuffer, PacketSize)         '    calculate received packet's CRC8 value

    If CalculatedCRC8 <> ReceivedCRC8                  '    If calculated CRC8 <> received CRC8, then
      RxPacketStatus := Reject                               '        reject packet (CRC check failed)


pri ManchesterEncodeAndGenCRC                                  'Manchester encoding procedure (see ref 2)

  If I <= PacketSize                                    'If packet transmission is not complete, then
    ByteForTx := TxBuffer[I]                            '    set current Tx Buffer byte for encoding
  Else                                                  'Else if all bytes of packet have been transmitted
    ByteForTx := 1 'CRC8(TxBuffer(1) , PacketSize)      '    calculate and encode Tx buffer packet’s CRC8 value

  EncodedWordLow := ByteForTx | $55                    'EncodedWordLow contains odd bits of ByteForTx; even bits =1
  EncodedWordHigh := ByteForTx | $AA                   'EncodedWordHigh contains even bits of ByteForTx; odd bits=1
  TempWord := EncodedWord & $55AA
  'TempWordLow >>= 1                                     'Shift TempWordLow right
  'TempWordHigh := TempWordHigh + TempWordHigh           'Shift TempWordHigh left
  EncodedWord := EncodedWord ^ TempWord                 'Resulting Manchester-encoded word

                                                                   
pri CreateAndTxControlPacket

  TempBufferAddr := RxPktType & %11000000               'Extract received packet's re-transmit counter value

  TempBufferCtrl := TempBufferCtrl | TempBufferAddr     'Create control byte

  TempBufferAddr := RxBufferAddr                        'Get received packet's address byte

  TempBufferAddr <-= 4                                  'Swap "To" and "From" addresses

  SwapBuffers                                           'Swap temp buffer contents with transmit buffer

  TransmitPacket                                        'Transmit "acknowledge" packet

  SwapBuffers                                           'Swap back, restoring transmit buffer to original state

                                                                      
pri SwapBuffers                                                'Swaps TempBuffer contents with TxBuffer header bytes

  I := 0

  Repeat
    I++
    TempBuffer[I] := TxBuffer[I]
  Until I == TempBufferSize
                                                                   
pri SendPacketToHost                                           'Send packet to host procedure

  PacketForHostStatus := Available                           'Packet for host is available

  NegotiatePktTransferDirxn                           'Negotiate with host on packet transfer direction

  outa[SetDataLine] := HI                                          'Initialise data line
  PacketSize := RxPacketSize                                 'Initialise packet size
  GetPacketSize                                       'Get actual received packet size

  I := 0

  repeat
    waitcnt(cnt + Dlay)                                             'Delay to maintain sync between sender and recipient
    repeat
    Until SignalIn == ClearToSend                       'Wait until host gives the "clear-to-send" signal
    waitcnt(cnt + Dlay)                                             'Delay to maintain sync between sender and recipient
    I++
    'ShiftOut DataOut , ClockOut , RxBuffer(I) , 0 , 8       'Shift-out bytes, MSB first, on RPC clock going LOW
  Until I == PacketSize                                 'Repeat until whole packet is transferred
  
  outa[SignalOut] := Free                                          'Set signal line to "free" (HI)
  outa[SetDataLine] := HiZ                                         'Set data input pin to high impedance
  'Config DataLine := Input                                   'Config data line for input
  PacketForHostStatus := None                                'Reset Packet-For-Host status flag
  RxBufferStatus := Empty                                    'Flush receive buffer
                                                                     
pri GetPacketForTx                                             'Get packet for transmission

  NegotiatePktTransferDirxn                           'Negotiate with host on packet transfer direction

  outa[SetDataLine] := HiZ                                         'Config data line for high impedence input mode

  'Config DataLine := Input                                   'Config data line for input

  outa[SignalOut] := ReadyForTransfer                              'Send host "ready-for-transfer" signal

  repeat
  Until SignalIn == RequestToSend                       'Wait until host sends "request-to-send" signal

  PacketSize := IOBufferSize                                 'Set packet size to default

  I := 0

  repeat
    I++
    outa[SignalOut] := ClearToSend                                 'Send "Clear-to-send" signal to host
    'ShiftIn DataIn , ClockIn , TxBuffer(I) , 5 , 8          'Shift-in bytes, MSB first, on host clock going HIGH
    outa[SignalOut] := Busy                                        'Send "busy" signal to host
    If I == PacketControlByte                           'Check for control packet and set packet size
      PacketSize := TxPacketSize                             'Initialise packet size
      GetPacketSize                                   'Get actual packet size
  Until I == PacketSize                                 'Get contents byte-by-byte and stuff TxBuffer

  outa[SignalOut] := Free                                          'Set signal line to "idle"
  outa[SetDataLine] := HI                                          'Initialise data-IO-status line
  TxBufferStatus := Full                                     'Set Transmit Buffer status flag
                                                            
pri PacketRetransmitControl                                    'Processes packet re-transmit cycle

  TxPktType := TxPktType + RetransmitCntrIncr                'Increment packet's retransmit count field
  TxCycleCounter := TxCycleCounter - 1                       'Decrement Tx-cycle counter

  If TxCycleCounter == 0                                'If Tx-cycle counter=0, then

    TxBufferStatus := Empty                                  ' Flush TxBuffer

    If AckInExpected == Yes                             ' If transmitted packet was not acknowledged, altho
      RxBufferAddr := TxBufferAddr                           '    set address byte
      RxPktType := NoACK                                     '    expected, create a "no-ack" control packet
      SendPacketToHost                                '    and send packet to host
      AckInExpected := No                                    '    Re-initialise Expect-ackn-to-transmitted-packet flag

                                                        
pri ScanForSignal | Timer, t, b, pinState                                             'Scan for signal

  SignalDetect := No                                         'Initialise signal-detect flag
  Timer := cnt

  pinState := ina[DataIn]

  if (pinState == 1)
  
    repeat
     
      if (ina[DataIn] == 0)
     
        t := cnt + bitTime >> 1                             ' sync + 1/2 bit
        
        repeat 8
          waitcnt(t += bitTime)                             ' wait for middle of bit
          b := ina[DataIn] << 7 | b >> 1                       ' sample bit

        bytemove (@ReceivedByte, @b, 1)
        
        SignalDetect := Yes
      
    until SignalDetect == Yes or (cnt - Timer) / (clkfreq / 1000) > TimeOutNormal

  return b
                                                                      
pri GetPacketSize

  PacketSize := PacketSize & $3F                          'Extract packet size information

  If PacketSize > IOBufferSize                          'If packet size is > IO buffer size, => control packet
    PacketSize := ControlPacketSize                          '    => control packet = 2 bytes
  ElseIf PacketSize < ControlPacketSize                 'If packet size is < control packet size,
    PacketSize := ControlPacketSize                          '    => control packet = 2 bytes
                                                                      
pri NegotiatePktTransferDirxn                                  'Negotiate with host on packet transfer direction

  outa[SetDataLine] := HI                                          'Initialise data-IO-status line
  'Config DataLine = Output                                  'Config data line for output
  outa[SignalOut] := StartNegotiation                              'Send host "start-negotiation" signal

  repeat
  Until SignalIn == StartNegotiation                    'Wait until host sends "start-negotiation" signal

  outa[SetDataLine] := LO                                          'Signal to host that packet status is online

  repeat
  Until SignalIn == ReadyToRead                         'Wait until host sends "ready-to-read" signal

  outa[SetDataLine] := PacketForHostStatus                         'Put packet-for-host availability status on data line
  outa[SignalOut] := ClearToRead                                   'Signal to host that packet status is online

  repeat
  Until SignalIn == ReadyForTransfer                    'Wait until host sends "ready-for-transfer" signal
  
PRI PAUSE(Duration) | clkCycles
{{
   Causes a pause for the duration in mS
   Smallest value is 2 at clkfreq = 5Mhz, higher frequencies may use 1
   Largest value is around 50 seconds at 80Mhz.
     BS2.Pause(1000)   ' 1 second pause
}}

   clkCycles := Duration * ms-2300 #> 400               ' duration * clk cycles for ms
                                                           ' - inst. time, min cntMin
   waitcnt( clkCycles + cnt )                              ' wait until clk gets there