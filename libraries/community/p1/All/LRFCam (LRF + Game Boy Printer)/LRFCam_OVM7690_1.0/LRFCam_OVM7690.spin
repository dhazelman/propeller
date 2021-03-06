{{
┌──────────────────────────────────────────────────────────┐
│ Parallax Laser Range Finder + Nintendo Game Boy Printer  │
│                                                          │
│ Author: Joe Grand                                        │                     
│ Copyright (c) 2011 Grand Idea Studio, Inc.               │
│ Web: http://www.grandideastudio.com                      │ 
│                                                          │
│ Distributed under a Creative Commons                     │
│ Attribution 3.0 United States license                    │
│ http://creativecommons.org/licenses/by/3.0/us/           │
└──────────────────────────────────────────────────────────┘

Program Description:

This demonstration project combines a Parallax Laser Ranger Finder module with a Nintendo Game Boy Printer to create
a portable "Polaroid camera." When the pushbutton switch is pressed, the LRF will grab a single frame (8 bits/pixel
greyscale, 160 x 128 resolution). The contents of the frame will be processed and transmitted to the Game Boy Printer
via Nintendo's proprietary synchronous serial interface. The printer will then print the image. 

This main file (LRFCam_OVM7690) is a modified version of the original Parallax Laser Range Finder firmware
(LRF_OVM7690). Only the required camera interface, frame grab, and serial communication functionality is retained
from the original code. All other code has been removed.  

Refer to the LRFCam project on Grand Idea Studio's Laser Range Finder page (http://www.grandideastudio.com/portfolio/
laser-range-finder/) for hardware connection details. For demonstration videos of this project, see:
http://www.youtube.com/watch?v=D2q0gXXFVro and http://www.youtube.com/watch?v=-KndnqWfHv4 

                                                                               
Revisions:
1.0 (November 30, 2011): Initial release
 
}}


CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 6_000_000            ' 96MHz overclock
  _stack   = 50                   ' Ensure we have this minimum stack space available

  ' I/O pin connections to the Propeller
  LaserEnPin    = 15              ' APCD laser diode module (active HIGH) (also defined in OVM7690_fg)
  LedRedPin     = 24              ' Bi-color Red/Green LED, common cathode
  LedGrnPin     = 25

  DbgRxPin      = 31              ' Serial interface via Prop Clip/Plug, IN from user
  DbgTxPin      = 30              '                                      OUT to user
  
  GBPInPin      = 27              ' SPI master interface, IN from Gameboy printer (GBP)
  GBPOutPin     = 26              '                       OUT to printer
  GBPClkPin     = 22              '                       CLOCK to printer
  
  ButtonPin     = 23              ' Pushbutton switch, active LOW  

  ' Serial terminal
  ' Control characters
  NL = 13    ''NL: New Line

  
