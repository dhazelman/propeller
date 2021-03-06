{{
┌─────────────────────────────┬──────────────────┬───────────────────────┐
│ HM55B_Dual_Driver.spin v1.0 │ Author:I.Kövesdi │ Release:20 April 2009 │
├─────────────────────────────┴──────────────────┴───────────────────────┤
│                    Copyright (c) 2009 CompElit Inc.                    │               
│                   See end of file for terms of use.                    │               
├────────────────────────────────────────────────────────────────────────┤
│  This is a 3-wire SPI driver object for the HM55B 2-axis magnetic field│
│ sensor module. It can drive two devices that may form a 3-axis unit.   │
│ The driver can be used for a single sensor setup, too. It needs one    │
│ additional COG for its PASM code for both sensors.                     │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│ Background and Detail:                                                 │
│  The reset and readout of the sensor(s) are fully controlled by the    │
│ host application. Continuous measurements or single shot readouts can  │
│ be commanded. With the second method the average current consumption of│
│ the sensor(s) can be decreased considerably to help low-power hand held│
│ applications. The only drawback of a single shot readout, that it      │
│ retains host SPIN code execution for about 30 msec.                    │
│                                                                        │ 
├────────────────────────────────────────────────────────────────────────┤
│ Note:                                                                  │
│ -Two HM55B can be mounted in a way that their axes form a rectangular  │
│ X, Y, Z coordinate system. Each measurement describes a point in this  │
│ local sensor coordinate system. In an ideal situation, where the sensor│
│ is rotated to various orientation in a field with no hard or soft iron │
│ effects, all measured points would lie on a sphere. However, due to    │
│ hard iron effects (nearby iron permanently magnetized and rotates with │
│ the sensor assembly) all points are translated to some unknown         │
│ direction. And due to soft iron effects (induced magnetic field from   │
│ some components of the sensor assembly), all points are transformed to │
│ some unknown ellipsoid. Misalignment of the magnetometer's axes will   │
│ cause something like a shear. This transforms into an other ellipsoid. │
│ If the resulting transformation is known, any measured point can be    │
│ transformed inversely back to the ideal sphere and computation of the  │
│ heading can be proceeded from there. The only problem is to find the   │
│ best fit transformation from a cloud of measured points during         │
│ calibration.                                                           │
│ -An algorithm that can automatically and continuously perform this     │
│ general error compensation for any 3-axis low cost MEMS sensor (magneto│
│ or accelero) in real-time on a computer platform with the quite limited│
│ resources of an embedded application is most wanted. This will be      │
│ accomplished with the Propeller/FPU combination. Preliminary results in│
│ this project can be found in the thread about H48C calibration, where  │
│ more than tenfold accuracy improvement was achieved even with a much   │
│ simpler version of the here proposed algorithm, and in this OBEX entry │ 
│ that introduces a dual HM55B 3-wire SPI driver.                        │
│                                                                        │  
└────────────────────────────────────────────────────────────────────────┘


Orientation of axes of HM55B 2-axis magnetic sensor module

                             ┌─────SMD voltage regulator on module
                        X            
                       / .________    
           Pin 1 ──  /  /   #   /
                     /  /       /       
                    /  /       /   
                   /     
                  ──────────────> Y



'Schematics for 3-wire SPI interface of the HM55B module


                  ┌────────┬┬────────┐
                  │            │
                  │       └┘└┘       │          
            ┌────│1   •┌──────┐    6│── +5V                                     
            │ 1K  │     │ X    │     │                   
       DIO ┻──│2    │     │    5│── /EN                 
                  │     │ └─Y │     │                                       
          VSS ──│3    └──────┘    4│── CLK                               
                  │      HM55B       │                                          
                  │                  │ 
                  └──────────────────┘


}}


CON

#1, _INIT, _RESET_1, _READ_1, _START_1                        '1-4
#5, _RESET_2, _READ_2, _START_12                              '5-7
'These are the enumerated PASM command No.s (_INIT=1, _RESET_1=2, etc..)
'They should be in harmony with the Cmd_Table of the PASM program in the
'DAT section of this object


VAR

LONG cog, command, par1, par2, par3, par4, par5, par6, par7

LONG mode


DAT '------------------------Start of SPIN code---------------------------
  
                                     
PUB StartCOG(mod, en1, clk1, dio1, en2, clk2, dio2, cogID_) : oKay 
'-------------------------------------------------------------------------
'------------------------------┌──────────┐-------------------------------
'------------------------------│ StartCOG │-------------------------------
'------------------------------└──────────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: -Starts a COG to run HM55B SPI Dual Driver's PASM code
''             -Passes Pin assignments to PASM code in COG memory
''             -Returns FALSE if no COG available or the HM55B(s) did not
''             respond properly
'' Parameters: -Single/Dual mode (1/2)
''             -Prop pin to /EN pin of 1st HM55B   
''             -Prop pin to CLK pin of 1st HM55B 
''             -Prop pin to DIO pin of 1st HM55B
''             -Prop pin to /EN pin of 2nd HM55B
''             -Prop pin to CLK pin of 2nd HM55B   
''             -Prop pin to DIO pin of 2nd HM55B 
''             -HUB/Address of cog ID
''    Results: -oKay (TRUE/FALSE)
''             -COG ID 
''+Reads/Uses: /_INIT
''    +Writes: cog, command, par1, par2, par3, par4, par5, par6
''      Calls: -stopCOG
''             -COG/#Init
''       Note: A simple hardware check of the sensors is performed which
''             consists of a reset then a single shot data reading
'-------------------------------------------------------------------------  
StopCOG                                'Stop previous copy of this driver,
                                       'if any

