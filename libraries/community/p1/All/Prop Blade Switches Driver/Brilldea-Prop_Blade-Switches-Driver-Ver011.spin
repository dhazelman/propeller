''**************************************
''
''  Prop Blade Switch Driver Ver. 01.1
''
''  Timothy D. Swieter, E.I.
''  www.brilldea.com
''
''  Copyright (c) 2008 Timothy D. Swieter, E.I.
''  See end of file for terms of use.
''
''  Updated: June 11, 2008
''
''Description:
''      This program reads the multiplexed switches on the Prop Blade.  This
''      code runs in a seperate cog but needs to be started from the "main" routine.
''      Call "start" with the appropriate variables and the new cog will start and
''      begin processing switch input. The switches are not debounced, but performance
''      sound be OK.  Call the "GetDMXAddress" or "GetSwitch" routine to read
''      the inputs. 
''
''Reference:
''      Prop Blade Schematic
''
''Revision Notes:
'' 1.0 Code Release
'' 1.1 Update switch reading routine, it was not working properly to read
''      the same switch on seperate banks (6/11/2008)
''
''**************************************
CON               'Constants to be located here
'***************************************                       

  '***************************************
  ' System Definitions     
  '***************************************

  _OUTPUT       = 1             'Sets pin to output in DIRA register
  _INPUT        = 0             'Sets pin to input in DIRA register  
  _HIGH         = 1             'High=ON=1=3.3v DC
  _ON           = 1
  _LOW          = 0             'Low=OFF=0=0v DC
  _OFF          = 0
  _ENABLE       = 1             'Enable (turn on) function/mode
  _DISABLE      = 0             'Disable (turn off) function/mode

  '***************************************
  ' Misc Definitions       
  '***************************************
  
  _debounceMask = $FE00         'Used to determine when the switch is fully on
  _edgeMask     = $FF00         'Used to detect the edge of a switch press (one bit more than debounce mask)

  _swEdgeDetc   = %0000_1111    'Pattern used to signal when an edge is detected
  _swOn         = %1111_1111    'Pattern used to indicate the sw is on

  
'**************************************
VAR               'Variables to be located here
'***************************************

  'Cog related
  long  cog                     'Values of cog running driver code
  long  stack[30]               'Stack space for spin cog

  'Switches
  word  DMXAddress              '9-bit value read from DIP switches 1-9
  byte  OptionSw                '1-bit value read from DIP Switches 10
  byte  Sw1                     '1-bit value read from Tac Switches 1
  byte  Sw2                     '1-bit value read from Tac Switches 2
  byte  Sw3                     '1-bit value read from Tac Switches 3
  byte  Sw4                     '1-bit value read from Tac Switches 4
  byte  Sw5                     '1-bit value read from Tac Switches 5

  word swState[6]
  

'***************************************
OBJ               'Object declaration to be located here
'***************************************

  'nada

'***************************************
PUB start(_b0, _b1, _b2, _s1, _s2, _s3,_s4, _s5) : okay | t0
'***************************************
'' Start the switch driver - starts a cog and then setup I/O and variables (only allows one cog)

  'Keeps from two cogs running
  stop                                                  

  'Qualify the I/O pins to make sure they are valid
  if lookdown(_b0: 31..0)
    t0++    
  if lookdown(_b1: 31..0)
    t0++
  if lookdown(_b2: 31..0)
    t0++
  if lookdown(_s1: 31..0)
    t0++
  if lookdown(_s2: 31..0)
    t0++
  if lookdown(_s3: 31..0)
    t0++
  if lookdown(_s4: 31..0)
    t0++
  if lookdown(_s5: 31..0)
    t0++

  if t0 == 8
    'Start a cog with the SPIN routine
    okay:= cog:= cognew(SwitchMultiplex(_b0,_b1,_b2,_s1,_s2,_s3,_s4,_s5), @stack) + 1 'Returns 0-8 depending on success/failure


'***************************************
PUB Stop
'***************************************
'' Stops a cog running the switch driver (only allows one cog)

  if cog
    cogstop(cog~ -  1)

    
'***************************************
PUB GetDMXAddress : DMXAdd
'***************************************
'' Returnes the 9-bit DMX address

  DMXAdd := DMXAddress

  
