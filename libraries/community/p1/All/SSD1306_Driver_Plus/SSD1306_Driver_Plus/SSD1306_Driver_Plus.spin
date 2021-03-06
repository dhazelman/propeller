{{
**********************************
*    SSD1306_Driver_Plus v 1.3   *
*       Author: L. Wendell       *
*         3DogPottery.Com        *
**********************************
 v1.0 - 3/27/2019 - original version
 v1.1 - 4/03/2019 - added scrolling
 v1.3 - 4/5/2019  - added decimal and binary
                  - added tx( ) functions for CR and CLS

      I2C IIC Serial 128X64 128*64 OLED  
      Gnd   to     Gnd
      VCC   to     3.3 Volts
      SCL   to     Propeller Pin
      SDA   to     Propeller Pin 


     Sample Use
     -------------------------------------------
     CR  = 13 'Carriage Return
     CLS = 16 'Clear Screen


     OBJ
         OLED  :  SSD1306_Driver_Plus


     PUB Main
        OLED.DrivInit(2, 3)
        OLED.Init
        OLED.Tx(CLS)
        OLED.TX(CR)
        OLED.Str(String("SSD1306_Driver_Plus!"))
        OLED.Tx(CR)
        OLED.Str(String("          Author... "))
        OLED.Tx(CR)
        OLED.Str(String("          L. Wendell"))          
}}
CON
  _clkmode = xtal1 + pll16x    'pLL16x means Multiply chrystal freq. by 16
  _xinfreq = 5_000_000

  _ConClkFreq = ((_clkmode - xtal1) >> 6) * _xinfreq     'This calculates the clock frequency to obtain
  _Ms_001   = _ConClkFreq / 1_000                        'the correct constant for milliseconds

    
  '' I2C IIC Serial 128X64 128*64 OLED  
  '  SCL = 2         '<--------------- Change these to the Propeller pins 
  '  SDA = 3         '                 you would like to use.

VAR
   byte characterToStringPointer, characterToString[255], SCL, SDA, Current_Page
                                             

PUB DrivInit(_SCL, _SDA)
''Initializes the SSD1306_Driver to OLED I2C Pins
   SCL := _SCL
   SDA := _SDA
   
PUB Init | ackBit
''Initializes the SSD1306 Module
   Start           

   repeat                          
      ackBit := 0
      ackBit += Write($78)   'Address with Write Bit
   while ackbit > 0
    