command := 0
cog := COGNEW(@HM55B, @command)        'Try to start a COG with a running
                                       'PASM program that waits for a
                                       'nonzero "command"
LONG[CogID_] :=  cog++                                       

IF cog  '-------------------->Then a COG has been succcessfully started
  mode := mod
  par1 := mode
  oKay := TRUE
  CASE mode
    1:
      par2 := en1                          
      par3 := clk1                         
      par4 := dio1                
    2:
      par2 := en1                          
      par3 := clk1                         
      par4 := dio1                
      par5 := en2
      par6 := clk2
      par7 := dio2    
    OTHER:
      oKay := FALSE                  'Bad mode parameter
    
  IF oKay
    command := _INIT                 'CALL _INIT procedure in COG to  
    REPEAT WHILE command             'setup SPI lines and check sensor(s)  

    oKay := par1
                                     'Read error condition
ELSE
  oKay := FALSE      

RETURN oKay  
'-------------------------------------------------------------------------


PUB StopCOG                                          
'-------------------------------------------------------------------------
'-------------------------------┌─────────┐-------------------------------
'-------------------------------│ StopCOG │-------------------------------
'-------------------------------└─────────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Stops HM55B_Dual_Driver PASM code by freeing a COG in which 
''             it is running
'' Parameters: None
''    Results: None 
''+Reads/Uses: cog
''    +Writes: cog, command
''      Calls: None
'-------------------------------------------------------------------------
command~                               'Clear "command" register
                                       'Here you can initiate a "shut off"
                                       'PASM routine if necessary 
IF cog
  COGSTOP(cog~ - 1)                    'Stop (cog-1) then clear cog      
'-------------------------------------------------------------------------


PUB Reset_1                                          
'-------------------------------------------------------------------------
'-------------------------------┌─────────┐-------------------------------
'-------------------------------│ Reset_1 │-------------------------------
'-------------------------------└─────────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Resets 1st HM55B sensor 
'' Parameters: None
''    Results: None 
''+Reads/Uses: /_RESET_1
''    +Writes: command
''      Calls: COG/#Reset1 
'-------------------------------------------------------------------------
command := _RESET_1
REPEAT WHILE command         'Wait for _RESET_1 command to be processed
'-------------------------------------------------------------------------


PUB Read_1(bx_, by_)                                
'-------------------------------------------------------------------------
'--------------------------------┌────────┐-------------------------------
'--------------------------------│ Read_1 │-------------------------------
'--------------------------------└────────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Reads a single shot data from the 1st HM55B sensor     
'' Parameters: HUB addresses of field components
''    Results: Components of the magnetic field in sensor axis frame
''+Reads/Uses: /_READ_1
''    +Writes: command, par1, par2
''      Calls: COG/#Read1
''      Note: -Data roughly gives field components in microT. Readings in
''            the range of max +-50 correspond to the Earth's magnetic
''            field. The size and direction of the field depends on
''            location. Max field size at 45 deg latitude is about 47 uT
''            in Europe with a max 25 uT horizontal component. The normal
''            measurement range of sensor is -+180 uT.
''            -Do not put the sensor close to a strong magnet, unless you
''            want to destroy it.
''            -SPIN code has to wait here (~30 msec) to read the data.
''            -This single shot readout promotes low power consumption
''            applications 
'-------------------------------------------------------------------------
command := _READ_1
REPEAT WHILE command         'Wait for _READ_1 command to be processed
                             '~30 msec

LONG[bx_] := par1            'Copy par1(=Bx) into the LONG at HUB/[bx_]
LONG[by_] := par2            'Copy par2(=By) into the LONG at HUB/[by_]
'-------------------------------------------------------------------------


PUB Start_1                                
'-------------------------------------------------------------------------
'--------------------------------┌─────────┐------------------------------
'--------------------------------│ Start_1 │------------------------------
'--------------------------------└─────────┘------------------------------
'-------------------------------------------------------------------------
''     Action: Starts continuous readout from 1st HM55B sensor     
'' Parameters: None
''    Results: None
''+Reads/Uses: /_START_1
''    +Writes: command
''      Calls: COG/#Start1
''       Note: -To access the data use the Get_1 procedure.
''             -Sensor is working continuously, so average current need is
''             higher than in the single shot mode.
''             -Any command sent to COG (e.g. with Reset_1) will stop this
''             continuous readout
'-------------------------------------------------------------------------
command := _START_1
REPEAT WHILE command         'Wait for _START_1 command to be processed
'-------------------------------------------------------------------------


PUB Get_1(bx_, by_)                                
'-------------------------------------------------------------------------
'---------------------------------┌───────┐-------------------------------
'---------------------------------│ Get_1 │-------------------------------
'---------------------------------└───────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Reads magnetization data that is updated continuously in
''             the background by the 1st HM55B sensor
'' Parameters: HUB addresses of field components
''    Results: Components of the magnetic field in sensor axis frame
''+Reads/Uses: par1, par2
''    +Writes: None
''      Calls: None
''       Note: -It reads data immediately and does not wait.
''             -The data is refreshed continuously by the PASM program
''             running in the COG of the driver
'-------------------------------------------------------------------------
LONG[bx_] := par1            'Copy par1(=Bx) into the LONG at HUB/[bx_]
LONG[by_] := par2            'Copy par2(=By) into the LONG at HUB/[by_]
'-------------------------------------------------------------------------


