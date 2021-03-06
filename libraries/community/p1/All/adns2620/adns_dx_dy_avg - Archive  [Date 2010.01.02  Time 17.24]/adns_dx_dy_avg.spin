''**********************************
''*  ADNS2620 optical sensor       *                                   
''*  by Chris Burns                *
''**********************************
''ADNS2620 is the heart os an optical mouse.  It is in reality a 324 pixel camera(0.000324 mega
''pixels).  The circut is simple.  It has an SPI interface.  It is inexpensive.
''
''                adns2620
''               ┌────────────────────┐
''              ┌┤1xtal1          led8├ nc nessecary
''         24 mhz│                    │
''              └┤2xtal2          gnd7├┬───── gnd
''               │                    │ 0.1
''               ┤3sda             5v6├┴───── 5v
''               │                    │2.2 - 10 mF
''               ┤4scl            ref5├─── gnd
''               └────────────────────┘+ -
''
CON
    _clkmode = xtal1 + pll16x                           
    _xinfreq = 5_000_000

obj
        ser: "fullduplexserial"
        adns: "adns"

'*******************************************************************************************************
'*Main Demo                                                                                            *
'*******************************************************************************************************
pub     adns_demo
        Ser.start(31, 30, 0, 19200)
        adns.init_ADNS
        repeat
          ser.str(string( " delta_x: "))
          ser.dec(adns.GET_dx)
          ser.tx(9)
          ser.str(string(" delta_y: "))
          ser.dec(adns.GET_dy)
          ser.str(string(" average pixel: "))
          ser.dec(adns.AVG_pix)
          ser.tx(13)
          waitcnt(cnt + clkfreq/2)
        
        


        
                                              

                                            