'***************************************
PUB GetSwitch(_sw) : Switch
'***************************************
'' Returns the information for the switch requested, 0 = option DIP switch, 1-5 = tac switch

  if lookdown(_sw: 5..0)
    if _sw == 0
      Switch := OptionSw
    if _sw == 1
      Switch := Sw1
    if _sw == 2
      Switch := Sw2
    if _sw == 3
      Switch := Sw3
    if _sw == 4
      Switch := Sw4
    if _sw == 5
      Switch := Sw5

      
'***************************************
PRI SwitchMultiplex(_bank0,_bank1,_bank2,_sw1,_sw2,_sw3,_sw4,_sw5) | t0
'***************************************
'' PRIVATE ROUTINE - this routine goes through the multiplex to gather the data and appropriately place it

  'Initialize the I/O direction and state
  'The banks are set to inputs, high impedance.  When a bank needs to be read, it is switch to output
  'and placed in a low state.  Only one bank at a time can be read.
  DIRA[_bank0] := _INPUT        'DIP Switch 1-5
  DIRA[_bank1] := _INPUT        'DIP Switch 6-10
  DIRA[_bank2] := _INPUT        'Tac Switch 1-5

  DIRA[_sw1]   := _INPUT
  DIRA[_sw2]   := _INPUT
  DIRA[_sw3]   := _INPUT
  DIRA[_sw4]   := _INPUT
  DIRA[_sw5]   := _INPUT
  
  OUTA[_bank0] := _HIGH
  OUTA[_bank1] := _HIGH
  OUTA[_bank2] := _HIGH

  'Infinite loop
  repeat

    '***************************************
    'Read the 9-bit DMX address and the 1-bit option switch
    'First set the bank for switch 1-5, set the direction to output and set the bank low
    DIRA[_bank0] := _OUTPUT
    OUTA[_bank0] := _LOW

    'then read and set the bits in the address using OR (the switches are high when off and low when on)
    t0 := ina[_sw5.._sw1]
   
   'Restore the bank to input
    DIRA[_bank0] := _INPUT
    
    '***************************************
    'Next set the other bank to output and to low
    DIRA[_bank1] := _OUTPUT
    OUTA[_bank1] := _LOW

    'then read and set the bits in the address for the new set using OR (the switches are high when off and low when on)
    t0 := (ina[_sw5.._sw1] << 5) | t0
    'set the DMXAddress to the value read from the switches after invetering the read value and applying a mask
    DMXAddress := !t0 & %1_1111_1111

    'Check the fith switch to see if the otion bit is on or off (the switch is high when off and low when on)
    if ina[_sw5]
      OptionSw := false
    else
      OptionSw := true

    'finally restore the bank to input
    DIRA[_bank1] := _INPUT

    '***************************************
    'Read the Tac switches and debounce
    'First set the correct bank to output and low
    DIRA[_bank2] := _OUTPUT
    OUTA[_bank2] := _LOW

    'Process the first switch
    swState[1] := (swState[1] << 1) | ina[_sw1] | _debounceMask
    if swState[1] == _edgeMask
      Sw1 := _swEdgeDetc
    elseif swState[1] == _debounceMask
      Sw1 := _swOn
    else
      Sw1 := false
      
    'Process the second switch
    swState[2] := (swState[2] << 1) | ina[_sw2] | _debounceMask
    if swState[2] == _edgeMask
      Sw2 := _swEdgeDetc
    elseif swState[2] == _debounceMask
      Sw2 := _swOn
    else
      Sw2 := false
    
    'Process the third switch
    swState[3] := (swState[3] << 1) | ina[_sw3] | _debounceMask
    if swState[3] == _edgeMask
      Sw3 := _swEdgeDetc
    elseif swState[3] == _debounceMask
      Sw3 := _swOn
    else
      Sw3 := false

    'Process the fourth switch
    swState[4] := (swState[4] << 1) | ina[_sw4] | _debounceMask
    if swState[4] == _edgeMask
      Sw4 := _swEdgeDetc
    elseif swState[4] == _debounceMask
      Sw4 := _swOn
    else
      Sw4 := false

    'Process the fifth switch
    swState[5] := (swState[5] << 1) | ina[_sw5] | _debounceMask
    if swState[5] == _edgeMask
      Sw5 := _swEdgeDetc
    elseif swState[5] == _debounceMask
      Sw5 := _swOn
    else
      Sw5 := false

    'Restore the bank to input
    DIRA[_bank2] := _INPUT

    
'***************************************
DAT
'***************************************
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