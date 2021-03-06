''**************************************
''
''  DS2760 Driver Ver. 00.4
''
''  Timothy D. Swieter, E.I.
''  www.brilldea.com
''
''  Copyright (c) 2008 Timothy D. Swieter, E.I.
''  See end of file for terms of use.
''
''  Updated: November 14, 2008
''
''Description:
''      This program reads the DS2760 and calculates a thermocouple voltage
''      Note that adjustments must be made to the findTCtemp and DAT section
''      in order to match the thermocouple being used
''
''      To use the object, first it must be declared in the top object such as
''        TC    : "Brilldea-DS2760-Ver004.spin"                 'Thermocouple control
''
''      Then in the code you must first strat the object, which starts a one-wire routine
''        TC.start(X)           'X is the one-wire data pin to the "D" on the DS2760
''
''      Then you can get a thermocouple reading
''        readingtemp := TC.TCtemp
''
{{

Schematic DS2760            
────────────────────────────────────────
                +5V       Pins    Names
          ┌────┐         ────    ─────
P? ──────┤D  +├─┘         D      One-wire comms to Propeller - note it is bi-directional and pulled up to
          │    │                  to 5V on the DS2760.  The Propeller seems to work fine for this without a resistor 
          │   -├┐          +      5V DC 
          └────┘│          -      Gnd
                                    
               GND
                                                          
}}
''Reference:
''      Forum post by others: http://forums.parallax.com/forums/default.aspx?f=25&m=223133
''                            http://forums.parallax.com/forums/default.aspx?f=25&m=306188
''      DS2760 Kit by Parallax datasheet & App note
''      DS2760 IC datasheet
''
''To do:
''    
''
''Revision Notes:
'' 0.1 Begin Coding, posted to forum for feedback
'' 0.2 Modified based on feedback and testing
'' 0.3 More modifcations and testing to get sign correct
'' 0.4 Released to the object exchange, not perfect, but works
''
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
  ' DS2760 Commands     
  '***************************************

  _READ_NET     = $33           'Read the net address of the DS2760
  _SKIP_NET     = $CC           'Skip the net address function and just instruct a command
  _READ_DATA    = $69           'Reads data from DS2760, must specify register to read

  _Voltage_MSB  = $0C           'MSB of the voltage register
  _Voltage_LSB  = $0D           'LSB of the voltage register
  _Current_MSB  = $0E           'MSB of the current register
  _Current_LSB  = $0F           'LSB of the current register
  _Temp_MSB     = $18           'MSB of the temperature register
  _Temp_LSB     = $19           'LSB of the temperature register
  

'**************************************
VAR               'Variables to be located here
'***************************************

  'Thermocouple definitions
  long tc_voltage                                       'Measured voltage of the thermocouple
  long cj_temp                                          'Measured temperature of the cold junction (IC)
  long cj_comp                                          'Compensation voltage for the cold junction temperature

  long prevtemp                                         'Previous temperature measured in table


'***************************************
OBJ               'Object declaration to be located here
'***************************************

  OW    : "OneWire.spin"                                'One-wire ASM interface by Cam Thompson


'***************************************
PUB start(_TC_data) : OK        'Pub used to start the cog
'***************************************
'' Start the routines needed to process the thermocouple

  'Start the 1-wire device driver
  OW.start(_TC_data)

  'Check for address 30
  'If it is not there stop the one-wire return and return an error
  if (readAddress == $30)
    return(true) 
  else
    stop
    return(false)       


'***************************************
PUB stop                        'Pub used to start the cog
'***************************************
'' Stop the routines needed to process the thermocouple

  'Stop the 1-wire device driver
  OW.stop

  
'***************************************
PUB TCtemp : _tctemp | cjcomp
'***************************************
''The routine that returns the thermocouple temperature in °C

  'Get the voltage at the "hot" end of the TC - called Seebeck voltage
  readTCvolt

  'Get the temperature at the IC or the "cold" end of the TC - called cold junction temp
  readCJtemp

  'Start the processing for the compensated voltage
  cjcomp :=   findCJcomp(cj_temp)

  'Add the signed numbers together
  cjcomp := cjcomp + tc_voltage

  'Look up the thermocouple temperature in the table
  _tctemp := findTCtemp(cjcomp)
               