PUB Reset_2                                          
'-------------------------------------------------------------------------
'-------------------------------┌─────────┐-------------------------------
'-------------------------------│ Reset_2 │-------------------------------
'-------------------------------└─────────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Resets 2nd HM55B sensor 
'' Parameters: None
''    Results: None 
''+Reads/Uses: /_RESET_2
''    +Writes: command
''      Calls: COG/#Reset2 
'-------------------------------------------------------------------------
command := _RESET_2
REPEAT WHILE command         'Wait for _RESET_2 command to be processed
'-------------------------------------------------------------------------


PUB Read_2(bx_, by_)                                
'-------------------------------------------------------------------------
'--------------------------------┌────────┐-------------------------------
'--------------------------------│ Read_2 │-------------------------------
'--------------------------------└────────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Reads a single shot data from the 2nd HM55B sensor     
'' Parameters: HUB addresses of field components  
''    Results: Components of the magnetic field in sensor axis frame
''+Reads/Uses: /_READ_2
''    +Writes: command, par3, par4
''      Calls: COG/#Read2
''      Note: -Data roughly gives field components in microT. Readings in
''            the range of max +-50 correspond to the Earth's magnetic
''            field. The size and direction of the field depends on
''            location. Max field size at 45 deg latitude is about 47 uT
''            in Europe with a max 25 uT horizontal component. The normal
''            measurement range of sensor is -+180 uT.
''            -Do not put the sensor close to a strong magnet, unless you
''            want to destroy it.
''            -SPIN code has to wait here (~30 msec) to read the data.
''            -This single shot readout promotes low power consumption
''            applications 
'-------------------------------------------------------------------------
command := _READ_2
REPEAT WHILE command         'Wait for _READ_2 command to be processed
                             '~30 msec

LONG[bx_] := par3            'Copy par3(=B2x) into the LONG at HUB/[bx_]
LONG[by_] := par4            'Copy par4(=B2y) into the LONG at HUB/[by_]
'-------------------------------------------------------------------------


PUB Start_12                                
'-------------------------------------------------------------------------
'-------------------------------┌──────────┐------------------------------
'-------------------------------│ Start_12 │------------------------------
'-------------------------------└──────────┘------------------------------
'-------------------------------------------------------------------------
''     Action: Starts continuous readout from both HM55B sensors     
'' Parameters: None
''    Results: None
''+Reads/Uses: /_START_12
''    +Writes: command
''      Calls: COG/#Start12
''       Note: -To access the data use the Get_12 procedure.
''             -Sensors are working continuously, so average current need
''             is higher than in the single shot mode.
''             -Any command sent to COG (e.g. with Reset_1) will stop this
''             continuous readout
'-------------------------------------------------------------------------
command := _START_12
REPEAT WHILE command         'Wait for _START_12 command to be processed
'-------------------------------------------------------------------------


PUB Get_12(bx1_, by1_, bx2_, by2_)                                
'-------------------------------------------------------------------------
'--------------------------------┌────────┐-------------------------------
'--------------------------------│ Get_12 │-------------------------------
'--------------------------------└────────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Reads magnetization data that is updated in the background
''             continuously by both HM55B sensors     
'' Parameters: HUB addresses of field components at both sensors
''    Results: Components of the magnetic field in sensor axis frame
''+Reads/Uses: par1, par2, par3, par4
''    +Writes: None
''      Calls: None
''       Note: -It reads data immediately and does not wait.
''             -Before this procedure you have to call the Start_12 one.
''             Following that call the data is refreshed continuously by
''             the PASM program running in the COG of the driver
'-------------------------------------------------------------------------
LONG[bx1_] := par1           'Copy par1(=B1x) into the LONG at HUB/[bx1_]
LONG[by1_] := par2           'Copy par2(=B1y) into the LONG at HUB/[by1_]
LONG[bx2_] := par3           'Copy par3(=B2x) into the LONG at HUB/[bx2_]
LONG[by2_] := par4           'Copy par4(=B2y) into the LONG at HUB/[by2_]
'-------------------------------------------------------------------------


DAT '-------------------------Start of PASM code--------------------------

'-------------------------------------------------------------------------
'-------------DAT section for PASM program and COG registers--------------
'-------------------------------------------------------------------------
HM55B    ORG             0             'Start of PASM program

Get_Command
RDLONG   r1,             PAR WZ        'Read "command" register from HUB
IF_Z     JMP             #Get_Command  'Wait for a nonzero "command"

Dispatcher
SHL      r1,             #1            'Multiply command No. with 2
ADD      r1,             #Cmd_Table-2  'Add it to the value of
                                       '#Cmd_Table-2
'Note that command numbers are 1, 2, 3, etc..., but the entry routines
'are the 0th, 2rd, 4th, etc... entries in the Cmd_Table (counted in 32
'bit registers)

JMP      r1                            'Jump to selected command 
                                     
