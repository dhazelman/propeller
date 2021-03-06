{{

Original work by:  Kevin McCullough and Beau Schwabe (MMA7455 demonstration - see below).
Original work by:  Martin Hebel (PLX-DAQ demonstration by Martin Hebel - see below)

Modified by:  Greg Denson, 2012 Jan 21

I took a couple of very nice spin programs:  One to handle the MMA7455
accelerometer by Kevin McCullough and Beau Schwabe, and another for the
PLX-DAQ data acquistion by Martin Heble, and combined them to allow me to send data
from the Pauallax MMA7455, 3-axis accelerometer to the PLX-DAQ data aquisition software.
There are also a few excellet Objects used here in my Object that came from these
fine gentlemen that were kind enough to share them.

My intent for combining their work into this object was to create a simple MMA7455-based
tri-axis seismograph.

Thus far, I have kept it all very simple, and am reading the 2g output from the
MMA7455.  However, I have left Kevin's and Beau's code for other modes in the repeat
loop about 2/3 of the way down in 'PUB main' below.  If you want to use those other modes,
or all modes, you will need to do at least these two things:
 - Modify your PLX-DAQ spreadsheet columns so that it will accept the new data.
 - Uncomment the code, below, for the mode(s) you want to use. 

So, I thought I would share what I have done so far so that some of you might be able to
take it and improve on it.  If so, I hope you'll share it back with us as Kevin, Beau, and
Martin did.

If you are not familiar with the PLX-DAQ software, please read its documentation, and/or
start out with my examples.  Then, once you're familiar with it, you can branch out and
change the spreadsheet as you see fit.

NOTE:  There were times while I was testing this arrangement that I had to click on my
charts in the Excel spreadsheet, and edit it to tell the spreadsheet which columns held
the data from my graphs.  You may have to do some work in this area as well, if you want
to see the charts plotted.  Even though you may have issues with this part, you should
still see data appearing in the first spreadsheet when you have everything running correctly.
In PLX-DAQ, only the first worksheet receives data.  So, if you want to use one of the other
example worksheets, you have to move it to the first position.

------------------------------------------------------------------------------------------- 
From here down, are Kevin and Beau's original comments on the program (and maybe a couple
from me tossed in here and there):
-------------------------------------------------------------------------------------------

****************************************************
* MMA7455 3-Axis Accelerometer Spin DEMO #1 Ver 2  *
* Author: Kevin McCullough                         *
* Author: Beau Schwabe                             *
* Copyright (c) 2009 Parallax                      *
* See end of file for terms of use.                *
****************************************************

   History:
                                Version 1 - (03-25-2009) initial concept
                                Version 2 - (06-10-2009) first DEMO release  

How to Use:
 • (Added by GREG:  )If your spreadsheet is already open, be sure spreadsheet is
   'disconnected' before attempting to load program to Propeller, or you'll
   get a message that the COM port is already in use.

 • With board power initially off, connect VIN to 3.3VDC (the same voltage
   powering the Propeller).  Connect GND to board ground.

 • Connect P0, P1, and P2 on the Propeller directly to the CLK, DATA, and CS
   pins on the Digital 3-Axis Accelerometer module.

   GREG:  That's...
   CLK   -> P0
   DATA  -> P1
   CS    -> P2

 • Make sure the "FullDuplexSerial.spin" and "MMA7455L_SPI_v2.spin" files are
   present in the same folder as this top-level spin file.

   GREG:  Actually I used the Extended Full Duplex Serial from suggested in
   his demo of the PLX-DAQ software.  Please read Martin's comments on that
   object for more information.
   
 • Start the Parallax Serial Terminal and set the baud to 38,400 and set the
   proper COM port.  The Parallax Serial Terminal is available on the Propeller
   Software Downloads web page

 • Power on the board.  Download and run this code on the propeller.

 • After Enabling the Parallax Serial Terminal, Check and then Un-Check the
   DTR button on the Parallax Serial Terminal.  
 
 • Acceleration values will stream back to the computer, and can be viewed
   using a generic serial terminal such as the Parallax Serial Terminal
   available on the Propeller Software Downloads web page.

   GREG:  You may know how to stop this from happening, but the serial output
   to the Parallax Serial Terminal seems to be competing with the PLX-DAQ
   software for the connection to the COM port.  So, I could only have one
   of them running at a time.  So, I removed all the out put to the PST window
   so that I could connect to the PLX-DAQ spreadsheet and send the data to it.
   
 • The offset values for each axis can be calibrated by placing the device 
   on a flat horizontal surface and adjusting the corresponding constants
   until the values for each axis read (while in 2g mode):
        X = 0   (0g)
        Y = 0   (0g)
        Z = 63  (+1g)
   The values already present are for demonstration purposes and can
   be easily modified to fine tune your own device. Keep in mind that
   the offset values are in 1/2 bit increments, so for example, to offset
   an axis by 5 counts, the corresponding offset would need to be increased
   by a value of 10.  See the MMA7455L device datasheet for more
   information.

}}