''Software Initiation Commands                                                                       
        
   ackBit := 0              ''Turn Display Off 
   repeat                   
      ackBit := 0
      ackBit += Write($80)   'Display Off = $AE  Display On = $AF           
      ackBit += Write($AE)   'RESET Value = $AE                
   while ackBit > 0
   
   repeat                   ''Set Oscillator Frequency      
      ackBit := 0
      ackBit += Write($80)   'Set display clock divide ratio. Dclock = Focs/D                     
      ackBit += Write($D5)   
      ackBit += Write($80)
      ackBit += Write($80)   'RESET Value = $80  (1 - 16 = $00 to $8F)
   while ackBit > 0

   repeat                   ''Set Multiplex Ratio.  Here, it is set to 63 (N + 1).   
      ackBit := 0
      ackBit += Write($80)   'i.e., the second byte following the command = 63.  
      ackBit += Write($A8)   'RAM locations 0 to 63 will be multiplexed to the display. 
      ackBit += Write($80)   '  
      ackBit += Write($3F)   'RESET Value = $3F = 64MUX ($3F + 1) = 64.  64 coms will be switched.
   while ackBit > 0                                                                                       

   repeat                   ''Set Display Offset 
      ackBit := 0
      ackBit += Write($80)   'Control Byte Command 
      ackBit += Write($D3)   'Shift from 0 to 63 Com's      
      ackBit += Write($80)
      ackBit += Write($00)   'RESET Value = $00
   while ackBit > 0
  
   repeat                   ''Set Start Line Address                                    
      ackBit := 0
      ackBit += Write($80)   'Control Byte Command
      ackBit += Write($40)   'RESET Value = $40
   while ackBit > 0
                  
   repeat                   ''Set Charge Pump Regulator  
      ackBit := 0
      ackBit += Write($80)   'Charge Pump Setting
      ackBit += Write($8D)   'Enable charge pump during display On 
      ackBit += Write($80)   
      ackBit += Write($14)   'RESET Value + $10 Charge Pump Disabled
   while ackBit > 0
                 
   repeat                   ''Set Segment Re-Map   
      ackBit := 0
      ackBit += Write($80)   'Column address 127 is mapped to SEG0.   
      ackBit += Write($A1)   'This flips the memory image horizontally.  
     'ackBit += Write($A0)   'RESET Value = $A0
   while ackBit > 0
  
   repeat                  ''Set Com Output Scan Direction 
      ackBit := 0
      ackBit += Write($80)  'Scan from COM[N-1] to COM0 Where N is the Multiplex ratio.        
      ackBit += Write($C8)  'Set to Remap Mode $C8   
    'ackBit += Write($C0)   'RESET Value = $C0
   while ackBit > 0
                               
   repeat                   ''Set COM pins hardware onfiguration.          ** For Accomidating to Hardware Config of OLED Screen **                        
      ackBit := 0            'Setting here is RESET, i.e.,                 $02 = 00   Sequential  Com Pin Config & Disable L/R Remap   
      ackBit += Write($80)   'Setting here is RESET, i.e.,                 $12 = 01   Alternative Com Pin Config & Disable L/R Remap  
      ackBit += Write($DA)   'and Disable COM Left to Right.               $22 = 10   Sequential  Com Pin Config & Enable  L/R Remap 
      ackBit += Write($80)   '                                             $32 = 11   Alternative Com Pin Config & Enable  L/R Remap
      ackBit += Write($12)   'RESET Value = $12
   while ackBit > 0                                   
                   
   repeat                   ''Set Contrast Control  
      ackBit := 0
      ackBit += Write($80)   'Set Contrast Control Register
      ackBit += Write($81)   'Settings are from 1 t 256
      ackBit += Write($80)
      ackBit += Write($7F)   'RESET Value = $7F
   while ackBit > 0
                       
   repeat                   ''Set Pre-charge Period for Phase 1 and Phase 2 
      ackBit := 0
      ackBit += Write($80)   'Lower Nybble sets Phase 1 period from 1 to 15. Reset = $02  
      ackBit += Write($D9)   'Upper Nubble sets Phase 2 period from 1 t 15.  Reset = $02
      ackBit += Write($80)   '
      ackBit += Write($22)   'RESET Value = #22
   while ackBit > 0
                 
   repeat                   ''Entire Display On   
      ackBit := 0
      ackBit += Write($80)   'Control Byte Command    '$A4: Display on and follows GDDRAM
      ackBit += Write($A4)   'RESET Value = $A4       '$A5: Display on and does not follow GDDRAM
   while ackBit > 0
                  
   repeat                   ''Set Normal or Inverse Display   
      ackBit := 0            '$A6 = Normal Display 
      ackBit += Write($80)   '$A7 = Negative of RAM Contents
      ackBit += Write($A6)   'RESET Value = $A6   
   while ackBit > 0
  
   repeat                    ''Adjust the VCOMH regulator output
      ackBit := 0
      ackBit += Write($80)    'Control Byte Command
      ackBit += Write($DB)   
      ackBit += Write($80)
      ackBit += Write($30)    '~0.83*vref
   while ackBit > 0
                   
   repeat                   ''Turn Display On   
      ackBit := 0             'Display is turned ON   
      ackBit += Write($80)    'Display Off = $AE  Display On = $AF           
      ackBit += Write($AF)    'RESET Value = $AE                
   while ackBit > 0
   Page(0)
   Stop
   return

PUB Clear | inx              
''Clears the OLED Screen
   Start     
   Write($78)     'Address with Write Bit             
   Horizontal_Addressing
   Write($40)     'Control Byte Data     
   repeat inx from 0 to 1023                  
      Write($00)                          
   Stop                                   
   return                                  

PUB Page(PageNum) | Char, ackBit  
''Selects the "Page" to print to. A Page is one of 8 rows that can be printed to (0 - 7)
   case PageNum 
      0 : Char := $B0
      1 : Char := $B1
      2 : Char := $B2
      3 : Char := $B3
      4 : Char := $B4
      5 : Char := $B5
      6 : Char := $B6
      7 : Char := $B7
  
   Start                          
   Write($78)       
   Page_Addressing 
   ackBit := 1
   repeat                
      ackBit := 0
      ackBit := Write($80)   
      ackBit := Write(Char)   
   while ackBit > 0
   Stop