Cmd_Table                              'Command dispatch table
CALL     #Init                         'Init    (command No.1)
JMP      #Done
CALL     #Reset1                       'Reset1  (command No.2)
JMP      #Done
CALL     #Read1                        'Read1   (command No.3)
JMP      #Done                                               
JMP      #Start1                       'Start1  (command No.4)
JMP      #Done
CALL     #Reset2                       'Reset2  (command No.5)
JMP      #Done
CALL     #Read2                        'Read2   (command No.6)
JMP      #Done
JMP      #Start12                      'Start12 (command No.7)                

'Command has been processed. Now send "Command Processed" status to the
'interpreted HUB memory SPIN code of this driver, than jump back to the
'entry point of this PASM code. There it will fetch the next command,
'if any.

Done
WRLONG   _Zero,          PAR       'Write 0 to HUB/command to signal a
                                   '"Command Processed" status for the
                                   'SPIN code                                       
JMP      #Get_Command              'Get next command
'-------------------------------------------------------------------------


DAT 'Init
'-------------------------------------------------------------------------
'-----------------------------------┌──────┐------------------------------
'-----------------------------------│ Init │------------------------------
'-----------------------------------└──────┘------------------------------
'-------------------------------------------------------------------------
'     Action: -Stores HUB address  of parameters for par1..4
'             -Initializes Pin Masks registers
'             -Initializes /EN, CLK and DIO lines
'             -Resets sensor(s)
'             -Checks for valid readout(s) 
' Parameters: -Mode in par1
'             -/EN and SPI lines in par2..7
'    Results: -COG/cmode
'             -COG/par1..4_Addr
'             -COG//EN, CLK. DIO pin masks
'             -Error condition back to HUB/par1 
'+Reads/Uses: /PAR          
'    +Writes: r1, r2
'      Calls: -#Reset1, #Reset2
'             -#Read1, #Read2  
'-------------------------------------------------------------------------
Init

MOV      r1,             PAR   'Get address of "command" in HUB memory
ADD      r1,             #4    'r1 now contains the HUB memory address
                               'of "par1" variable
                               '("par1" is next to "command")
                               
MOV      par1_Addr_,     r1    'Store this address in COG memory
RDLONG   cmode,          r1    'Load Mode from HUB memory into cmode

ADD      r1,             #4    'r1 now points to "par2" in HUB memory  
MOV      par2_Addr_,     r1    'Store this address in COG memory
RDLONG   r2,             r1    'Load /EN1 pin No. from HUB memory into r2 
MOV      en1_Pin_Mask,   #1    'Setup /EN1 pin mask
SHL      en1_Pin_Mask,   r2

ADD      r1,             #4    'r1 now points to "par3" in HUB memory
MOV      par3_Addr_,     r1    'Store this address in COG memory
RDLONG   r2,             r1    'Load CLK1 pin No. from HUB memory into r2
MOV      clk1_Pin_Mask,  #1    'Setup CLK1 pin mask 
SHL      clk1_Pin_Mask,  r2

ADD      r1,             #4    'r1 now points to "par4" in HUB memory
MOV      par4_Addr_,     r1    'Store this address in COG memory
RDLONG   r2,             r1    'Load DIO1 pin No. from HUB memory into r2
MOV      dio1_Pin_Mask,  #1    'Setup DIO1 pin mask
SHL      dio1_Pin_Mask,  r2

'Prepare Prop hardware on HM55B_1 lines
OR       OUTA,           en1_Pin_Mask  'Pre-Set /EN1 pin HIGH
OR       DIRA,           en1_Pin_Mask  'Set /EN1 as OUTPUT(deselect HM55B)
ANDN     OUTA,           clk1_Pin_Mask 'Pre-Set CLK1 pin LOW
OR       DIRA,           clk1_Pin_Mask 'Set CLK1 pin as OUTPUT
ANDN     DIRA,           dio1_Pin_Mask 'Set DIO1 pin as an INPUT

'Check Single / Dual mode
SUB      cmode,          #1 WZ, NR 
IF_Z     JMP             #:SingleMode  'Jump to Single mode branch

'Else read in Dual mode additional parameters
ADD      r1,             #4    'r1 now points to "par5" in HUB memory
RDLONG   r2,             r1    'Load /EN1 pin No. from HUB memory into r2 
MOV      en2_Pin_Mask,   #1    'Setup /EN1 pin mask
SHL      en2_Pin_Mask,   r2

ADD      r1,             #4    'r1 now points to "par6" in HUB memory
RDLONG   r2,             r1    'Load CLK1 pin No. from HUB memory into r2
MOV      clk2_Pin_Mask,  #1    'Setup CLK1 pin mask 
SHL      clk2_Pin_Mask,  r2

ADD      r1,             #4    'r1 now points to "par7" in HUB memory
RDLONG   r2,             r1    'Load DIO1 pin No. from HUB memory into r2
MOV      dio2_Pin_Mask,  #1    'Setup DIO1 pin mask
SHL      dio2_Pin_Mask,  r2

'Prepare Prop hardware on HM55B_2 lines
OR       OUTA,           en2_Pin_Mask  'Pre-Set /EN2 pin HIGH
OR       DIRA,           en2_Pin_Mask  'Set /EN2 as OUTPUT(deselect HM55B)
ANDN     OUTA,           clk2_Pin_Mask 'Pre-Set CLK2 pin LOW
OR       DIRA,           clk2_Pin_Mask 'Set CLK2 pin as OUTPUT
ANDN     DIRA,           dio2_Pin_Mask 'Set DIO2 pin as an INPUT