'***************************************
PRI readAddress : address
'***************************************
''Read the first eight bits of the device address
''the first eight bits are the devices' family

  OW.reset
  OW.writeByte(_READ_NET)
  address := OW.readbyte

  return(address)
  

'***************************************
PRI readTCvolt
'***************************************
''The voltage across the external thermocouple wires
''two complement format, resolution of 15.625µV
'' ┌───┬────┬────┬───┬───┬───┬───┬───┐ ┌───┬───┬───┬───┬───┬───┬───┬───┐
'' │ S │2^11│2^10│2^9│2^8│2^8│2^6│2^5│ │2^4│2^3│2^2│2^1│2^0│ x │ x │ x │
'' └───┴────┴────┴───┴───┴───┴───┴───┘ └───┴───┴───┴───┴───┴───┴───┴───┘
''  MSB         Add OE          LSB    MSB         Add 0F          LSB
''
''  This routine returns microvolts (µV)

  'Read the two registers of data out of the DS2760    
  OW.reset
  OW.writeByte(_SKIP_NET)
  OW.writeByte(_READ_DATA)
  OW.writeByte(_Current_MSB)
  tc_voltage.byte[1] := OW.readbyte
  tc_voltage.byte[0] := OW.readbyte

  'This appears to work
  'it isn't pretty and I bet there is a way to make it better
  if (tc_voltage & $8000)
    tc_voltage >>= 3                                    'Get rid of the don't cares
    tc_voltage |= $ff_ff_f0_00                          'Make sure the sign stays correct
  else
    tc_voltage >>= 3                                    'Get rid of the don't cares

  tc_voltage := tc_voltage * 125 ~> 3                   'Multiplying by 15.625 and keeping the sign

  return(tc_voltage)


'***************************************
PRI readCJtemp
'***************************************
''The integrated temperature sensor of the IC
''two complement format, resolution of 0.125°C
'' ┌───┬───┬───┬───┬───┬───┬───┬───┐  ┌───┬───┬───┬───┬───┬───┬───┬───┐
'' │ S │2^9│2^8│2^7│2^6│2^5│2^4│2^3│  │2^2│2^1│2^0│ x │ x │ x │ x │ x │
'' └───┴───┴───┴───┴───┴───┴───┴───┘  └───┴───┴───┴───┴───┴───┴───┴───┘
''  MSB         Add 18          LSB    MSB         Add 19          LSB
''
''  This routine returns whole degrees in C

  'Read the two registers of data out of the DS2760  
  OW.reset
  OW.writeByte(_SKIP_NET)
  OW.writeByte(_READ_DATA)
  OW.writeByte(_Temp_MSB)
  cj_temp.byte[1] := OW.readbyte
  cj_temp.byte[0] := OW.readbyte

  'Manipulate the data to be what we want which is
  'no negative temperatures and in whole degrees C
  if (cj_temp & $8000)                                  'Read the sign (S) bit of the upper byte
    cj_temp := 0
  else
    cj_temp := cj_temp >> 8                             '>>5 to get rid of don't cares, >>3 for 0.125 multiply

  return(cj_temp)


'***************************************
PRI findCJcomp(_cjtemp) : cjc
'***************************************
''Look into the data table and return a millivolt value
''
  cjc := Ttable[_cjtemp]


