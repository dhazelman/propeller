{{

<MAX1202 ADC, Version 1.0, author(James Long), Sept 2006>

┌──────────────────────────────────────────┐
│ Copyright (c) 2006 James Long │               
│     See end of file for terms of use.    │               
└──────────────────────────────────────────┘

}}

CON

  _clkmode      = xtal1 + pll16x                        ' use crystal x 16
  _xinfreq      = 5_000_000
  
  ClkAdc        = 11             ' A/D clock  (Change These Values/Pins As Needed)
  CsAdc         = 5             ' Chip Select for ADC
  AoutAdc       = 13             ' A/D Data sent to the ADC
  AinAdc        = 12             ' A/D Data recieved from the ADC
  Sstrb         = 3             ' SSTRB signal for max 1202
  ready         = 16            ' Cog ready signal (pin to read for ready state)
  
{{
     ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
     │   Control-Byte Format                                                                                           TABLE 1│
     │   BIT 7(MSB)   BIT 6 BIT  5 BIT 4 BIT 3 BIT 2 BIT 1  BIT 0(LSB)                                                        │
     │   START        SEL2  SEL1   SEL0  RNG   BIP   PD1    PD0                                                               │
     │                                                                                                                        │
     │   BIT        NAME           DESCRIPTION                                                                                │
     │   7 (MSB)    START          First logic 1 after CS goes low defines the beginning of the control byte.                 │
     │   6          SEL2           These 3 bits select the desired “on” channel (Table 2 or 3 depending on SGL/DIF).          │
     │   5          SEL1                                                                                                      │
     │   4          SEL0                                                                                                      │
     │   3          UNI/BIP        Selects the unipolar or bipolar conversion mode (1 = GND to Vref)(0 = -Vref/2 to +Vref/2)  │
     │   2          SGL/DIF        Selects Single Ended or differential conversion (Table 2 & 3).                             │
     │   1          PD1            Select clock and power-down modes (Table 4).                                               │
     │   0 (LSB)    PD0                                                                                                       │
     └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
     ┌─────────────────────────────────────────┐
     │   (Single Ended)                 TABLE 2│    
     │   SEL2 SEL1 SEL0 CHANNEL     (SGL/DIF=1)│
     │   0    0    0    CH0                    │
     │   1    0    0    CH1                    │
     │   0    0    1    CH2                    │
     │   1    0    1    CH3                    │
     │   0    1    0    CH4                    │
     │   1    0    1    CH5                    │
     │   0    1    1    CH6                    │
     │   1    1    1    CH7                    │
     └─────────────────────────────────────────┘
     ┌─────────────────────────────────────────┐
     │  (Differential Ended)            TABLE 3│   
     │  SEL2 SEL1 SEL0 CHANNEL      (SGL/DIF=0)│
     │  0    0    0    CH0+ CH1-               │
     │  0    0    1    CH2+ CH3-               │
     │  0    1    0    CH4+ CH5-               │
     │  0    1    1    CH6+ CH7-               │
     │  1    0    0    CH0- CH1+               │
     │  1    0    1    CH2- CH3+               │
     │  1    1    0    CH4- CH5+               │
     │  1    1    1    CH6- CH7+               │
     └─────────────────────────────────────────┘
     ┌─────────────────────────────────────────────────────────────┐
     │    Power-Down and Clock Selection                    TABLE 4│
     │   PD1   PD0   MODE                                          │
     │   0     0     Full power-down(Idd=2µA, internal reference)  │
     │   0     1     Fast power-down(Idd=30µA, internal reference) │
     │   1     0     Internal clock mode                           │
     │   1     1     External clock mode                           │
     └─────────────────────────────────────────────────────────────┘


For example 0v-5v CH0, single ended, unipolar, no power down, internal reference is %10001110

How to Start a Conversion
The MAX1202 uses either an external serial
clock or the internal clock to complete an acquisition
and perform a conversion. In external mode, the
external clock shifts data in and out. See Table 4 for
details on programming clock modes.
The falling edge of CS does not start a conversion on
the MAX1202; a control byte is required for
each conversion. Acquisition starts after the sixth bit is
programmed in the input control byte. 
Keep CS low during successive conversions. If a startbit
is received after CS transitions from high to low, but
before the output bit 6 (D6) becomes available, the current
conversion will terminate and a new conversion will
begin.

}}

OBJ
  bs2   :       "BS2_FUNCTIONS"                                                 'Set an alias for BS2_functions to bs2
  
  delay :       "timing"                                                        'Set an alias for timing to delay

var
  long Value2Pass                                                               'Variable for value coming into the max_1202 cog
  long Stack[9]                                                                'Stack space for the new cog
  
PUB start (ReturnAirpress,control_byte)                                           'Initiate the Max_1202 Cog with returnaddress being sent out and control_bit being received in
  
  cognew(get_value(ReturnAirpress),@Stack)                                       'Start Cog

PUB getairspeed(control_byte)                                                  'Method to change the control_bit value

  Value2Pass := control_byte                                                     'Change names to keep name globally unique(Variable-control_bit)
  
PRI get_value(ReturnAirpress)| temp                                              'The main ADC loop (returnaddress = value to send out to parent Object)(temp = value received from the ADC itself)
                      
  dira[CsAdc]~~                                                                 '' set max 1202 cs pin as output
  outa[CsAdc] := 0                                                            '' set max 1202 cs low (this pin goes low for the ADC to receive information)
  bs2.SHIFTOUT(AoutAdc, ClkAdc, Value2Pass, BS2#MSBFIRST,8 )                  '' send control bit out(send the value that was originally control_bit to the ADC chip)(This is a byte)                                         
  outa[CsAdc] := 1                                                            '' set max 1202 cs high(This pin is returned high for the adc to start conversion of the electrical value of it's inputs) 
  outa[CsAdc] := 0                                                            '' set max 1202 cs low (this pin goes low for the ADC to transmit the value of selected channel)
  temp := bs2.SHIFTIN(AinAdc, ClkAdc, BS2#MSBPOST,12)                         '' temp = receive adc value in (this is 12 bits.....)
  outa[CsAdc] := 1                                                            '' set max 1202 cs high(Pin returned to high)                                                                                                                        
  word[ReturnAirpress] := temp                                                 '' Send ADC value to the return address(this is the value that is sent to the Parent Object)



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