'Now check both sensors
CALL     #Reset1                       'Reset 1st HM55B sensor
CALL     #Read1                        'Read 1st HM55B sensor
CALL     #Reset2                       'Reset 2nd HM55B sensor
CALL     #Read2                        'Read 2nd HM55B sensor

MOV      r1,             bx1           'Check for non-zero reading
ABS      r1,             r1            'from 1st sensor
ADDABS   r1,             by1
TEST     r1,             r1 WZ
IF_NZ    JMP             #:Data1st_OK

MOV      r2,             #0            'Prepare FALSE(0) back to host
JMP      #:Send

:Data1st_OK
MOV      r1,             bx2           'Check for non-zero reading
ABS      r1,             r1            'from 2nd sensor
ADDABS   r1,             by2
TEST     r1,             r1 WZ
IF_NZ    JMP             #:Data_OK

MOV      r2,             #0            'Prepare FALSE(0) back to host
JMP      #:Send

:SingleMode
'Check 1st sensor
CALL     #Reset1                       'Reset 1st HM55B sensor
CALL     #Read1                        'Read 1st HM55B sensor  

MOV      r1,             bx1           'Check for non-zero reading
ABS      r1,             r1            'from 1st sensor
ADDABS   r1,             by1
TEST     r1,             r1 WZ
IF_NZ    JMP             #:Data_OK

MOV      r2,             #0            'Prepare FALSE(0) back to host
JMP      #:Send

:Data_OK
NEG      r2,             #1            'Prepare TRUE(-1) back to host

:Send       
WRLONG   r2,             par1_Addr_    'Write test result into HUB/par1

Init_Ret
RET          
'-------------------------------------------------------------------------


DAT 'Reset1
'-------------------------------------------------------------------------
'---------------------------------┌────────┐------------------------------
'---------------------------------│ Reset1 │------------------------------
'---------------------------------└────────┘------------------------------
'-------------------------------------------------------------------------
'     Action: Resets 1st HM55B sensor
' Parameters: None
'    Results: None
'+Reads/Uses: /en1_Pin_Mask, _Cmd_Reset          
'    +Writes: r1
'      Calls: #Shiftout1
'-------------------------------------------------------------------------
Reset1

ANDN     OUTA,           en1_Pin_Mask  'Set /EN1 Pin LOW  (enable device)  

MOV      r1,             _Cmd_Reset
CALL     #ShiftOut1
              
OR       OUTA,           en1_Pin_Mask  'Set /EN1 Pin HIGH (disable device) 

Reset1_Ret
RET
'-------------------------------------------------------------------------


DAT 'Read1
'-------------------------------------------------------------------------
'---------------------------------┌───────┐-------------------------------
'---------------------------------│ Read1 │-------------------------------
'---------------------------------└───────┘-------------------------------
'-------------------------------------------------------------------------
'     Action: Reads single shot magnetization data from the 1st HM55B
' Parameters: None
'    Results: Components of B field in sensor's x, y directions bx1, by1
'+Reads/Uses: -/_Cmd_Measure, _Cmd_Report
'             -/en1_Pin_Mask
'             -/_11bitSign_Mask, _32bitExtend_Mask           
'    +Writes: r1, r2
'      Calls: #ShiftOut1
'             #ShiftIn1
'       Note: This holds back (~30 msec) host SPIN code until measurement
'             is ready
'-------------------------------------------------------------------------
Read1

ANDN     OUTA,           en1_Pin_Mask  'Set /EN1 LOW, enable device 

MOV      r1,             _Cmd_Measure  'Send Measure command  
CALL     #ShiftOut1

:Wait_DataReady

'Pulse /EN1 line
OR       OUTA,           en1_Pin_Mask  'Set /EN1 HIGH
NOP                                    'Trimming NOP to ensure 100 ns pw
ANDN     OUTA,           en1_Pin_Mask  'Set /EN1 LOW

MOV      r1,             _Cmd_Report   'Request Riport Status    
CALL     #ShiftOut1

MOV      r2,             #4            'Read status and error flag(4 bits)                 
CALL     #ShiftIn1

SUB      _Data_Ready,    r1 WZ, NR     'Exit loop when data is ready
IF_NZ    JMP             #:Wait_DataReady

MOV      r2,             #11           'Read x component of B field                              
CALL     #ShiftIn1
MOV      bx1,            r1            'Store result
              
MOV      r2,             #11           'Read y component of B field                       
CALL     #ShiftIn1
MOV      by1,            r1            'Store result

OR       OUTA,           en1_Pin_Mask  'Set /EN1 HIGH, disable device

'Make 32 bit extension for negative readings
TEST     bx1,            _11bitSign_Mask WZ  'Check sign bit
IF_NZ    OR              bx1, _32bitExt_Mask 'If set extend it to 32 bit

TEST     by1,            _11bitSign_Mask WZ  'Check sign bit
IF_NZ    OR              by1, _32bitExt_Mask 'If set extend it to 32 bit

WRLONG   bx1,            par1_Addr_    'Write results into HUB
WRLONG   by1,            par2_Addr_

Read1_Ret
RET
'-------------------------------------------------------------------------