CON

  _clkmode      = xtal1 + pll16x
  _xinfreq      = 5_000_000

  CLKPIN        = 0
  DATAPIN       = 1
  CSPIN         = 2
  
  X_OFFSETVAL   =   12  'Orininally 32            ' X-Axis offset compensation value
  Y_OFFSETVAL   =   45  'Originally 50            ' Y-Axis offset compensation value
  Z_OFFSETVAL   =    0  'Originally  0            ' Z-Axis offset compensation value
{{
   GREG:  I adjusted the offset values above several times to try and get my X,Y values
          to be centered somewhere near 0, and to get the Z value to settle around 63.
          However, I was never entirely successful in getting exactly what I wanted so
          I also made adjustments in the PUB Display routine, below, and they are
          commented there.
        ------------------------------------------------------------------------------
        Original comments on offsets by Kevin and Beau:  
        The Offset value is an iterative process.
        To adjust the Offset, set X_OFFSETVAL, Y_OFFSETVAL, and Z_OFFSETVAL to Zero
        and run the program.

        Multiply the returned value by 2 and subtract from the corresponding current
        offset value.

                  0 - -28 = 28

        Note: - The Offset is valid only at Zero-g, so you will need to orient the
                Z axis so that it is perpendicular to the influence of gravity.

              - At rest, it is possible to see a g force greater than 1 or less than
                1 (where 1g returns 63) because depending on where you are, the force
                of gravity can be stronger or weaker depending on your elevation.   
  
}}
VAR

  long  XYZData[3]
  
OBJ
  Serial        : "Extended_FDSerial"    'Suggested by Martin Heble for use with PLX-DAQ
  SPI           : "MMA7455L_SPI_v2"      'Used to Communicate to the Accelerometer
  PDAQ          : "PLX-DAQ"              'The Parallax Data Acquisition software available
                                         'online at http://www.parallax.com
  
PUB main
  PDAQ.start(31,30,0,38400)                                    ' Rx,Tx, Mode, Baud  
  PDAQ.Label(string("Time, Timer, X_axis, Y_axis, Z_axis"))    ' Label the spreadsheet columns
  PDAQ.ClearData                                               ' Clear present data
  PDAQ.ResetTimer                                              ' Reset timer for seconds interval
                                                               ' GREG: The labels above were the ones for my
                                                               ' PLX-DAQ spreadsheet because the PLX-DAQ provides
                                                               ' the Time data, while the program below provides
                                                               ' the Timer and the XYZ axis readings.  Before
                                                               ' making any modifications to my example, you may
                                                               ' want to download and run Martin Hebel's demo for
                                                               ' PLX-DAQ to get some idea of how it works.  That's
                                                               ' how I learned what to do about adjusting my
                                                               ' spreadsheet columns to work with the MMA7455 data.
 

  'Initialize the device (GREG:  Initialize MMA7455 operating in SPI mode)
  SPI.start(CLKPIN, DATAPIN, CSPIN)

  waitcnt(clkfreq/100+cnt)