PUB Start_Scroll | ackBit
''Start Scrolling                                                       
   Start
   Write($78)
   repeat                   
      ackBit := 0
      ackBit += Write($80)   
      ackBit += Write($2F)      
   while ackBit > 0
   Stop
   return                 

PUB Scroll( Dir, Start_P, Stop_P, Speed ) | ackBit, _Dir, StPg, SpPg, Spd
''Horizontal Scrolling
''Scroll(Direction , Start Page, End Page, Speed)
''       Direction: 1 = Right Scrolling   2 = Left Scrolling
''       Start Page: 0 to 7 are the only Valid pages
''       Stop  Page: 0 to 7 are the only Valid pages
''       Speed: 0 to 7 are the only Valid speeds

   case Dir
      1 : _Dir := $26       'Right Horizontal Scrolling
      2 : _Dir := $27       'Left Horizontal Scrolling
   StPg := $00 + Start_P    'Start Page
   SpPg := $00 + Stop_P     'Stop Page
   Spd  := $00 + Speed      'Speed

   Start     
   Write($78)
   repeat               
      ackBit := 0
      ackBit += Write($80)    
      ackBit += Write(_Dir)   
      ackBit += Write($80)   
      ackBit += Write($00)     
      ackBit += Write($80)   
      ackBit += Write(StPg)    ' 
      ackBit += Write($80)   
      ackBit += Write(Speed) 
      ackBit += Write($80)   
      ackBit += Write(SpPg)    
      ackBit += Write($80)   
      ackBit += Write($00)     
      ackBit += Write($80)   
      ackBit += Write($FF)      
      ackBit += Write($80)   
      ackBit += Write($2F)     
   while ackBit > 0
   Stop                                   
   return                  

PUB Stop_Scroll | ackBit
''Stop Scrolling                                                     
   Start
   Write($78)
   repeat                  
      ackBit := 0
      ackBit += Write($80)   
      ackBit += Write($2E)      
   while ackBit > 0
   Stop
   return                 

PUB WakeUp
''This wakes up the SSD1306 if in an uncertain state.                   
   outa[SCL] := 1                      
   dira[SCL] := 1                  
   dira[SDA] := 0                   
   repeat 9                        
      outa[SCL] := 0               
      outa[SCL] := 1              
      if ina[SDA]                      
         quit                          