DAT 'Start1
'-------------------------------------------------------------------------
'--------------------------------┌────────┐-------------------------------
'--------------------------------│ Start1 │-------------------------------
'--------------------------------└────────┘-------------------------------
'-------------------------------------------------------------------------
'     Action: Reads magnetization data from HM55B 1 device continuously
' Parameters: None
'    Results: -bx1, by1 in HUB/par1, par2     'Magn comp. at 1st sensor
'+Reads/Uses: /_Zero
'    +Writes: r1
'      Calls: #Read1
'       Note: Any command from host SPIN code will cause this code to jump
'             out of the measuring loop
'-------------------------------------------------------------------------
Start1

'Clear command
WRLONG   _Zero,          PAR           'Clear command to let SPIN code
                                       'continue
:MeasureLoop

CALL     #Read1

'Check for a nonzero command
RDLONG   r1,             PAR WZ        'Read "command" register from HUB
IF_NZ    JMP             #Dispatcher   'Jump to command table dispatcher
                                       'and quit this loop 

JMP      #:MeasureLoop
'-------------------------------------------------------------------------


DAT 'Reset2
'-------------------------------------------------------------------------
'---------------------------------┌────────┐------------------------------
'---------------------------------│ Reset2 │------------------------------
'---------------------------------└────────┘------------------------------
'-------------------------------------------------------------------------
'     Action: Resets 2nd HM55B sensor
' Parameters: None
'    Results: None
'+Reads/Uses: /en2_Pin_Mask, _Cmd_Reset          
'    +Writes: r1
'      Calls: #Shiftout2
'-------------------------------------------------------------------------
Reset2

ANDN     OUTA,           en2_Pin_Mask  'Set /EN1 Pin LOW  (enable device)  

MOV      r1,             _Cmd_Reset
CALL     #ShiftOut2
              
OR       OUTA,           en2_Pin_Mask  'Set /EN1 Pin HIGH (disable device) 

Reset2_Ret
RET
'-------------------------------------------------------------------------


DAT 'Read2
'-------------------------------------------------------------------------
'---------------------------------┌───────┐-------------------------------
'---------------------------------│ Read2 │-------------------------------
'---------------------------------└───────┘-------------------------------
'-------------------------------------------------------------------------
'     Action: Reads single shot magnetization data from the 2nd HM55B
' Parameters: None
'    Results: Components of B field in sensor's x, y directions bx2, by2
'+Reads/Uses: -/_Cmd_Measure, _Cmd_Report
'             -/en2_Pin_Mask
'             -/_11bitSign_Mask, _32bitExtend_Mask           
'    +Writes: r1, r2
'      Calls: #ShiftOut2
'             #ShiftIn2
'       Note: This holds back (~30 msec) host SPIN code until measurement
'             is ready
'-------------------------------------------------------------------------
Read2

ANDN     OUTA,           en2_Pin_Mask  'Set /EN2 LOW, enable device 

MOV      r1,             _Cmd_Measure  'Send Measure command  
CALL     #ShiftOut2

:Wait_DataReady
'Pulse /EN2 line
OR       OUTA,           en2_Pin_Mask  'Set /EN1 HIGH
NOP                                    'Trimming NOP to ensure 100 ns pw
ANDN     OUTA,           en2_Pin_Mask  'Set /EN1 LOW

MOV      r1,             _Cmd_Report   'Request Status Report    
CALL     #ShiftOut2

MOV      r2,             #4            'Read status and error flag(4 bits)                 
CALL     #ShiftIn2

SUB      _Data_Ready,    r1 WZ, NR     'Exit loop when data is ready
IF_NZ    JMP             #:Wait_DataReady

MOV      r2,             #11           'Read x component of B field                              
CALL     #ShiftIn2
MOV      bx2,            r1            'Store result
              
MOV      r2,             #11           'Read y component of B field                       
CALL     #ShiftIn2
MOV      by2,            r1            'Store result

OR       OUTA,           en2_Pin_Mask  'Set /EN2 HIGH, disable device

'Make 32 bit extension for negative readings
TEST     bx2,            _11bitSign_Mask WZ  'Check sign bit
IF_NZ    OR              bx2, _32bitExt_Mask 'If set extend it to 32 bit

TEST     by2,            _11bitSign_Mask WZ  'Check sign bit
IF_NZ    OR              by2, _32bitExt_Mask 'If set extend it to 32 bit

WRLONG   bx2,            par3_Addr_    'Write results into HUB
WRLONG   by2,            par4_Addr_

Read2_Ret
RET
'-------------------------------------------------------------------------


DAT 'Start12
'-------------------------------------------------------------------------
'-------------------------------┌─────────┐-------------------------------
'-------------------------------│ Start12 │-------------------------------
'-------------------------------└─────────┘-------------------------------
'-------------------------------------------------------------------------
'     Action: Reads magnetization data from both HM55B devices
'             continuously.
' Parameters: None
'    Results: -bx1, by1 in HUB/par1, par2     'Magn comp. at 1st sensor
'             -bx2, by2 in HUB/Par3, par4     'Magn comp. at 2nd sensor
'+Reads/Uses: /_Zero       
'    +Writes: None
'      Calls: #Read1, #Read2
'       Note: Any command from host SPIN code will cause this code to jump
'             out of the measuring loop
'-------------------------------------------------------------------------
Start12

'Clear command
WRLONG   _Zero,          PAR           'Clear command to let SPIN code
                                       'continue
:MeasureLoop

CALL     #Read1
CALL     #Read2

'Check for a nonzero command
RDLONG   r1,             PAR WZ        'Read "command" register from HUB
IF_NZ    JMP             #Dispatcher   'Jump to command table dispatcher
                                       'and quit this loop 

