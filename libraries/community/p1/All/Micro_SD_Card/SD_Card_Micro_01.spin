{{
SD_Card_Micro_01.spin

Copyright (c) 2011 Greg Denson
See end of file for terms of use 

Based on a tutorial by Jeff Ledger (Original tutorial can be found at:  http://gadgetgangster.com/tutorials/331)

**** THIS PROGRAM WORKS WELL FOR BASIC MICRO SD CARD COMMUNICATION - I USE IT AS A TEMPLATE FOR MICRO SD CARDS OBJECTS ****

Original Program Created By:
Jeff Ledger (Gadget Gangster Tutorial)

Modified Program Created By:
Greg Denson, 2011-05-30 to run with my PPD Board and SD card holder.

Modified By:
Greg Denson, 2011-06-29 to use the PPD Board with the Parallax Micro SD Card adapter/holder.

Don't get too excited!  This program is basically the same as the demo in the tutorial mentioned above.  It is very simple
and is mainly intended to give you a template to use as part of any program where you need to read and write some text
to a Micro SD Card.  I've added a lot of comments, and a few extra steps to help beginners along.
 
When searching the Propeller Object Exchange for "Micro SD", I got no results.  So, I thought I would update a
demo program for the larger SD Card, get it working with the Micro SD card and adapter, and show the pin connections, etc.,
that are required.

I thought this might be helpful to newcomers who might not be sure whether or not the objects and basic workings for SD and
Micro SD cards were similar. So, hopefully, now when someone searches for "Micro SD" they will bring up a basic starting point,
and learn that, for the most part, they can treat the Micro SD like the larger SD card. The biggest differences you may find
are the way the various adapter boards from different suppliers expose the connections to you, and the way those connections
are labeled.  So, while there's an example of one way to do it in this demo, if you are using different hardware, be sure
to pay attention to the different pin labels, pin availability, power requirements, etc.

This program works well with the Micro SD Card holder (Parallax Micro SD Card adapter) mounted on the Professional Development Board.
I assume that it would also work well with other Propeller boards such as the Propeller Demo Board.
If you are using the Parallax card adapter, and a Parallax Propeller board, then you should be able to use the pin numbers shown
below, since they match the labels on my Parallax Micro SD Card adapter and Propeller board.  But, again, if you are using
different hardware, pay attention to the different labels, pins used, power requirements, etc.

This program uses the Parallax Serial Terminal program to allow the user to input data.  Of course, you could also adapt
other means of display - using a TV or VGA interface, large LCD display, etc.

I noticed, on at least one occasion when developing a demo program for the larger SD cards, that I had to restart the terminal
and re-compile the program after removing the SD Card to read the data on my PC.  Not sure what happened, but this program told
me it had failed to mount the SD Card.  In any case, a restart restored the communications, so try that if you
lose communications with your Micro SD Card as well.  I've since learned some better ways to start up the serial terminal to avoid
most of these communication issues.
}}

CON
  _clkmode = xtal1 + pll16x             ' Set up the clock frequencies
  _xinfreq = 5_000_000

'  CD  = 4       ' Propeller Pin 4 - Uncomment this line if you are using the Chip Detect function on the card. See below. 
  CS  = 3       ' Propeller Pin 3 - Set up these pins to match the Parallax Micro SD Card adapter connections.
  DI  = 2       ' Propeller Pin 2 - For additional information, download and refer to the Parallax PDF file for the Micro SD Adapter.                        
  CLK = 1       ' Propeller Pin 1 - The pins shown here are the correct pin numbers for my Micro SD Card adapter from Parallax                               
  D0  = 0       ' Propeller Pin 0 - In addition to these pins, make the power connections as shown in the following comment block.


{{ Making the Connections...

(1)  Connections to the SD Card holder from uController.com are shown in the diagram below:                                                       

   Parallax Micro 
   SD Card Holder      PROPELLER (Professional Development Board)
            ───┐       ┌───
         GND   │─────│ GND
         3.3V  │─────│ +3.3 Volts
         CD    │─────│ NC   No Connection  -  See notes below - Card Select - Not actually used in this basic demo
         DAT2  │─────│ NC   No Connection  -  See notes below
         CS    │─────│ P3
         DI    │─────│ P2
         SCLK  │─────│ P1
         D0    │─────│ P0
         DAT1  │─────│ NC   No Connection  -  See notes below
            ───┘       └───

NOTE:  The PDF document for the Parallax Micro SD Card adapter states that it can be connected using either the SD Card bus technique or via SPI.
       Connectors for either method are available on on the Parallax adapter.  However, for use with the FSRW.SPIN object, that I used in
       this demo, the DAT1 and DAT2 connecting pins are not needed.

       The CD connection on the Micro SD Card adapter is the Card Detect pin.  The Parallax Micro SD Card adapter has a Card Detect switch
       built into the card holder.  If you wish to use that switch as part of your program, you would want to make a connection from CD to
       Propeller Pin 4, and provide some code to read the pin.  I did a VERY fast and not so thorough scan of of the methods in FSRW.spin, and
       didn't see a use of CD in that Object, but again, it was a very fast scan.  I checked the 'mount' method used below more than once, and
       the CD pin was definitely not addressed there.  So, you may find use of CD in another ojbect or write your own code if you want to use it.
       
}}
                                      
OBJ
  sdfat : "fsrw"                       ' Download the fswr.spin object from the Parallax Propeller Object Exchange (OBEX), accessed from parallax.com
  pst   : "Parallax Serial Terminal"   ' If you don't already have it in your working directory, you can also download this object from OBEX.
  
PUB demo | insert_card, text
  
  'This section will start the Parallax Serial Terminal to allow you to communicate with the Micro SD Card.
  'I've set up a 'waitcnt' for 8 seconds to allow me time to launch the serial terminal and get ready to receive the first messages.
  'Once you get things working the way you want, and don't need a delay this long, you can shorten or eliminate it.

  pst.Start(115_200)                    ' Start the terminal at 115,200 baud
  waitcnt(clkfreq*8 + cnt)              ' Increase the 8 if more time is required, decrease or eliminate it if the delay is too long.
  
  'This section uses methods from the FSRW.SPIN Object to manipulate data on the Micro SD Card.
  'It will let you know if the card is not correctly mounted, and the program will abort at that point.
  
  insert_card := \sdfat.mount_explicit(D0, CLK, DI, CS)        ' Here we call the 'mount' method using the 4 pins described in the 'CON' section.
  if insert_card < 0                                           ' If mount returns a zero...
    pst.str(string(13))                                        ' Print a carriage return to get a new line.
    pst.str(string("The Micro SD Card was not found!"))        ' Print the failure message.
    pst.str(string(13))                                        ' Carriage return...
    pst.str(string("Insert card, or check your connections.")) ' Remind user to insert card or check the wiring.
    pst.str(string(13))                                        ' And yet another carriage return.
    abort                                                      ' Then we abort the program.
        
  
  pst.str(string(13))
  pst.str(string("Micro SD card was found!"))                  ' Let the user know the card is properly inserted.
  pst.str(string(13))
  
  pst.str(string(13))
  pst.str(string("Type a short phrase to save on the card:  "))' Prompt user to enter some text to be saved on the Micro SD Card.
  pst.str(string(13))
  pst.str(string("Then press <ENTER>"))                        ' Remind the user to press <ENTER> after each entry
  pst.str(string(13))
  
  pst.strin(text)                         ' Receive the line of text entered in the Parallax Serial Terminal window.                                                    
  
  sdfat.popen(string("output.txt"), "a")  ' Open output.txt, a text file, to receive your line of text.
                                          ' Change "a" to "w" if you want to overwrite the text each time.
                                          ' The "a" option will append text to the end of the file every time you write to it.
                                                                                  
  sdfat.pputs((text))                     ' Now, we actually put the line of text into the file we opened on the card.

  sdfat.pclose                            ' Close the file - it will be saved on the Micro SD Card
                                          ' Hopefully you have a card reader where you can insert the
                                          ' Micro SD Card and read the text in your file!


' Now, we're going to repeat the above input section to show you that we can re-open the file and append more text to it.
' Hopefully this will give you some ideas on how to expand the demo to do greater things in your own programs.

' In addition, some of these lines can be made more compact once you get the idea.  For example, this line:
' pst.str(string(13, "This time, type another sentence...", 13))
' can replace three of the lines I've been using below.  I used the expanded version for clarity, and to give room for
' more comments in the sections above.  So, there's plenty of room to make improvements in this demo as you begin to use the
' code in your own programs in actual practice.

  
  pst.str(string(13))
  pst.str(string("This time, type another sentence..."))' Prompt user to enter some text to be saved on the Micro SD Card.
  pst.str(string(13))
  pst.str(string("And press <ENTER>"))    ' Prompt user to press <ENTER> again.
  pst.str(string(13))
  
  pst.strin(text)                         ' Receive the line of text entered in the Parallax Serial Terminal window.                                                    
  
  sdfat.popen(string("output.txt"), "a")  ' Open output.txt, a text file, to receive your line of text.
                                          ' Change "a" to "w" if you want to overwrite the text each time.
                                          ' The "a" option will append text to the end of the file every time you write to it.
                                                                                  
  sdfat.pputs((text))                     ' Now, we actually put the line of text into the file we opened on the card.

  sdfat.pclose                            ' Close the file - it will be saved on the Micro SD Card
                                          ' Hopefully you have a card reader where you can insert the
                                          ' Micro SD Card and read the text in your file!

  pst.str(string(13))                     ' In this section, we let the user know that the file write has been completed:
  pst.str(string("Text was written to your output file on the Micro SD Card"))
  pst.str(string(13))
  
  sdfat.unmount                           ' This line dismounts the card so you can safely remove it.
  

{{   MIT License:
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: 

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. 

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
IN THE SOFTWARE.

}}             
  