'***************************************
PRI findTCtemp(_cjcomp) : tct | t0, tmin, tmax                                       
'***************************************
''Look into the data table and return the °C for the compensated thermocouple millivolt value
''for the Ttable or Ktable
''
''Tables for T-type and K-type are in the dat section.
''Adjust the code below for XtableMin,XtableMax and Xtable by placing a T or K in the X

  tct := -1

  tmin := TtableMin
  tmax := TtableMax

  'Make sure the _cjcomp is within bounds of the table
  if ((_cjcomp => Ttable[TtableMin]) and (_cjcomp =< Ttable[TtableMax]))

    'Then, to shorten search time look just above or below the previous temperature
    'this assumes that the temperature is slowly changing
    if prevtemp <> 0
      tmin := prevtemp - 15 #> tmin
      tmax := prevtemp + 15 <# tmax

   'Now loop through the table to find the temperature
    repeat t0 from tmin to tmax
      if _cjcomp < Ttable[t0]
        tct := t0 - 1
        prevtemp := tct
        return tct

      
{ Unused routine
'***************************************
PRI readVoltIn : voltin
'***************************************
''The voltage between VIN and VSS over a range of 0 to 4.75V
''two complement format, resolution of 4.88mV
'' ┌───┬───┬───┬───┬───┬───┬───┬───┐  ┌───┬───┬───┬───┬───┬───┬───┬───┐
'' │ S │2^9│2^8│2^7│2^6│2^5│2^4│2^3│  │2^2│2^1│2^0│ x │ x │ x │ x │ x │
'' └───┴───┴───┴───┴───┴───┴───┴───┘  └───┴───┴───┴───┴───┴───┴───┴───┘
''  MSB         Add 0C          LSB    MSB         Add 0D          LSB
''
''  This routine returns millivolts (mV)

  'Read the two registers of data out of the DS2760
  OW.reset
  OW.writeByte(_SKIP_NET)
  OW.writeByte(_READ_DATA)
  OW.writeByte(_Voltage_MSB)
  voltin.byte[1] := OW.readbyte
  voltin.byte[0] := OW.readbyte

  'Manipulate the data to be what we want which is
  'no negative voltages
  'I THINK THIS ROUTINE NEEDS WORK or could be simplified
  if (voltin & $8000)                                   'Read the sign (S) bit of the upper byte
    voltin := 0
  else
    voltin := (voltin >> 5)                             '>>5 to get rid of don't cares
    voltin := (voltin * 4) + (voltin ** 3_779_571_220)  'multiply by 4.88.  0.88 ~= 3779571220/4294967296

} 
'***************************************
DAT
'***************************************
'' T-type (Copper/Constantan) thermocouple data (°C reference)
'' Compiled from example DS2760 code on Parallax.com
''
TtableNum     word 00401        'The number of elements in the table is 401
TtableMin     word 00000
TtableMax     word 00400
'                   +0     +1     +2     +3     +4     +5     +6     +7     +8     +9
Ttable        word 00000, 00039, 00078, 00117, 00156, 00195, 00234, 00273, 00312, 00352  '  0°C         
              word 00391, 00431, 00470, 00510, 00549, 00589, 00629, 00669, 00709, 00749  ' 10°C
              word 00790, 00830, 00870, 00911, 00951, 00992, 01032, 01074, 01114, 01155  ' 20°C
              word 01196, 01238, 01279, 01320, 01362, 01403, 01445, 01486, 01528, 01570  ' 30°C
              word 01612, 01654, 01696, 01738, 01780, 01822, 01865, 01908, 01950, 01993  ' 40°C         
              word 02036, 02079, 02121, 02165, 02208, 02250, 02294, 02338, 02381, 02425  ' 50°C
              word 02468, 02512, 02556, 02600, 02643, 02687, 02732, 02776, 02819, 02863  ' 60°C
              word 02909, 02952, 02998, 03043, 03087, 03132, 03177, 03222, 03266, 03312  ' 70°C         
              word 03358, 03403, 03447, 03494, 03539, 03584, 03631, 03677, 03722, 03768  ' 80°C
              word 03814, 03859, 03907, 03953, 03999, 04046, 04092, 04137, 04185, 04232  ' 90°C         
              word 04278, 04325, 04371, 04419, 04466, 04512, 04561, 04608, 04655, 04701  '100°C         
              word 04750, 04798, 04844, 04892, 04940, 04988, 05036, 05084, 05131, 05179  '110°C
              word 05227, 05277, 05325, 05373, 05421, 05469, 05519, 05567, 05616, 05665  '120°C         
              word 05714, 05762, 05812, 05860, 05910, 05959, 06008, 06057, 06107, 06155  '130°C
              word 06206, 06254, 06304, 06355, 06403, 06453, 06504, 06554, 06604, 06653  '140°C
              word 06703, 06754, 06804, 06855, 06905, 06956, 07006, 07057, 07107, 07158  '150°C
              word 07209, 07259, 07310, 07360, 07411, 07463, 07515, 07565, 07617, 07668  '160°C
              word 07719, 07770, 07823, 07874, 07926, 07977, 08028, 08080, 08133, 08185  '170°C
              word 08237, 08288, 08340, 08393, 08445, 08496, 08550, 08602, 08653, 08707  '180°C
              word 08759, 08811, 08865, 08916, 08970, 09022, 09076, 09128, 09182, 09234  '190°C
              word 09288, 09341, 09394, 09448, 09500, 09554, 09608, 09662, 09714, 09769  '200°C
              word 09822, 09875, 09929, 09984, 10038, 10092, 10146, 10200, 10253, 10307  '210°C
              word 10362, 10416, 10471, 10525, 10580, 10634, 10689, 10743, 10798, 10852  '220°C
              word 10907, 10961, 11016, 11072, 11127, 11182, 11237, 11291, 11346, 11403  '230°C
              word 11458, 11512, 11569, 11624, 11679, 11734, 11791, 11846, 11902, 11958  '240°C
              word 12012, 12069, 12125, 12181, 12237, 12293, 12349, 12405, 12461, 12518  '250°C
              word 12573, 12630, 12686, 12743, 12798, 12855, 12912, 12968, 13025, 13082  '260°C
              word 13139, 13195, 13253, 13310, 13365, 13423, 13480, 13537, 13595, 13652  '270°C
              word 13708, 13766, 13823, 13881, 13938, 13995, 14053, 14109, 14168, 14226  '280°C
              word 14282, 14341, 14399, 14455, 14514, 14572, 14630, 14688, 14746, 14804  '290°C
              word 14862, 14919, 14977, 15035, 15095, 15153, 15211, 15269, 15328, 15386  '300°C
              word 15445, 15503, 15562, 15621, 15679, 15737, 15797, 15855, 15913, 15973  '310°C
              word 16032, 16091, 16149, 16208, 16268, 16327, 16387, 16446, 16504, 16564  '320°C
              word 16623, 16682, 16742, 16801, 16861, 16920, 16980, 17039, 17100, 17158  '330°C
              word 17219, 17278, 17338, 17399, 17458, 17518, 17577, 17638, 17698, 17759  '340°C
              word 17818, 17879, 17939, 17998, 18059, 18120, 18179, 18240, 18301, 18362  '350°C
              word 18422, 18483, 18542, 18603, 18664, 18725, 18786, 18847, 18908, 18969  '360°C
              word 19030, 19091, 19152, 19213, 19274, 19335, 19396, 19457, 19518, 19579  '370°C
              word 19641, 19702, 19763, 19824, 19885, 19946, 20009, 20070, 20132, 20193  '380°C
              word 20255, 20317, 20378, 20440, 20501, 20563, 20625, 20687, 20748, 20810  '390°C
              word 20872                                                                 '400°C