JMP      #:MeasureLoop
'-------------------------------------------------------------------------


DAT '----------------------------PRI PASM code----------------------------
'Now come the "PRIVATE" PASM routines of this Driver. They are "PRI" in
'the sense that they do not have "command No." and they do not use par1,
'par2, etc... 


DAT 'ShiftOut1
'-------------------------------------------------------------------------
'-------------------------------┌───────────┐-----------------------------
'-------------------------------│ ShiftOut1 │-----------------------------
'-------------------------------└───────────┘-----------------------------
'-------------------------------------------------------------------------
'     Action: Shifts out 4 bits to 1st HM55B device
' Parameters: 4 bit data in LSBs of r1
'    Results: None
'+Reads/Uses: /dio1_Pin_Mask          
'    +Writes: r2, r3
'      Calls: #Clk1_Pulse
'-------------------------------------------------------------------------
ShiftOut1
                              
ANDN     OUTA,           dio1_Pin_Mask   'Pre-Set Data pin LOW
OR       DIRA,           dio1_Pin_Mask   'Set Data pin as an OUTPUT

MOV      r2,             #4              'Number of data bits to output
MOV      r3,             #%1000          'Mask for MSBFIRST type shiftout
                                                   
:Loop
TEST     r1,             r3 WC           'Copy databit at mask into C 
MUXC     OUTA,           dio1_Pin_Mask   'Set DIO line HIGH or LOW as C
SHR      r3,             #1              'Move mask right on next databit  
CALL     #Clk_Pulse1                     'Send a clock pulse
DJNZ     r2,             #:Loop          'Decrement r2, jump if not Zero

ANDN     DIRA,           dio1_Pin_Mask   'Set DIO1 pin as an INPUT 

ShiftOut1_Ret
RET
'-------------------------------------------------------------------------


DAT 'ShiftIn1
'-------------------------------------------------------------------------
'--------------------------------┌──────────┐-----------------------------
'--------------------------------│ ShiftIn1 │-----------------------------
'--------------------------------└──────────┘-----------------------------
'-------------------------------------------------------------------------
'     Action: Shifts in bits from 1st HM55B device in a MSBFIRST way
' Parameters: Number of bits in r2
'    Results: Entry in r1
'+Reads/Uses: /dio1_Pin_Mask          
'    +Writes: r2
'      Calls: #Clk1_Pulse
'-------------------------------------------------------------------------
ShiftIn1
                             
ANDN     DIRA,           dio1_Pin_Mask 'Set Data pin as an INPUT
MOV      r1,             #0            'Clear r1

:Loop
CALL     #Clk_Pulse1                   'Send clock pulse
TEST     dio1_Pin_Mask,  INA WC        'Read Data Bit into 'C' flag and
RCL      r1,             #1            'rotate it into LSB of return value
DJNZ     r2,             #:Loop        'Decrement r2, jump if not Zero

ShiftIn1_ret
RET              
'-------------------------------------------------------------------------


DAT 'Clk_Pulse1
'-------------------------------------------------------------------------
'-------------------------------┌────────────┐----------------------------
'-------------------------------│ Clk_Pulse1 │----------------------------
'-------------------------------└────────────┘----------------------------
'-------------------------------------------------------------------------
'     Action: Sends a 100 ns pulse to CLK pin of 1st HM55B module
' Parameters: None
'    Results: None 
'+Reads/Uses: /clk1_Pin_Mask
'    +Writes: None
'      Calls: None
'       Note: At 80 MHz the clock pulse width is about 100 ns (8 ticks) 
'-------------------------------------------------------------------------
Clk_Pulse1

OR       OUTA,           clk1_Pin_Mask 'Set CLK1 pin HIGH
NOP                                    'Trimming NOP to ensure 100 ns pw
ANDN     OUTA,           clk1_Pin_Mask 'Set CLK1 pin LOW
  
Clk_Pulse1_Ret         
RET
'-------------------------------------------------------------------------


DAT 'ShiftOut2
'-------------------------------------------------------------------------
'-------------------------------┌───────────┐-----------------------------
'-------------------------------│ ShiftOut2 │-----------------------------
'-------------------------------└───────────┘-----------------------------
'-------------------------------------------------------------------------
'     Action: Shifts out 4 bits to 2nd HM55B device
' Parameters: 4 bit data in LSBs of r1
'    Results: None
'+Reads/Uses: /dio2_Pin_Mask          
'    +Writes: r2, r3
'      Calls: #Clk2_Pulse
'-------------------------------------------------------------------------
ShiftOut2
                              
ANDN     OUTA,           dio2_Pin_Mask   'Pre-Set Data pin LOW
OR       DIRA,           dio2_Pin_Mask   'Set Data pin as an OUTPUT

MOV      r2,             #4              'Number of data bits to output
MOV      r3,             #%1000          'Mask for MSBFIRST type shiftout
                                                   
:Loop
TEST     r1,             r3 WC           'Copy databit at mask into C
MUXC     OUTA,           dio2_Pin_Mask   'Set DIO line HIGH or LOW as C
SHR      r3,             #1              'Move mask right on next databit
CALL     #Clk_Pulse2                     'Send a clock pulse
DJNZ     r2,             #:Loop          'Decrement r2, jump if not Zero

ANDN     DIRA,           dio2_Pin_Mask   'Set DIO1 pin as an INPUT 

