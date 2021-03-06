{{General purpose Sixteen-segment alpha-numeric display object. Display up to 14 characters.

  Note that a 14-character display requires 30 Propeller I/O pins, leaving only two pins
  for either USB or EEPROM connection. 
             
   Author: Steven R. Stuart (Adapted from Steve Nicholson's Seven-segment display object)
  Version: 1.6
    Terms: MIT License - See end of file for terms of use. 
  History: 1.6 (21-Dec-2014) Added missing address operator on display buffer symbol DspBuff 
           1.5 (21-Jul-2010) Fixed error when displaying 9 or more characters
           1.4 (20-Dec-2009) Added character code checking to ensure display chars fall within the
                              character table. Default display has been set to six characters.
           1.3 (16-Dec-2009) Fixed error in CharSel table. Fixed error in curly bracket patterns
           1.2 (04-Dec-2009) Increased display support to 14 chars. Map lower case chars to    
                              upper case chars to avoid redundant table entries
           1.1 (02-Dec-2009) Added local display buffer
           1.0 (14-Nov-2009) Initial release
}}

VAR                                           
  long LowCharPin, HighCharPin                          'The pins for specifying chars.
                                                        ' Must be contiguous
                                                        ' HighCharPin can be from 0 to 13 more than LowCharPin
  long Seg0Pin, Seg15Pin                                'The pins for the segments.
                                                        ' Must be contiguous
  long flags
  long stack[10]   
  long runningCogID
  
CON
  isEnabled  = %0001                                    'Display ENABLE flag

PUB Start(charRt, chars, s0, enabled)
''Start the display
''Parameters:
''   charRt - the cathode pin number of the rightmost character
''   chars - the number of characters to display  (up to 14)
''   s0 - the pin number of segment 0 (segment a1)
''   enabled - the initial enabled state

  LowCharPin := charRt
  HighCharPin := charRt + ((chars - 1) <# 13)           'Limit to 14 chars
  Seg0Pin := s0
  Seg15Pin := s0 + 15
  dira[Seg0Pin..Seg15Pin]~~                             'Set segment pins to outputs
  dira[LowCharPin..HighCharPin]~~                       'Set char pins to outputs
  outa[Seg0Pin..Seg15Pin]~                              'Turn off all segments
  dira[LowCharPin..HighCharPin]~~                       'Turn off all chars
  if enabled                                            'Set initial enabled state
    flags |= isEnabled
  else
    flags~
  stop
  runningCogID := cognew(ShowStr, @stack) + 1

PUB Stop
''Shutdown the display
  if runningCogID
    cogstop(runningCogID~ - 1)

PUB Enable
''Enable the display
  flags |= isEnabled

PUB Disable
''Disable (blank) the display
  flags &= !isEnabled

PUB SetDisplay(strAddr)
''Move the desired display string to local buffer  
  bytemove(@DspBuff,strAddr,14)
      
PRI ShowStr | stringPos, char, bias
' ShowStr runs in its own cog and continually updates the display
  dira[Seg0Pin..Seg15Pin]~~                               'Set segment pins to outputs
  dira[LowCharPin..HighCharPin]~~                         'Set character pins to outputs
  repeat
    if flags & isEnabled
      repeat stringPos from 0 to HighCharPin - LowCharPin 'Get next char position
        char := byte[@DspBuff+stringPos]&127 #>32         'Get char and validate
        case char                                         'Adjust char table pointer
          "a".."z": bias := -128                          ' Map lowercase to uppercase
          123..127: bias := -116                          ' Adjust chars above the lowcase set 
          other   : bias := -64                           ' Skip unprintable chars       
        outa[Seg15Pin..Seg0Pin]~                          'Clear the segments to avoid flicker                                                        
        outa[LowCharPin..HighCharPin] := word[@CharSel +stringPos *2] 'Enable the next character
        outa[Seg15Pin..Seg0Pin] := word[@CharTab +char *2 +bias]      'Output the pattern
        waitcnt (clkfreq / 10_000 + cnt)                  'This delay value can be tweaked to adjust
                                                          ' display brightness
    else
      outa[HighCharPin..LowCharPin]~~                     'Disable all characters
      waitcnt (clkfreq / 10 + cnt)                        'Wait 1/10 second before checking again
     
DAT
{{
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│ASCII character codes 0 through 31 are normally unprintable control codes and most have no│
│defined 16-segment pattern so have been excluded from the display table.                  │
│Characters outside the range of 32..127 will display as a space character (code Asc_032)  │
└──────────────────────────────────────────────────────────────────────────────────────────┘
}}
  CharTab

'                    a1 a2      
'                   | |\ \   | |   / /| |
'  segment          | | \h\  |i|  /j/ | |   
'  identification   |f|  \ \ | | / /  |b|
'                   | |   \ \| |/ /   | |   
'                    g1 g2      
'                   | |   / /| |\ \   | | 
'                   |e|  / / | | \ \  |c| 
'                   | | /m/  |l|  \k\ | | 
'                   | |/ /   | |   \ \| |
'                    d1 d2
' 
'                    Character table                  
'                   ─────────────────
'      segments:     mlkjihggfeddcbaa
'                          21  21  21
{
  Asc_000   word    %0000000000000000   'NUL    (Null char)
  Asc_001   word    %0000000000000000   'SOH    (Start of Header)
  Asc_002   word    %0000000000000000   'STX    (Start of Text)
  Asc_003   word    %0000000000000000   'ETX    (End of Text)
  Asc_004   word    %0000000000000000   'EOT    (End of Transmission)
  Asc_005   word    %0000000000000000   'ENQ    (Enquiry)
  Asc_006   word    %0000000000000000   'ACK    (Acknowledgment)
  Asc_007   word    %0000000000000000   'BEL    (Bell)
  Asc_008   word    %0000000000000000   'BS     (Backspace)
  Asc_009   word    %0000000000000000   'HT     (Horizontal Tab)
  Asc_010   word    %0000000000000000   'LF     (Line Feed)
  Asc_011   word    %0000000000000000   'VT     (Vertical Tab)
  Asc_012   word    %0000000000000000   'FF     (Form Feed)
  Asc_013   word    %0000000000000000   'CR     (Carriage Return)
  Asc_014   word    %0000000000000000   'SO     (Shift Out)
  Asc_015   word    %0000000000000000   'SI     (Shift In)
  Asc_016   word    %0000000000000000   'DLE    (Data Link Escape)
  Asc_017   word    %0000000000000000   'DC1    (Device Control 1) (XON)
  Asc_018   word    %0000000000000000   'DC2    (Device Control 2)
  Asc_019   word    %0000000000000000   'DC3    (Device Control 3) (XOFF)
  Asc_020   word    %0000000000000000   'DC4    (Device Control 4)
  Asc_021   word    %0000000000000000   'NAK    (Negative Acknowledgemnt)
  Asc_022   word    %0000000000000000   'SYN    (Synchronous Idle)
  Asc_023   word    %0000000000000000   'ETB    (End of Trans. Block)
  Asc_024   word    %0100101100110010   'CAN    (Cancel)
  Asc_025   word    %0101011100000000   'EM     (End of Medium)
  Asc_026   word    %0100101111110011   'SUB    (Substitute)
  Asc_027   word    %0000101000000110   'ESC    (Escape)
  Asc_028   word    %0001010011000000   'FS     (File Separator)
  Asc_029   word    %0100101100110000   'GS     (Group Separator)
  Asc_030   word    %1110100000000000   'RS     (Reqst to Send)(Rec. Sep.)
  Asc_031   word    %0101110000000000   'US     (Unit Separator)
}
  Asc_032   word    %0000000000000000   'SP     (Space)  
  Asc_033   word    %0100100000110000   '!      (exclamation mark)
  Asc_034   word    %0000100010000000   '"      (double quote)
  Asc_035   word    %1111111111111111   '#      (number sign)
  Asc_036   word    %0100101110111011   '$      (dollar sign)
  Asc_037   word    %1101101110101001   '%      (percent)
  Asc_038   word    %1101100000111010   '&      (ampersand)
  Asc_039   word    %0001000000000000    '      (single quote)
  Asc_040   word    %0011000000000000   '(      (left/open parenthesis)
  Asc_041   word    %1000010000000000   ')      (right/closing parenth.)
  Asc_042   word    %1111111100000000   '*      (asterisk)
  Asc_043   word    %0100101100000000   '+      (plus)
  Asc_044   word    %1000000000000000   ',      (comma)
  Asc_045   word    %0000001100000000   '-      (minus or dash)
  Asc_046   word    %0100000101100000   '.      (dot)
  Asc_047   word    %1001000000000000   '/      (forward slash)
  Asc_048   word    %1001000011111111   '0
  Asc_049   word    %0000000000001100   '1
  Asc_050   word    %0000001101110111   '2
  Asc_051   word    %0000001000111111   '3
  Asc_052   word    %0000001110001100   '4
  Asc_053   word    %0000001110111011   '5
  Asc_054   word    %0000001111111001   '6
  Asc_055   word    %0000000000001111   '7
  Asc_056   word    %0000001111111111   '8
  Asc_057   word    %0000001110111111   '9
  Asc_058   word    %0100100000000000   ':      (colon)
  Asc_059   word    %1000100000000000   ';      (semi-colon)
  Asc_060   word    %0011000000000000   '<      (less than)
  Asc_061   word    %0000001100110000   '=      (equal sign)
  Asc_062   word    %1000010000000000   '>      (greater than)
  Asc_063   word    %0100001000000110   '?      (question mark)
  Asc_064   word    %0000101011110111   '@      (AT symbol)
  Asc_065   word    %0000001111001111   'A
  Asc_066   word    %0100101000111111   'B
  Asc_067   word    %0000000011110011   'C
  Asc_068   word    %0100100000111111   'D
  Asc_069   word    %0000001111110011   'E
  Asc_070   word    %0000000111000011   'F
  Asc_071   word    %0000001011111011   'G
  Asc_072   word    %0000001111001100   'H
  Asc_073   word    %0100100000000000   'I
  Asc_074   word    %0000000001111100   'J
  Asc_075   word    %0011000111000000   'K
  Asc_076   word    %0000000011110000   'L
  Asc_077   word    %0001010011001100   'M
  Asc_078   word    %0010010011001100   'N
  Asc_079   word    %0000000011111111   'O
  Asc_080   word    %0000001111000111   'P
  Asc_081   word    %0010000011111111   'Q
  Asc_082   word    %0010001111000111   'R
  Asc_083   word    %0010000110110011   'S
  Asc_084   word    %0100100000000011   'T
  Asc_085   word    %0000000011111100   'U
  Asc_086   word    %1001000011000000   'V
  Asc_087   word    %1010000011001100   'W
  Asc_088   word    %1011010000000000   'X
  Asc_089   word    %0101010000000000   'Y
  Asc_090   word    %1001000000110011   'Z
  Asc_091   word    %0100100000100010   '[      (left/opening bracket)
  Asc_092   word    %0010010000000000   '\      (back slash)
  Asc_093   word    %0100100000010001   ']      (right/closing bracket)
  Asc_094   word    %1001000000000110   '^      (caret/circumflex)
  Asc_095   word    %0000000000110000   '_      (underscore)
  Asc_096   word    %0000010000000000   '`      (back tick)
{
  Asc_097   word    %0000001111001111   'a       
  Asc_098   word    %0100101000111111   'b      
  Asc_099   word    %0000000011110011   'c       Lower case characters are mapped
  Asc_100   word    %0100100000111111   'd       to upper case patterns
  Asc_101   word    %0000001111110011   'e       
  Asc_102   word    %0000000111000011   'f
  Asc_103   word    %0000001011111011   'g
  Asc_104   word    %0000001111001100   'h
  Asc_105   word    %0100100000000000   'i
  Asc_106   word    %0000000001111100   'j
  Asc_107   word    %0011000111000000   'k         
  Asc_108   word    %0000000011110000   'l         
  Asc_109   word    %0001010011001100   'm         
  Asc_110   word    %0010010011001100   'n
  Asc_111   word    %0000000011111111   'o
  Asc_112   word    %0000001111000111   'p
  Asc_113   word    %0010000011111111   'q
  Asc_114   word    %0010001111000111   'r
  Asc_115   word    %0010000110110011   's
  Asc_116   word    %0100100000000011   't
  Asc_117   word    %0000000011111100   'u
  Asc_118   word    %1001000011000000   'v
  Asc_119   word    %1010000011001100   'w
  Asc_120   word    %1011010000000000   'x
  Asc_121   word    %0101010000000000   'y
  Asc_122   word    %1001000000110011   'z
}
  Asc_123   word    %0100100100010010   '{      (left/opening brace)
  Asc_124   word    %0100100000000000   '|      (vertical bar)
  Asc_125   word    %0100101000100001   '}      (right/closing brace)
  Asc_126   word    %0000001101000100   '~      (tilde)
  Asc_127   word    %0100001011111111   'DEL    (delete)

' Common cathode 16-segment displays are activated by bringing the cathode to ground
  CharSel   word    %11111111_11111110  'Rightmost character
            word    %11111111_11111101  
            word    %11111111_11111011
            word    %11111111_11110111
            word    %11111111_11101111
            word    %11111111_11011111                                          
            word    %11111111_10111111  
            word    %11111111_01111111  
            word    %11111110_11111111  
            word    %11111101_11111111
            word    %11111011_11111111
            word    %11110111_11111111
            word    %11101111_11111111
            word    %11011111_11111111  'Leftmost character of a 14 char display      

  DspBuff   byte    "00000000000000"    '14-byte display buffer

{{
┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                             TERMS OF USE: MIT License                                         │                                                                           
├───────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated   │
│documentation files (the "Software"), to deal in the Software without restriction, including without limitation│
│the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,   │
│and to permit persons to whom the Software is furnished to do so, subject to the following conditions:         │                                                         │
│                                                                                                               │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions  │
│of the Software.                                                                                               │
│                                                                                                               │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED  │
│TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL  │
│THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF  │
│CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       │
│DEALINGS IN THE SOFTWARE.                                                                                      │
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}   