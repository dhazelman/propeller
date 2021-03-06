''*****************************************************
''*  MCP3202 12-bit/2-channel ADC Driver Example      *
''*  Uses Parallax 2-Axis Joystick #27800             * 
''*  and Parallax Serial Terminal for display         *
''*  Author: Ken Gracey                               *
''*****************************************************
'' Modified by John Abshier 24 Aug 2012 (jabshier on Forum) to demo ADC/DAC on Propeller Professional Development Board
OBJ

  Serial   : "FullDuplexSerialPlus"    
  MCP3202  : "MCP3202"

CON

  _CLKMODE      = XTAL1 + PLL4X
  _XINFREQ      = 5_000_000                             ' 5MHz Crystal

  cpin  = 24         
  dpin  = 23
  spin  = 25

{{          ┌────┬┬────┐
     P25───│1        8│─── +3.3V     P24  = clock
            │   MCP    │               P23  = data in / data out
     CH0───│2 3202-B 7│─── P24       P25  = chip select
            │  12-bit  │
     CH1───│3  A/D   6│─┐            CH0 = Pot
            │          │  │            CH1 = Pot
     VSS───│4        5│─┻─ P23                         
            └──────────┘

                      470Ω
            P0 ────────── Vss                                      

                      470Ω
            P1 ────────── Vss                                      
}}                   
VAR    

  long  CH0
  long  CH1

PUB Main
  waitcnt(clkfreq * 3 + cnt)
  serial.startPST(19200)
  MCP3202.start1(dpin, cpin, spin, %0011,1)             ' enable both channels single-ended mode. DAC on pin 1
                                                        ' see datasheet for configuration options
'  MCP3202.outPercent(100,100)                            ' Set DAC to 100%.  Professional Development Board
                                                        ' needs about 55% to light LEDrepeat

  MCP3202.out($c000_0000,$c000_0000)                    ' set DAC
  repeat
    MCP3202.average(0,100)                            ' average 100 samples on CH0
    serial.CursorHome
    serial.str(string("MCP3202 12-bit A/D"))
    serial.CarriageReturn
    serial.str(string("==================")) '
    serial.CarriageReturn              
    CH0 := MCP3202.in(0)
    serial.str(string("Channel 0: "))  
    serial.ClearEndOfLine
    serial.dec(CH0)
    serial.CarriageReturn
    MCP3202.average(1,100)                               ' average 100 samples on CH1
    serial.str(string("Channel 1: ")) ' 
    serial.ClearEndOfLine
    CH1 := MCP3202.in(1)    
    serial.dec(CH1)    