ShiftOut2_Ret
RET
'-------------------------------------------------------------------------


DAT 'ShiftIn2
'-------------------------------------------------------------------------
'-------------------------------┌──────────┐------------------------------
'-------------------------------│ ShiftIn2 │------------------------------
'-------------------------------└──────────┘------------------------------
'-------------------------------------------------------------------------
'     Action: Shifts in bits from 2nd HM55B device in MSBFIRST way
' Parameters: Number of bits in r2
'    Results: Entry in r1
'+Reads/Uses: /dio2_Pin_Mask          
'    +Writes: r2
'      Calls: #Clk2_Pulse
'-------------------------------------------------------------------------
ShiftIn2
                             
ANDN     DIRA,           dio2_Pin_Mask 'Set Data pin as an INPUT
MOV      r1,             #0            'Clear r1

:Loop
CALL     #Clk_Pulse2                   'Send a clock pulse
TEST     dio2_Pin_Mask,  INA WC        'Read Data Bit into 'C' flag and
RCL      r1,             #1            'rotate it into LSB of return value
DJNZ     r2,             #:Loop        'Decrement r2, jump if not Zero

ShiftIn2_ret
RET              
'-------------------------------------------------------------------------


DAT 'Clk_Pulse2
'-------------------------------------------------------------------------
'-------------------------------┌────────────┐----------------------------
'-------------------------------│ Clk_Pulse2 │----------------------------
'-------------------------------└────────────┘----------------------------
'-------------------------------------------------------------------------
'     Action: Sends a 100 ns pulse to CLK pin of 2nd HM55B module
' Parameters: None
'    Results: None 
'+Reads/Uses: /clk2_Pin_Mask
'    +Writes: None
'      Calls: None
'       Note: At 80 MHz the clock pulse width is about 100 ns (8 ticks) 
'-------------------------------------------------------------------------
Clk_Pulse2

OR       OUTA,           clk2_Pin_Mask 'Set CLK2 Pin HIGH
NOP                                    'Trimming NOP to ensure 100 ns pw
ANDN     OUTA,           clk2_Pin_Mask 'Set CLK2 Pin LOW
  
Clk_Pulse2_Ret         
RET
'------------------------------------------------------------------------- 


DAT '-----------COG memory allocation defined by PASM symbols-------------

'-------------------------------------------------------------------------
'----------------------Initialized data for constants---------------------
'-------------------------------------------------------------------------
_Zero              LONG    0

'HM55B commands 
_Cmd_Reset         LONG    %0000
_Cmd_Measure       LONG    %1000
_Cmd_Report        LONG    %1100

'HM55B flags
_Data_Ready        LONG    %1100       'Data ready (no error) condition

'_Error             LONG    %0011       'ADC overflow error condition
'_TimeOut           LONG    4_000_000   '50 msec at 80 MHz
'These are not yet used but they should be in next version of the driver

'32 bit extension masks
_11bitSign_Mask    LONG    %00000000_00000000_00000100_00000000 '11th bit  
_32bitExt_Mask     LONG    %11111111_11111111_11111000_00000000 'Above 11 


'-------------------------------------------------------------------------
'---------------------Uninitialized data for variables--------------------
'-------------------------------------------------------------------------

'-----------------------------------Mode----------------------------------
cmode              RES     1           'Mode 

'----------------------------------Pin Masks------------------------------
en1_Pin_Mask       RES     1           'Pin mask in COG for /EN1          
clk1_Pin_Mask      RES     1           'Pin mask in COG for CLK1          
dio1_Pin_Mask      RES     1           'Pin mask in COG for DIO1
en2_Pin_Mask       RES     1           'Pin mask in COG for /EN2          
clk2_Pin_Mask      RES     1           'Pin mask in COG for CLK2         
dio2_Pin_Mask      RES     1           'Pin mask in COG for DIO2         

'----------------------------HUB memory addresses-------------------------
par1_Addr_         RES     1
par2_Addr_         RES     1
par3_Addr_         RES     1
par4_Addr_         RES     1

'-----------------------Data read from HM55B Modules----------------------
bx1                RES     1       'Bx magnetic field in ≈uT at sensor 1
by1                RES     1       'By magnetic field in ≈uT at sensor 1
bx2                RES     1       'Bx magnetic field in ≈uT at sensor 2
by2                RES     1       'By magnetic field in ≈uT at sensor 2

'----------------------Recycled Temporary Registers-----------------------
r1                 RES     1         
r2                 RES     1         
r3                 RES     1

FIT                496


DAT '---------------------------MIT License-------------------------------


{{
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │                                                            
├────────────────────────────────────────────────────────────────────────┤
│  Permission is hereby granted, free of charge, to any person obtaining │
│ a copy of this software and associated documentation files (the        │ 
│ "Software"), to deal in the Software without restriction, including    │
│ without limitation the rights to use, copy, modify, merge, publish,    │
│ distribute, sublicense, and/or sell copies of the Software, and to     │
│ permit persons to whom the Software is furnished to do so, subject to  │
│ the following conditions:                                              │
│                                                                        │
│  The above copyright notice and this permission notice shall be        │
│ included in all copies or substantial portions of the Software.        │  
│                                                                        │
│  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND        │
│ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     │
│ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. │
│ IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   │
│ CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   │
│ TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      │
│ SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 │
└────────────────────────────────────────────────────────────────────────┘
}}                                  