{
'' K-type (Chromel/alumel) thermocouple data (°C reference)
'' Compiled from example DS2760 code on Parallax.com
'' Arranged by TJHJ
''
KtableNum     word 01024        'The number of elements in the table is 1024
KtableMin     word 00000
KtableMax     word 01023
'                     +0,    +1,    +2,    +3,    +4,    +5     +6,    +7,    +8,    +9               
Ktable        Word 00000, 00039, 00079, 00119, 00158, 00198, 00238, 00277, 00317, 00357  '   0°C
              Word 00397, 00437, 00477, 00517, 00557, 00597, 00637, 00677, 00718, 00758  '  10°C
              Word 00798, 00838, 00879, 00919, 00960, 01000, 01040, 01080, 01122, 01163  '  20°C
              Word 01203, 01244, 01284, 01326, 01366, 01407, 01448, 01489, 01530, 01570  '  30°C
              Word 01612, 01653, 01694, 01735, 01776, 01816, 01858, 01899, 01941, 01982  '  40°C
              Word 02023, 02064, 02105, 02146, 02188, 02230, 02270, 02311, 02354, 02395  '  50°C
              Word 02436, 02478, 02519, 02560, 02601, 02644, 02685, 02726, 02767, 02810  '  60°C
              Word 02850, 02892, 02934, 02976, 03016, 03059, 03100, 03141, 03184, 03225  '  70°C
              Word 03266, 03307, 03350, 03391, 03432, 03474, 03516, 03557, 03599, 03640  '  80°C
              Word 03681, 03722, 03765, 03806, 03847, 03888, 03931, 03972, 04012, 04054  '  90°C
              Word 04096, 04137, 04179, 04219, 04261, 04303, 04344, 04384, 04426, 04468  ' 100°C
              Word 04509, 04549, 04591, 04633, 04674, 04714, 04756, 04796, 04838, 04878  ' 110°C
              Word 04919, 04961, 05001, 05043, 05083, 05123, 05165, 05206, 05246, 05288  ' 120°C
              Word 05328, 05368, 05410, 05450, 05490, 05532, 05572, 05613, 05652, 05693  ' 130°C
              Word 05735, 05775, 05815, 05865, 05895, 05937, 05977, 06017, 06057, 06097  ' 140°C
              Word 06137, 06179, 06219, 06259, 06299, 06339, 06379, 06419, 06459, 06500  ' 150°C
              Word 06540, 06580, 06620, 06660, 06700, 06740, 06780, 06820, 06860, 06900  ' 160°C
              Word 06940, 06980, 07020, 07059, 07099, 07139, 07179, 07219, 07259, 07299  ' 170°C
              Word 07339, 07379, 07420, 07459, 07500, 07540, 07578, 07618, 07658, 07698  ' 180°C
              Word 07738, 07778, 07819, 07859, 07899, 07939, 07979, 08019, 08058, 08099  ' 190°C
              Word 08137, 08178, 08217, 08257, 08298, 08337, 08378, 08417, 08458, 08499  ' 200°C
              Word 08538, 08579, 08618, 08659, 08698, 08739, 08778, 08819, 08859, 08900  ' 210°C
              Word 08939, 08980, 09019, 09060, 09101, 09141, 09180, 09221, 09262, 09301  ' 220°C
              Word 09343, 09382, 09423, 09464, 09503, 09544, 09585, 09625, 09666, 09707  ' 230°C
              Word 09746, 09788, 09827, 09868, 09909, 09949, 09990, 10031, 10071, 10112  ' 240°C
              Word 10153, 10194, 10234, 10275, 10316, 10356, 10397, 10439, 10480, 10519  ' 250°C
              Word 10560, 10602, 10643, 10683, 10724, 10766, 10807, 10848, 10888, 10929  ' 260°C
              Word 10971, 11012, 11053, 11093, 11134, 11176, 11217, 11259, 11300, 11340  ' 270°C
              Word 11381, 11423, 11464, 11506, 11547, 11587, 11630, 11670, 11711, 11753  ' 280°C
              Word 11794, 11836, 11877, 11919, 11960, 12001, 12043, 12084, 12126, 12167  ' 290°C
              Word 12208, 12250, 12291, 12333, 12374, 12416, 12457, 12499, 12539, 12582  ' 300°C
              Word 12624, 12664, 12707, 12747, 12789, 12830, 12872, 12914, 12955, 12997  ' 310°C
              Word 13039, 13060, 13122, 13164, 13205, 13247, 13289, 13330, 13372, 13414  ' 320°C
              Word 13457, 13497, 13539, 13582, 13624, 13664, 13707, 13749, 13791, 13833  ' 330°C
              Word 13874, 13916, 13958, 14000, 14041, 14083, 14125, 14166, 14208, 14250  ' 340°C
              Word 14292, 14335, 14377, 14419, 14461, 14503, 14545, 14586, 14628, 14670  ' 350°C
              Word 14712, 14755, 14797, 14839, 14881, 14923, 14964, 15006, 15048, 15090  ' 360°C
              Word 15132, 15175, 15217, 15259, 15301, 15343, 15384, 15426, 15468, 15510  ' 370°C
              Word 15554, 15596, 15637, 15679, 15721, 15763, 15805, 15849, 15891, 15932  ' 380°C
              Word 15974, 16016, 16059, 16102, 16143, 16185, 16228, 16269, 16312, 16355  ' 390°C
              Word 16396, 16439, 16481, 16524, 16565, 16608, 16650, 16693, 16734, 16777  ' 400°C
              Word 16820, 16861, 16903, 16946, 16989, 17030, 17074, 17115, 17158, 17201  ' 410°C
              Word 17242, 17285, 17327, 17370, 17413, 17454, 17496, 17539, 17582, 17623  ' 420°C
              Word 17667, 17708, 17751, 17794, 17836, 17879, 17920, 17963, 18006, 18048  ' 430°C
              Word 18091, 18134, 18176, 18217, 18260, 18303, 18346, 18388, 18431, 18472  ' 440°C
              Word 18515, 18557, 18600, 18643, 18686, 18728, 18771, 18812, 18856, 18897  ' 450°C
              Word 18940, 18983, 19025, 19068, 19111, 19153, 19196, 19239, 19280, 19324  ' 460°C
              Word 19365, 19408, 19451, 19493, 19536, 19579, 19621, 19664, 19707, 19750  ' 470°C
              Word 19792, 19835, 19876, 19920, 19961, 20004, 20047, 20089, 20132, 20175  ' 480°C
              Word 20218, 20260, 20303, 20346, 20388, 20431, 20474, 20515, 20559, 20602  ' 490°C
              Word 20643, 20687, 20730, 20771, 20815, 20856, 20899, 20943, 20984, 21027  ' 500°C
              Word 21071, 21112, 21155, 21199, 21240, 21283, 21326, 21368, 21411, 21454  ' 510°C
              Word 21497, 21540, 21582, 21625, 21668, 21710, 21753, 21795, 21838, 21881  ' 520°C
              Word 21923, 21966, 22009, 22051, 22094, 22137, 22178, 22222, 22265, 22306  ' 530°C
              Word 22350, 22393, 22434, 22478, 22521, 22562, 22606, 22649, 22690, 22734  ' 540°C
              Word 22775, 22818, 22861, 22903, 22946, 22989, 23032, 23074, 23117, 23160  ' 550°C
              Word 23202, 23245, 23288, 23330, 23373, 23416, 23457, 23501, 23544, 23585  ' 560°C
              Word 23629, 23670, 23713, 23757, 23798, 23841, 23884, 23926, 23969, 24012  ' 570°C
              Word 24054, 24097, 24140, 24181, 24225, 24266, 24309, 24353, 24394, 24437  ' 580°C
              Word 24480, 24523, 24565, 24608, 24650, 24693, 24735, 24777, 24820, 24863  ' 590°C
              Word 24905, 24948, 24990, 25033, 25075, 25118, 25160, 25203, 25245, 25288  ' 600°C
              Word 25329, 25373, 25414, 25457, 25500, 25542, 25585, 25626, 25670, 25711  ' 610°C
              Word 25755, 25797, 25840, 25882, 25924, 25967, 26009, 26052, 26094, 26136  ' 620°C
              Word 26178, 26221, 26263, 26306, 26347, 26390, 26432, 26475, 26516, 26559  ' 630°C
              Word 26602, 26643, 26687, 26728, 26771, 26814, 26856, 26897, 26940, 26983  ' 640°C
              Word 27024, 27067, 27109, 27152, 27193, 27236, 27277, 27320, 27362, 27405  ' 650°C
              Word 27447, 27489, 27531, 27574, 27616, 27658, 27700, 27742, 27784, 27826  ' 660°C
              Word 27868, 27911, 27952, 27995, 28036, 28079, 28120, 28163, 28204, 28246  ' 670°C
              Word 28289, 28332, 28373, 28416, 28416, 28457, 28500, 28583, 28626, 28667  ' 680°C
              Word 28710, 28752, 28794, 28835, 28877, 28919, 28961, 29003, 29045, 29087  ' 690°C
              Word 29129, 29170, 29213, 29254, 29297, 29338, 29379, 29422, 29463, 29506  ' 700°C
              Word 29548, 29589, 29631, 29673, 29715, 29757, 29798, 29840, 29882, 29923  ' 710°C
              Word 29964, 30007, 30048, 30089, 30132, 30173, 30214, 30257, 30298, 30341  ' 720°C
              Word 30382, 30423, 30466, 30507, 30548, 30589, 30632, 30673, 30714, 30757  ' 730°C
              Word 30797, 30839, 30881, 30922, 30963, 31006, 31047, 31088, 31129, 31172  ' 740°C
              Word 31213, 31254, 31295, 31338, 31379, 31420, 31461, 31504, 31545, 31585  ' 750°C
              Word 31628, 31669, 31710, 31751, 31792, 31833, 31876, 31917, 31957, 32000  ' 760°C
              Word 32040, 32082, 32124, 32164, 32206, 32246, 32289, 32329, 32371, 32411  ' 770°C
              Word 32453, 32495, 32536, 32577, 32618, 32659, 32700, 32742, 32783, 32824  ' 780°C
              Word 32865, 32905, 32947, 32987, 33029, 33070, 33110, 33152, 33192, 33234  ' 790°C
              Word 33274, 33316, 33356, 33398, 33439, 33479, 33521, 33561, 33603, 33643  ' 800°C
              Word 33685, 33725, 33767, 33807, 33847, 33889, 33929, 33970, 34012, 34052  ' 810°C
              Word 34093, 34134, 34174, 34216, 34256, 34296, 34338, 34378, 34420, 34460  ' 820°C
              Word 34500, 34542, 34582, 34622, 34664, 34704, 34744, 34786, 34826, 34866  ' 830°C
              Word 34908, 34948, 34999, 35029, 35070, 35109, 35151, 35192, 35231, 35273  ' 840°C
              Word 35313, 35353, 35393, 35435, 35475, 35515, 35555, 35595, 35637, 35676  ' 850°C
              Word 35718, 35758, 35798, 35839, 35879, 35920, 35960, 36000, 36041, 36081  ' 860°C
              Word 36121, 36162, 36202, 36242, 36282, 36323, 36363, 36403, 36443, 36484  ' 870°C
              Word 36524, 36564, 36603, 36643, 36685, 36725, 36765, 36804, 36844, 36886  ' 880°C
              Word 36924, 36965, 37006, 37045, 37085, 37125, 37165, 37206, 37246, 37286  ' 890°C
              Word 37326, 37366, 37406, 37446, 37486, 37526, 37566, 37606, 37646, 37686  ' 900°C
              Word 37725, 37765, 37805, 37845, 37885, 37925, 37965, 38005, 38044, 38084  ' 910°C
              Word 38124, 38164, 38204, 38243, 38283, 38323, 38363, 38402, 38442, 38482  ' 920°C
              Word 38521, 38561, 38600, 38640, 38679, 38719, 38759, 38798, 38838, 38878  ' 930°C
              Word 38917, 38957, 38996, 39036, 39076, 39115, 39164, 39195, 39234, 39274  ' 940°C
              Word 39314, 39353, 39393, 39432, 39470, 39511, 39549, 39590, 39628, 39668  ' 950°C'
              Word 39707, 39746, 39786, 39826, 39865, 39905, 39944, 39984, 40023, 40061  ' 960°C
              Word 40100, 40140, 40179, 40219, 40259, 40298, 40337, 40375, 40414, 40454  ' 970°C
              Word 40493, 40533, 40572, 40610, 40651, 40689, 40728, 40765, 40807, 40846  ' 980°C
              Word 40885, 40924, 40963, 41002, 41042, 41081, 41119, 41158, 41198, 41237  ' 990°C
              Word 41276, 41315, 41354, 41393, 41431, 41470, 41509, 41548, 41587, 41626  '1000°C
              Word 41665, 41704, 41743, 41781, 41820, 41859, 41898, 41937, 41976, 42014  '1100°C
              Word 42053, 42092, 42131, 42169                                            '1020°C                    
 }

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