VAR
  long fbPtr                    ' Pointer to frame buffer (defined in OVM7690_fg)
  byte gbpBuf[g#FB_SIZE]        ' Game Boy Printer graphics array (in bytes, 2 bit/pixel greyscale)

     
OBJ
  g             : "LRF_con"           ' Laser Range Finder global constants  
  cam           : "OVM7690_obj"       ' OVM7690 CMOS camera
  dbg           : "JDCogSerial"       ' Full-duplex serial communication (Carl Jacobs, http://obex.parallax.com/objects/398/)
  gbp           : "GameBoyPrinter"    ' Nintendo Game Boy Printer interface (Joe Grand, http://obex.parallax.com/objects/814/)

  
PUB main
  SystemInit
  dbg.Str(String(NL, NL, "Parallax Laser Range Finder + Nintendo Game Boy Printer"))
        
  ' Start cycle
  repeat
    LEDGreen                                  ' Set status indicator to show that we're ready
    LaserOff                                  ' Ensure laser is off when not in use (we're not using it in this project)

    waitpeq(0, |< ButtonPin, 0)               ' Wait here until the pushbutton switch ("shutter") is pressed
                           
    LEDOrange                                 ' Set status indicator to show that we're busy          
    dbg.Str(String(NL, "Grabbing frame..."))    
    fbPtr := cam.getFrame(cam#GreySingle)     ' Get frame
    dbg.Str(String("Done!"))

    LEDRed
    dbg.Str(String(NL, "Converting frame..."))
    ConvertFrame                              ' Convert image in frame buffer into a 2-bit/pixel, tiled version suitable for transmission to the Game Boy Printer
    dbg.Str(String("Done!"))
            
    dbg.Str(String(NL, "Printing frame..."))
    PrintFrame                                ' Print frame
    dbg.Str(String("Done!", NL))
    
    waitpeq(|< ButtonPin, |< ButtonPin, 0)    ' Wait here until the pushbutton switch is released


PRI ConvertFrame | gbpIdx, band, tile, line, pixel, ca, cb, clv, pixelnum, data
  ' The Game Boy Printer does not store its image data in a contiguous buffer. Instead, it uses
  ' tiles (blocks) of graphics. So, we need to convert the image captured by the LRF's OVM7690 camera
  ' and move the pixels around to meet the GBP requirements.
  '
  ' GBP horizontal resolution of 160 pixels @ 2 bit/pixel greyscale
  ' Each tile = 8 pixels * 8 pixels 
  ' 20 tiles horizontal per band
  ' 2 bands per buffer
  ' => 640 bytes to GBP in a single call
  
  gbpIdx := 0

  ' OVM7690 returns 160x128 resolution image => 16 bands
  repeat band from 0 to 15      
    repeat tile from 0 to 19    
      repeat line from 0 to 7        ' Tile line (8 lines/tile)
        ca := 0
        cb := 0
          
        repeat pixel from 0 to 7       ' Tile pixels (8 pixels/tile)
          ca <<= 1                       ' Shift left
          cb <<= 1

          pixelnum := (pixel + (line * 160) + (tile * 8) + (band * 1280))       ' Determine which pixel we need to grab from the camera image
          data := LONG[fbptr][pixelnum / 4]                                     ' Get the long from the OVM7690 frame buffer that contains our desired pixel
          case (pixelnum // 4)                                                  ' Get the pixel value (OVM7690 returns Y/luma (brightness) as [0 = darkest, 255 = brightest])
            0:
              clv := data.BYTE[3]
            1:
              clv := data.BYTE[2]
            2:
              clv := data.BYTE[1]
            3:
              clv := data.BYTE[0]
          
          ' Downsample the camera's 8 bpp greyscale image to 2 bpp greyscale
          if (clv => 192)     ' 00
            ca += 0
            cb += 0
          elseif (clv => 128) ' 01
            ca += 1
            cb += 0
          elseif (clv => 64)  ' 10
            ca += 0
            cb += 1
          else
            ca += 1           ' 11
            cb += 1
        
        gbpBuf[gbpIdx++] := ca    ' store the 2 bytes that define the tile's current line
        gbpBuf[gbpIdx++] := cb

        
PRI PrintFrame | index, data
  if gbp.printbuffer(@gbpBuf, 8)   ' 8 = sizeof(gbpBuf) / 640 = number of 640-byte chunks of image data that need to be passed to the GBP
    dbg.Str(String(NL, "ERR: gbp.printbuffer"))
    Error

  
PRI SystemInit | CommPtr, ackbit
  ' Set direction of I/O pins
  dira[LedRedPin] := 1          ' Output
  dira[LedGrnPin] := 1          ' Output
  dira[LaserEnPin] := 1         ' Output
  dira[ButtonPin] := 0          ' Input

  ' Set I/O pins to the proper initialization values
  LaserOff                      ' Ensure laser is off during power-up intialization
  LedOrange                     ' Set status indicator to show that we're busy initializing

  CommPtr := dbg.Start(|<DbgRxPin, |<DbgTxPin, 115_200)  ' Start JDCogSerial cog
  if CommPtr == 0
    Error                       ' If we can't start the serial cog, then all we can do is blink
  dbg.rxflush                   ' Flush receive buffer

  if cam.start                  ' Start OVM7690 CMOS camera 
    dbg.Str(String(NL, "ERR: cam.start"))
    Error

  if cam.setRes(g#GRY_X, g#GRY_Y) ' Configure camera for low resolution greyscale
    dbg.Str(String(NL, "ERR: cam.setRes"))
    Error

  gbp.start(GBPInPin, GBPOutPin, GBPClkPin)   ' Start Game Boy Printer object
  
    
PRI Error       ' error mode. something went wrong, so stay here and flash the indicator light 
  repeat                                       
    LedOff
    waitcnt(clkfreq >> 1 + cnt)  ' 1/2 second delay
    LedOrange
    waitcnt(clkfreq >> 1 + cnt)


PRI LaserOn
  outa[LaserEnPin] := 1


PRI LaserOff
  outa[LaserEnPin] := 0

  
PRI LedOff
  outa[LedRedPin] := 0 
  outa[LedGrnPin] := 0

  
PRI LedGreen
  outa[LedRedPin] := 0 
  outa[LedGrnPin] := 1

  
PRI LedRed
  outa[LedRedPin] := 1 
  outa[LedGrnPin] := 0

  
PRI LedOrange
  outa[LedRedPin] := 1 
  outa[LedGrnPin] := 1

  