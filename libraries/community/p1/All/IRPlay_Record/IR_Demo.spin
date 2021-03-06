{{
 IRPlayRecord 
 by Chris Cantrell
 Version 1.1 6/27/2011
 Copyright (c) 2011 Chris Cantrell
 See end of file for terms of use.
}}

{{
                                              
  Operation:

  This object demonstrates the IRPlayRecord object -- a universal IR remote control with
  record/playback functions.                                      
                 
                     +5
               IR    
         120   ┌─┘ 120
  P24 ─────    
               │  2N3904G
               

          ┌───┐ GP1UX311QS
          │ ° │
          └┬┬┬┘ +5    
           │││  
  P26  ───┘└──┘    
  
  Simply connect a 3-pin GP1UX311QS IR sensor and an LED IR LED to the propeller demo
  board (I used the Spinneret Web Server). The demo uses the Propeller Serial Terminal
  to debug back to the host computer.

  The demo uses line-at-a-time commands to record and play back IR signals.

  For instance, Type "+TV_Volumne_up" and press enter. Then press the VOLUME UP on the target TV
  remote. Then type "*TV_Volume_up" to play the sequence back and turn the volume up on the TV.

  A large number of sequences can be stored in the map's database. The object
  can be the basis of a universal remote control project.
}}

CON 
        _clkmode        = xtal1 + pll16x
        _xinfreq        = 5_000_000

        OUT_PIN = 24  ' IR LED output
        'DEB_PIN = 25  ' Debug (visible) LED output 
        IN_PIN  = 26  ' Sensor input                       

VAR

' Command box to talk to IRPlayRecord cog        
        long command        
        long paramError
        long bufPtr

' Scratch area for sample recording
        byte sampleBuffer[512]

' Scratch area for input string
        byte stringBuffer[200]     

        byte mapStructure[1024*8]

OBJ                                 
        PST  : "Parallax Serial Terminal.spin"
        ir   : "IRPlayRecord"                 
        map  : "StringKeyMap"             

PUB start | c, i

  PauseMSec(2_000) ' Allow 2 seconds after programming to start the PST.

  'Initialize PST screen
  PST.Start(115200)
  PST.Home
  PST.Clear

  ' database of named IR sequences
  map.new(@mapStructure,1024*8)          

  paramError:= (OUT_PIN<<8) | IN_PIN  ' Output/Input pin numbers
  command:=1               ' Driver clears after init
  ir.start(@command)       ' Start the IRPlayRecord
  repeat while command<>0  ' Wait for driver to start

  command:=$50
  repeat while command<>0  ' Wait for driver to start 

  printHelp

  repeat
    PST.Char(":")
    
    PST.StrInMax(@stringBuffer,200)    

    if stringBuffer[0]=="+"
        map.writeWordToMemory(@sampleBuffer,510)             
        bufPtr:=@sampleBuffer
        command:=1
        PST.Str(string("Press button on remote",13))          
        repeat while command<>0
        map.putBinary(@mapStructure,@stringBuffer+1,@sampleBuffer+2,map.readWordFromMemory(@sampleBuffer))

    elseif stringBuffer[0]=="*"
        c := map.getBinary(@mapStructure,@stringBuffer+1)
        if c==0
          PST.Str(string("Unknown sequence "))
          PST.Str(@stringBuffer+1)
          PST.Char(13)
        else
          bufPtr:=c
          command:=2                  
          repeat while command<>0

    elseif stringBuffer[0]=="#"
        c := @sampleBuffer
        repeat i from 0 to 63
          PST.hex(byte[c++],2)
          PST.Char(" ")
        PST.Char(13)                   
              
    else
      PST.Str(string("Unknown command",13))
      printHelp
  
PUB printHelp
  PST.str(string("+TVVolUp   records sequence 'TVVolUp'",13))
  PST.str(string("*TVVolUp   plays sequence 'TVVolUp'",13))
  PST.Char(13)

PRI PauseMSec(Duration)
''  Pause execution for specified milliseconds.
''  This routine is based on the set clock frequency.
''  
''  params:  Duration = number of milliseconds to delay                                                                                               
''  return:  none
  
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)

  return  'end of PauseMSec  

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
           