{{
         MCTL - Mode control register
   ┌────┬────┬────┬────┬────┬────┬────┬────┐
   │ D7 │ D6 │ D5 │ D4 │ D3 │ D2 │ D1 │ D0 │
   ├────┼────┼────┼────┼────┼────┼────┼────┤
   │ -- │DRPD│SPI3│STON│GLVL│GLVL│MODE│MODE│
   └────┴────┴────┴────┴────┴────┴────┴────┘ 
  
   D7       - don't care          0

   D6(DRPD) - Data ready status   0 - output to INT1 pin
                                  1 - is not output to INT1 pin
                                 
   D5(SPI3W)- Wire Mode           0 - SPI is 4-wire mode
                                  1 - SPI is 3-wire mode
                                 
   D4(STON) - Self Test           0 - not enabled
                                  1 - enabled

   D3(GLVL[1]) - g-Select        00 - 8g ; 16 LSB/g in 8-bit format
   D2(GLVL[0]) - g-Select        10 - 4g ; 32 LSB/g in 8-bit format
                                 01 - 2g ; 64 LSB/g in 8-bit format

                                         ; Note: When reading g in 10-bit
                                         ;       format, resolution is fixed
                                         ;       at 64 LSB/g
                   10-bit g register
   ┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
   │ D9 │ D8 │ D7 │ D6 │ D5 │ D4 │ D3 │ D2 │ D1 │ D0 │
   └────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘ 
   │─────────────────────────────────────│            ; These 8 bits are read in 8g mode
        │─────────────────────────────────────│       ; These 8 bits are read in 4g mode
             │─────────────────────────────────────│  ; These 8 bits are read in 2g mode

   D1(MODE[1]) - Mode Select     00 - Standby
   D0(MODE[0]) - Mode Select     01 - Measurement
                                 10 - Level Detection
                                 11 - Pulse Detection
                                  
}} 

  'Write the X, Y, and Z offset compensation values
  'GREG:  If begin to make some changes, and are experimenting with different setups, and you're having
  'difficulties seeing data come into the PLX-DAQ spreadsheet, experiment some with   'Kevin and Beau's
  'original MMA7455 demo programs and make sure you can see the data in the Parallax Serial Terminal
  'first.  Then you can come back to this make you adjutments when you understand the data you got from
  'the PST terminal. 
  SPI.write(SPI#XOFFL, X_OFFSETVAL)                         
  SPI.write(SPI#XOFFH, X_OFFSETVAL >> 8)
  SPI.write(SPI#YOFFL, Y_OFFSETVAL)
  SPI.write(SPI#YOFFH, Y_OFFSETVAL >> 8)
  SPI.write(SPI#ZOFFL, Z_OFFSETVAL)
  SPI.write(SPI#ZOFFH, Z_OFFSETVAL >> 8)
  
                                  ' GREG:  Some of the comments here are original, and some added by me.
  repeat                          ' Loop to read the accelerometer and send data to the display routine
    waitcnt(clkfreq/100+cnt)      ' Original divisor:  clkfreq/100+cnt  -  Less than 100 slows down the data collection
    Read8BitData(SPI#G_RANGE_2g)  ' Read 8-Bit Output Value for each axis in 2g mode ; then display results
    Display                       ' Call the routine, below, that sends the data to the spreadsheet

 '*************************************************************************************
 '* NOTE:  (GREG)Un-comment routines, below, to turn on display of other modes...     *
 '*         Be sure to set up spreadsheet to capture the data correctly if you do.    *
' *         The Read8BitData() line, above, is for the 8-bit 2g data only.            *
 '*************************************************************************************       

    'Read8BitData(SPI#G_RANGE_4g)  ' Read 8-Bit Output Value for each axis in 4g mode ; then display results
    'Display
          
    'Read8BitData(SPI#G_RANGE_8g)  ' Read 8-Bit Output Value for each axis in 8g mode ; then display results
    'Display

    'Read10BitData                  ' Read 10-Bit Output Value for each axis ; ; then display result
    'Display

PUB Read8BitData(G_RANGE)
    SPI.write(SPI#MCTL, (%0110 << 4)|(G_RANGE << 2)|SPI#G_MODE) 'Initialize the Mode Control register
    XYZData[0] := SPI.read(SPI#XOUT8)                           'repeat for X-axis
    XYZData[1] := SPI.read(SPI#YOUT8)                           'repeat for Y-axis
    XYZData[2] := SPI.read(SPI#ZOUT8)                           'and Z-axis

PUB Read10BitData
    SPI.write(SPI#MCTL, (%0110 << 4)|SPI#G_MODE)                'Initialize the Mode Control register
    DataIn_High := SPI.read(SPI#XOUTH)                          'repeat for X-axis
    DataIn_Low  := SPI.read(SPI#XOUTL)
    XYZData[0]  := DataIn 
    DataIn_High := SPI.read(SPI#YOUTH)                          'repeat for Y-axis
    DataIn_Low  := SPI.read(SPI#YOUTL)
    XYZData[1]  := DataIn    
    DataIn_High := SPI.read(SPI#ZOUTH)                          'and Z-axis
    DataIn_Low  := SPI.read(SPI#ZOUTL)
    XYZData[2]  := DataIn    

PUB Display
' Display Output Value for each axis       ' GREG:  Many of the comments below are from me.
    PDAQ.DataText(string("TIME,TIMER"))    ' Place current time and time since reset    
    PDAQ.Data(~XYZData[0]+1)               ' Send X_axis data (+1 is an adjustment for X axis)
    PDAQ.Data(~XYZData[1])                 ' Send Y_axis data
    PDAQ.Data(~XYZData[2]-3)               ' Send Z_axis data
                                           ' Added -3 to this calculation to get my base gravity on Z-axis
                                           ' down to approximately 63 (normal gravity reading)
    PDAQ.CR                                ' Send a carriage return to start next row on spreadsheet

                                           ' GREG:  I used the +1 and -3 adjustments just to 'normalize' my
                                           ' readings for testing.  It is possible that the -3 should be
                                           ' removed to make the reading more accurate.  As stated by Kevin
                                           ' and Beau in the oiginal comments in the 'CON' section, your
                                           ' actualy gravity (on Z axis) may provide something other thand
                                           ' 63 as its true value.  So, again, this was just for my testin,
                                           ' and you may want to delete these adjustments.
DAT

DataIn        word              ' Data positioning trick to convert Words to Bytes
DataIn_Low    byte    0         ' or Bytes to a Word without using any math overhead
DataIn_High   byte    0

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