PUB Pause(ms) | _int
''Delay program ms milliseconds
   _int := cnt - 1088                
   repeat (ms #> 0)                
      waitcnt(_int += _MS_001)
      
PUB Str(stringptr)
''Sends a string to the OLED.
   Start                     
   Write($78)
   Write($40)   
   repeat strsize(stringptr)
      txt(byte[stringptr++])
   Stop 

PUB Dec(value) | knx, _value, flag    'Maximum interger = +/- 2,147,483,647
''Prints a decimal number
   flag := 0
   if value < 0
      -value
      Str(String("-"))
   knx := 1_000_000_000
   repeat 10
      if value => knx
         _value := GetVal(value / knx)
         Str(@_value)
         value //= knx               'value = modulus of value / knx (modulus is non-fractional part)
         flag~~                      'Post set
      elseif flag or knx == 1
         Str(String("0"))
      knx /= 10   

PUB Bin(value, digits) | _value
''Prints the character representation of a binary number
   value <<= 32 - digits
   repeat digits
      _value :=( value <-= 1) & 1 + 0         
      Dec(_value)   

                                
PUB Tx(value)
   case value
      13:
         Current_Page++
         Page(Current_Page)
      16: Clear
                                          
PRI GetVal(value) : StrVal
   case value
      0: StrVal := "0"
      1: StrVal := "1"
      2: StrVal := "2"                      
      3: StrVal := "3"
      4: StrVal := "4"
      5: StrVal := "5"
      6: StrVal := "6"
      7: StrVal := "7"
      8: StrVal := "8"
      9: StrVal := "9"      
   return
   
PRI Horizontal_Addressing | ackBit
   repeat                       ''Set Addressing Mode to Horizontal 
      ackBit := 0
      ackBit += Write($80)   'Control Byte Command       
      ackBit += Write($20)   'Addressng Mode Command
      ackBit += Write($80)   ' 
      ackBit += Write($00)   'Set Addressing Mode to Horizontal   
   while ackBit > 0
  
   repeat                        ''Set Column Addresses for Horizontal Mode 
      ackBit := 0
      ackBit += Write($80)   'Control Byte Command       
      ackBit += Write($21)   'Set Column Address Command 
      ackBit += Write($80)   ' 
      ackBit += Write($00)   'Set Column Start to 0   
      ackBit += Write($80)   ' 
      ackBit += Write($7F)   'Set Column End to 127  
   while ackBit > 0
   
   repeat                        ''Set Page Start and Page End for Horizontal Mode 
      ackBit := 0
      ackBit += Write($80)   'Control Byte Command       
      ackBit += Write($22)   'Page Start and End Command Command 
      ackBit += Write($80)   ' 
      ackBit += Write($00)   'Set Page Start to 0   
      ackBit += Write($80)   ' 
      ackBit += Write($07)   'Set Page End to 7  
   while ackBit > 0
   return      

PRI Page_Addressing | ackBit
                     
   repeat                         ''Set Addressing Mode 
      ackBit := 0
      ackBit += Write($80)    'Control Byte Command       
      ackBit += Write($20)    'Set Memory Addressing Mode
      ackBit += Write($80)    ' 
      ackBit += Write($10)    'Page Addressing Mode Selected. RESET Value = $10 (Page Addressing Mode)  
   while ackBit > 0
                       
   repeat                          ''Set the Lower and Upperstart Column Address  
      ackBit := 0
      ackBit += Write($80)     'Control Byte Command 
      ackBit += Write($00)     'Set the lower nybble start column address ($00 to $0F)
      ackBit += Write($80)     '
      ackBit += Write($10)     'Set the upper nybble start column address ($10 to $1F)
   while ackBit > 0
   return                                                                                                                                                                        

PRI txt(char)
''Character Lookup
   case char
      "0".."9":                      
         SendByte(@Zero[(char - "0") * 6]) 
      "A".."Z":
         SendByte(@A[(char - "A") * 6])
      "a".."z":     
         SendByte(@_a[(char - "a") * 6])
      " ": SendByte(@Space)
      ":": SendByte(@Colon)
      ".": SendByte(@Period)
      ",": SendByte(@Comma)
      "'": SendByte(@Apost)
      "!": SendByte(@Exclam)
      "+": SendByte(@Plus)
      "-": SendByte(@Minus)
      "&": SendByte(@Ampsnd)
      "@": SendByte(@At)
      "_": SendByte(@UndScr)

PRI SendByte(char) | inx
''Sends a Character to the OLED Panel
    repeat inx from 0 to 5 
       Write(BYTE[char][inx])
    return

PRI buildString(character) '' 4 Stack longs
   ifnot(characterToStringPointer)
      bytefill(@characterToString, 0, 255)
   if(characterToStringPointer and (character == 8))
      characterToString[--characterToStringPointer] := 0
   elseif(character and (characterToStringPointer <> 254))
      characterToString[characterToStringPointer++] := character

PRI builtString(resetString) '' 4 Stack Longs
   characterToStringPointer &= not(resetString)
   return @characterToString

PRI Start                    
    outa[SCL]~~                        
    dira[SCL]~~                       
    outa[SDA]~~                           
    dira[SDA]~~                         
    outa[SDA]~                         
    outa[SCL]~                      
  
PRI Stop
    outa[SCL]~~                        
    outa[SDA]~~                        
    dira[SCL]~                        
    dira[SDA]~                         

PRI Write(data) : ackbit 
    ackbit := 0 
    data <<= 24
    repeat 8                           
       outa[SDA] := (data <-= 1) & 1   
       outa[SCL]~~                      
       outa[SCL]~
    dira[SDA]~                         
    outa[SCL]~~
    ackbit := ina[SDA]                 
    outa[SCL]~
    outa[SDA]~                         
    dira[SDA]~~

DAT
''Characters for OLED Screen (5x8 characters)
      Zero   byte  $3E, $41, $41, $41, $3E, $00
      One    byte  $00, $42, $7F, $40, $00, $00 
      Two    byte  $72, $49, $49, $49, $4E, $00
      Three  byte  $22, $41, $49, $49, $36, $00
      Four   byte  $08, $0C, $0A, $7F, $08, $00
      Five   byte  $27, $45, $45, $45, $39, $00
      Six    byte  $37, $49, $49, $49, $32, $00
      Seven  byte  $01, $01, $71, $09, $07, $00
      Eight  byte  $36, $49, $49, $49, $36, $00
      Nine   byte  $26, $49, $49, $49, $36, $00

      A      byte  $7E, $09, $09, $09, $7E, $00
      B      byte  $7f, $49, $49, $49, $36, $00
      C      byte  $3E, $41, $41, $41, $22, $00
      D      byte  $7F, $41, $41, $41, $3E, $00
      E      byte  $7F, $49, $49, $49, $41, $00
      F      byte  $7F, $09, $09, $09, $01, $00
      G      byte  $3E, $49, $49, $49, $3A, $00
      H      byte  $7F, $08, $08, $08, $7F, $00
      I      byte  $00, $41, $7F, $01, $00, $00
      J      byte  $30, $40, $40, $40, $3F, $00
      K      byte  $7F, $08, $14, $22, $41, $00
      L      byte  $7F, $40, $40, $40, $40, $00
      M      byte  $7F, $02, $04, $02, $7F, $00
      N      byte  $7f, $02, $08, $20, $7f, $00
      O      byte  $3E, $41, $41, $41, $3E, $00
      P      byte  $7F, $09, $09, $09, $06, $00
      Q      byte  $3E, $41, $41, $41, $5E, $00
      R      byte  $7F, $09, $09, $09, $76, $00
      S      byte  $26, $49, $49, $49, $32, $00
      T      byte  $01, $01, $7F, $01, $01, $00
      U      byte  $3F, $40, $40, $40, $3F, $00
      V      byte  $1F, $20, $40, $20, $1F, $00
      W      byte  $7F, $20, $10, $20, $7F, $00
      X      byte  $63, $14, $08, $14, $63, $00
      Y      byte  $03, $04, $78, $04, $03, $00
      Z      byte  $61, $51, $49, $45, $43, $00
      _a     byte  $20, $54, $54, $54, $78, $00
      _b     byte  $7F, $68, $64, $64, $38, $00
      _c     byte  $38, $44, $44, $44, $40, $00
      _d     byte  $38, $44, $44, $48, $7F, $00
      _e     byte  $38, $54, $54, $54, $18, $00
      _f     byte  $08, $7E, $09, $01, $02, $00
      _g     byte  $0C, $52, $52, $52, $3E, $00
      _h     byte  $7F, $10, $08, $08, $70, $00
      _i     byte  $00, $44, $7D, $40, $00, $00
      _j     byte  $20, $40, $44, $3D, $00, $00
      _k     byte  $7F, $10, $28, $44, $00, $00
      _l     byte  $00, $41, $7F, $40, $00, $00
      _m     byte  $7C, $04, $18, $04, $78, $00
      _n     byte  $7C, $08, $04, $04, $78, $00
      _o     byte  $38, $44, $44, $44, $38, $00
      _p     byte  $7C, $14, $14, $14, $08, $00
      _q     byte  $08, $14, $14, $18, $7C, $00
      _r     byte  $7C, $08, $04, $04, $08, $00
      _s     byte  $48, $54, $54, $54, $20, $00
      _t     byte  $04, $3F, $44, $40, $20, $00
      _u     byte  $3C, $40, $40, $20, $7C, $00
      _v     byte  $1C, $20, $40, $20, $1C, $00
      _w     byte  $3C, $40, $30, $40, $3C, $00
      _x     byte  $44, $28, $10, $28, $44, $00
      _y     byte  $0C, $50, $50, $50, $3C, $00
      _z     byte  $44, $64, $54, $4C, $44, $00
      
      Space  byte  $00, $00, $00, $00, $00, $00
      Colon  byte  $00, $14, $00, $00, $00, $00  
      Period byte  $00, $60, $60, $00, $00, $00
      Comma  byte  $50, $30, $00, $00, $00, $00
      Apost  byte  $00, $05, $02, $00, $00, $00
      Exclam byte  $00, $00, $5F, $00, $00, $00
      Plus   byte  $08, $08, $3E, $08, $08, $00
      Minus  byte  $08, $08, $08, $08, $00, $00     
      Ampsnd byte  $36, $49, $55, $22, $50, $00
      At     byte  $3E, $4D, $53, $4D, $26, $00
      Undscr byte  $40, $40, $40, $40, $40, $00
      
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