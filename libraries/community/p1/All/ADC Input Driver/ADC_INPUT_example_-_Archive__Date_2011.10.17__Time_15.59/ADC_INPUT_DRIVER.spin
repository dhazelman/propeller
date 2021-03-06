''*********************************************
''*  ADC Input Driver v2.0                    *
''*  Supports 8- to 16-bit, up to 8 channels  *
''*  Designed for the MCP3X0X series of ADCs  *
''*  Author: Brandon Nimon                    *
''*  Created: 16 July, 2009                   *
''*  Copyright (c) 2009 Parallax, Inc.        *
''*  See end of file for terms of use.        * 
''***********************************************************************************
''* Driver features include support for Microchip ADCs with anywhere between 1 and  *
''* 8 ADC input channels and resolutions of 16 bits or less. Both single-ended and  *
''* differential modes are supported. The driver adds support for frequency reading *
''* on each of the channels and allows the ADC to react as a programmable Schmitt   *
''* trigger. Also available is gathering of maximum and minimum or average values   *
''* of the channels over time. The driver can wait for a channel to achieve a       *
''* specific state, or can even be put into standby to save power. Channel values   *
''* and states are available to multiple objects if the driver is supplied with     *
''* variables to store the information.                                             *
''*                                                                                 * 
''* A channel is considered "high" only after the channel's value is above the high *
''* threshold. It is considered "low" when the value is below or equal to low       *
''* threshold. Thus making 0 a valid value for both high and low threshold, but     *
''* (for a 12-bit ADC) 4095 would not be a valid value as the "high" state would    *     
''* never be achieved (4094 would be valid).                                        *     
''*                                                                                 *
''* The waithigh, waitlow, getfreq, and average routines don't start until the      *
''* program cycles around to the channel that has been selected. Then the ADC       *
''* samples will be completely dedicated to the selected task (all other channels'  *
''* values are ignored).                                                            *
''*                                                                                 *
''* Due to channel sample speed changing between the different routines, the output *
''* values may vary slightly (read the ADC's datasheet for more information). For   *
''* example: during testing, displaying max/min values on a consistent input gave a *
''* max value of 3712 and a minimum of 3711, but when getting the average of the    *
''* same channel, it read 3702. This is due to the fact that the channel was being  *
''* sampled eight times more often during the average routine than during the       *
''* normal operation. This results will vary based on number of channels being      *
''* scanned.                                                                        *
''*                                                                                 *
''* For many of the routines with a watchdog value, zero can be put in its place to *
''* disable it. This will make the PASM cog attempt to fulfill the task             *
''* indefinitely. The controlling cog will wait indefinitely for the PASM cog to    *
''* complete. Normally, the watchdog value is the maximum amount of time to wait in *
''* milliseconds (1/1000th of a second).                                            *
''*                                                                                 *
''* FastMode should only be used after extensive testing with your hardware. When   *
''* enabled at or above 80MHz (on a 10-bit device) or 64MHz (on a 12-bit device),   *
''* it is likely that the driver will communicate with the ADC at faster speeds     *
''* than are specified in the datasheet. Many ADCs can handle the extra speed but   *
''* each chip has a slightly different threshold for speed, and even temperature    *
''* can affect maximum communication rate. If sporadic or unusual numbers are       *
''* received, try disabling FastMode or lowering your clock speed.                  *
''*                                                                                 *
''* Example wiring would be as follows:                                             *
''*               R1                                                                *
''*     ADC─┳──┳──input                                                         *
''*       C1 R2                                                                 *
''*                                                                               *
''* R1: 10K (high impedance input is helpful, 10K should be the minimum)            *
''* R2: 100K (this effectively creates a voltage divider, but also drives input to  *
''*     zero volts when not in use)                                                 *
''* C1: 0.01µF (10000pF is the about the maximum you would want to use. The         *
''* capacitor reduces jitter or spikes but also reduces resolution).                *
''***********************************************************************************
''
'' Notes:
''      single-channel ADCs must always have FastMode disabled.
''      getval, getmax, getmin, and getstate
''                      
'' Updates:
''      1.1 (28 July, 2009):
''              Added alternate start method: start_pointed. This allows for multiple objects to access
''                current channel value, state, and max/min. The parent object supplies 4 8-long
''                blocks which are used instead of this object's blocks.
''              Shifting in and out has been sped up. Fewer instructions are used per bit.
''      1.2 (29 July, 2009):
''              Created a "fast" and "slow" method of shifting in and out. This allows the driver to
''                function closer to the ADC's maximum sample rate at 5V. For 12-bit ADCs, it still runs 
''                faster than is specified in the MCP32XX datasheet, almost all ADCs should be able to 
''                run at the provided speeds. Clock speeds of 80MHz or faster uses the "slow" method, 
''                while slower speeds will use the "fast" method.
''              Updated documentation with tables and better descriptions of sample speed.
''      1.3 (30 July, 2009):
''              Fixed freeze when standby_disable was called when not in standby.
''              Fixed problem where waitlow would always return 0 (whether it timed out or not).
''              Renamed curval to getval for uniformity in method names.
''              Wait methods can now be put into a mode to ignore or read current state before the
''                driver actually starts waiting.
''      1.3.1 (3 August, 2009):
''              Add lines of code to make sure threshold values are valid.
''      2.0.0 (22 October, 2009):
''              Added support for 2 and 1 channel ADCs (now supports 8, 4, 2, and 1 channel ADCs).
''              Added parameters to main method calls to allow for multiple types of ADCs in the same
''                program (specific values are parameters instead of constants). 
''              Period meassuring for frequency method is now averaged (in PASM)
''              Slight optimizations in SPIN coding.
''      2.0.1 (5 November, 2009):
''              Added wait for driver to fully initialize (so commands don't get sent before driver is
''                ready).
''      2.1.0 (12 July, 2011):
''              Replaced clock speed/bit detection with FastMode parameter to manually set driver
''                communicate speed. Different ADCs have different communication speed requirements. 
''              Fixed minimum waitlength in standby_enable.
''              Any command that brings the driver out of standby will be executed (instead of ignored).
''              Rearranged methods into a more logical and useful order.
''              Commands are executed using a jump table, so things are faster, especially the higher
''                number commands.
''              Other minor speed and size optimizations.
''      2.1.1 (15 July, 2011):
''              Added retperiod parameter to getfreq to get back just the period length instead of a
''                frequency. This gives you flexibility to perform more precise math on the results. 
''              Fixed problem with waitlow.
''      2.1.2 (21 July, 2011):
''              Fixed a bug in average where entering a value of less than 1 in samples would return
''                unexpected results (it really shouldn't ever be less than 1 anyway).
''      2.1.3 (17 October, 2011):
''              Fixed bug that allowed single channel ADCs to run in fast mode, this didn't work.
''              Minor size and speed optimizations.
''      
''
'' Future additions:                                                                                                                    
''      Add ability to alter each channel's threshold separately (may slow down the driver too much).            
''      Instead of limiting the total number of channels, enable/disable the channels based on a bit of
''        a byte value (also make it so the channels could be changed on the fly).
''      Reduce the variable space (combine variables, use 4 longs instead of 8, etc.).                   
''

CON

  default_low_threshold  = 100  ' default "low" threshold value                                 (min: 0, max: 2^bits_s_in - 2)
  default_high_threshold = 500  ' default "high" threshold value                                (min: 0, max: 2^bits_s_in - 2)

OBJ

VAR    

  BYTE cogon, cog 
  LONG timescale

  ''===[ 49 longs, DO NOT alter order! ]===
  LONG tx_pin                   
  LONG rx_pin         
  LONG ck_pin         
  LONG cs_pin
  LONG adcch         
  LONG channels
  LONG bits_s_in      
  LONG mode       
  LONG fastslow
  LONG par1
  LONG par2      
  LONG ptr_start
  LONG done           
  LONG channel        
  LONG duration 
  LONG retval 
  LONG count
  LONG command        
  LONG chanstate[8]   
  LONG chanval[8]     
  LONG chanmax[8]    
  LONG chanmin[8]     

             
PUB start (DTPin, INPin, ClkPin, RSPin, ChCount, ActChannels, BitCount, SingDiff, FastMode) 
'' Starts driver.
'' DTPin: outgoing (from µController) serial data pin (0-31); ignored if 1-channel ADC
'' INPin: incoming (to µController) serial data pin (0-31)
'' ClkPin: serial clock pin (0-31)
'' RSPin: reset, CS pin (0-31)
'' ChCount: Number of channels on ADC (8 = 3208/3008; 4 = 3204/3004; 2 = 3202/3002; 1 = 3201/3001)
'' ActChannels: number of channels to scan (1-8)
'' BitCount: number of bits the ADC outputs (2-16)
'' SingDiff: ADC single or differential mode (1 = single, 0 = differential)
'' FastMode: Set driver to faster communication. Fast mode may excede specifications of ADC. (True/False)                        

'=====[ SETTINGS ]==============
  par1 := default_low_threshold ' default "low" threshold value                                 (min: 0, max: 2^bits_s_in - 2)
  par2 := default_high_threshold' default "high" threshold value                                (min: 0, max: 2^bits_s_in - 2)
'===============================

  stop
  longfill(@done, 0, 38)
  longmove(@tx_pin, @DTPin, 9)   
  ptr_start := 0  
  timescale := clkfreq / 1000   ' milliseconds -- could be changed to any scale

  cogon := (cog := cognew(@entry, @tx_pin))

  waitcnt(7000 + cnt)           ' wait for driver to fully initialize
  
  RETURN cogon 

PUB start_pointed (DTPin, INPin, ClkPin, RSPin, ChCount, ActChannels, BitCount, SingDiff, FastMode, chanstate_ptr, chanval_ptr, chanmax_ptr, chanmin_ptr)
'' Starts the driver, but with 4 supplied 8-long blocks.
'' DTPin: outgoing (from µController) serial data pin (0-31); ignored if 1-channel ADC
'' INPin: incoming (to µController) serial data pin (0-31)
'' ClkPin: serial clock pin (0-31)
'' RSPin: reset, CS pin (0-31)
'' ChCount: Number of channels on ADC (8 = 3208/3008; 4 = 3204/3004; 2 = 3202/3002; 1 = 3201/3001)
'' ActChannels: number of channels to scan (1-8)
'' BitCount: number of bits the ADC outputs (2-16)
'' SingDiff: ADC single or differential mode (1 = single, 0 = differential)
'' FastMode: Set driver to faster communication. Fast mode may excede specifications of ADC. (True/False)                        
'' *_ptr: The address of the array of longs to store the information.                        
''                                                               
'' Note: This type of start grants the ability to access channels states and values in a faster method (e.g.
''       adcstate[7] -- similar to ina[7]). It also allows for multiple objects to get the same information from
''       this object. Of course, only the object that started this driver has access to the normal functions
''       (threshold, freq, average, etc.).
''       If this method is used to start the driver, the getmax, getmin, getstate, and getval functions will not
''       operate as expected. Use the supplied variables for the values given by those functions.

'=====[ SETTINGS ]==============
  par1 := default_low_threshold ' default "low" threshold value                                 (min: 0, max: 2^bits_s_in - 2)
  par2 := default_high_threshold' default "high" threshold value                                (min: 0, max: 2^bits_s_in - 2)
'===============================

  stop
  longfill(@done, 0, 38)
  longmove(@tx_pin, @DTPin, 9)
  ptr_start := -1   
  timescale := clkfreq / 1000   ' milliseconds -- could be changed to any scale

  chanstate := chanstate_ptr
  chanval := chanval_ptr
  chanmax := chanmax_ptr
  chanmin := chanmin_ptr   

  cogon := (cog := cognew(@entry, @tx_pin))

  waitcnt(7000 + cnt)           ' wait for driver to fully initialize

  RETURN cogon  

PUB stop
'' Stops cog if running
              
  IF (cogon~)
    cogstop(cog) 

PUB getval (ch)
'' returns current value of this channel

  RETURN chanval[ch]

PUB getmax (ch)
'' return maximum value on this channel since last reset

  RETURN chanmax[ch]

PUB getmin (ch)
'' return minimum value on this channel since last reset

  RETURN chanmin[ch]

PUB getstate (ch)
'' returns current state of this channel (-1 == high or 0 == low)

  RETURN chanstate[ch]  

PUB setthreshold (low, high)
'' sets the high/low thresholds for all channels
                                               
  par1 := low
  par2 := high   
  command := 1 
          
PUB resetmaxminall
'' reset maximum and minimum values on all channels (min set to 0 and max set to max ADC value based on bits_s_in)
                
  command := 2
          
PUB resetmax (ch)
'' reset maximum value on this channel (set to 0)
                                              
  channel := ch
  command := 3  

PUB resetmin (ch)
'' reset minimum value on this channel (set to max ADC value based on bits_s_in)
                                              
  channel := ch
  command := 4

PUB standby_enable (waitlength)
'' puts the ADC into standby mode, the ADC isn't sampled, and the cog is in waitcnt most of the time
'' Note: checks for any command every waitlength cycles (higher values use slightly less power, but the cog may
''       have to wait before the next command can be issued. A suggestion for waitlength would be 8000, as it
''       would check for a new command every 100µS.  
                   
  par1 := waitlength #> 32
  command := 5

PUB standby_disable
'' an ignored command to pull the ADC out of standby
                 
  done := 0
  command := -1
  REPEAT UNTIL (done)
 
PUB waithigh (ch, watchdog, waitmode)
'' wait until this channel is in high state (returns channel value at end of wait in case of watchdog timeout)
'' waitmode enables or disables acknolegment of current channel state. Meaning, if waitmode is 0 and the channel
''       is currently high, but the actual value is floating between the two thresholds it is not considered
''       high. In this mode, the method will only return when the channel's value has exceeded the high
''       threshold level. waitmode 1 will read current channel state to see if it is high, if it is it will
''       return immediately.

  IFNOT (_checkchannel(ch))
    RETURN false

  done := 0
  par1 := waitmode
  duration := timescale * watchdog
  channel := ch
  command := 6
  REPEAT UNTIL (done)

  RETURN retval

PUB waitlow (ch, watchdog, waitmode)
'' wait until this channel is in low state (returns channel value at end of wait in case of watchdog timeout)
'' waitmode enables or disables acknolegment of current channel state. Meaning, if waitmode is 0 and the channel
''       is currently low, but the actual value is floating between the two thresholds it is not considered
''       low. In this mode, the method will only return when the channel's value is eqaul or below the threshold
''       level. waitmode 1 will read current channel state to see if it is low, if it is it will return
''       immediately.

  IFNOT (_checkchannel(ch))
    RETURN false

  done := 0
  par1 := waitmode
  duration := timescale * watchdog
  channel := ch
  command := 7
  REPEAT UNTIL (done)

  RETURN retval

PUB getfreq (ch, watchdog, precision, highhold, retperiod)
'' return frequency on this channel
'' Note: This function waits for a high-to-low transition, then starts a timer. Once 2 to-the-power-of precision
''       high-to-low transitions have been achieved, it averages the period lengths between the high-to-low
''       transitions and returns the period length in retval. The frequency is determined by dividing current
''       clock speed by the period length. 0 precision means it wait for only one frequency cycle, while 5 will
''       make it wait for 32 cycles then average the results.
''       highhold can reduce the function's resolution by requiring the channel's high-state to be held for a
''       certain number of cycles. 0 disables the feature.
''       retperiod is a boolean value to return the average period (length) rather than the frequency in Hz.

  IFNOT (_checkchannel(ch))
    RETURN false

  done := 0
  par1 := precision
  par2 := highhold
  duration := timescale * watchdog
  channel := ch
  command := 8
  REPEAT UNTIL (done)

  IF (retperiod)
    RETURN retval
  ELSE
    RETURN clkfreq / retval 

PUB average (ch, samples)
'' return average value of a channel for a certain number of samples   

  IFNOT (_checkchannel(ch))
    RETURN false

  done := 0
  par1 := (samples #> 1)
  channel := ch
  command := 9
  REPEAT UNTIL (done)

  RETURN retval / par1

PUB average_time (ch, watchdog)
'' return average value of a channel for a certain period of time   

  IFNOT (_checkchannel(ch))
    RETURN false

  done := 0
  duration := timescale * (watchdog #> 1)                                       ' do not allow 0 as a value
  channel := ch
  command := 10
  REPEAT UNTIL (done)

  RETURN retval / count

PUB getsamples
'' returns number of samples taken during last operation

  RETURN count

PRI _checkchannel (ch)
'' Check if cannel being accessed is being monitored (without this check, driver locks up)

  IF (ch => channels)
    RETURN false
  RETURN true

DAT
                        ORG
'=====[ START ]=========================================                        
entry
'-----[ SETUP VALUES, PINS, AND TIMER ]-----------------
                        MOV     p1, PAR
                        RDLONG  p2, p1                  ' get data-out (TX) pin
                        MOV     DPin2, p2
                        MOV     DPin, #1
                        SHL     DPin, p2   
                        
                        ADD     p1, #4
                        RDLONG  p2, p1                  ' get data-in (RX) pin
                        MOV     NPin, #1
                        SHL     NPin, p2

                        ADD     p1, #4
                        RDLONG  p2, p1                  ' get clock (CLK) pin
                        MOV     CPin2, p2
                        MOV     CPin, #1
                        SHL     CPin, p2

                        ADD     p1, #4
                        RDLONG  p2, p1                  ' get reset (CS) pin
                        MOV     CSPin, #1
                        SHL     CSPin, p2

                        ADD     p1, #4
                        RDLONG  adcchs, p1              ' get ADC being used (8/4/2/1-channel ADC)

                        CMP     adcchs, #1      WZ      ' if 1 channel ADC
              IF_NZ     JMP     #:skip1
                        MOV     sval, #0
                        MOV     dval, #0
                        MOV     valplus1, #0
                        MOV     nullbits, #3
                        JMP     #:vdone
                        
:skip1                  CMP     adcchs, #2      WZ      ' if 2 channel ADC     
              IF_NZ     JMP     #:skip2
                        MOV     sval, sval_2
                        MOV     dval, dval_2
                        MOV     valplus1, valplus1_2
                        MOV     nullbits, #0
                        JMP     #:vdone

:skip2                  MOV     sval, sval_8            ' if nothing else...assumed 8/4 channel ADC
                        MOV     dval, dval_8
                        MOV     valplus1, valplus1_8
                        MOV     nullbits, #2
:vdone

                        ADD     p1, #4
                        RDLONG  chs, p1                 ' get number of channels to monitor

                        MAX     chs, adcchs             ' limit channels scanned to channels on ADC
                        
                        ADD     p1, #4
                        RDLONG  bitssin, p1             ' get number bits to shift in
                        MOV     bitssin1, bitssin
                        SUB     bitssin1, #1            ' number of bits to ignore (usually shift-in-bits minus 1)                                                                                 

                        ADD     p1, #4
                        RDLONG  p2, p1          WZ      ' get mode: single/differential
              IF_NZ     MOV     mval, sval              ' single
              IF_Z      MOV     mval, dval              ' differential
                        
                        ADD     p1, #4
                        RDLONG  fs, p1                  ' get speed mode (-1 == fast, 0 == slow)
                        CMP     adcchs, #1      WZ      ' if 1 channel ADC
              IF_Z      MOV     fs, #0                  ' force slow mode

                        ADD     p1, #4
                        MOV     pr1_addr, p1            ' get parameter1 address
                        RDLONG  chlow, p1               ' set low threshold
                        
                        ADD     p1, #4
                        MOV     pr2_addr, p1            ' get parameter2 address
                        RDLONG  chhigh, p1              ' set high threshold                          

                        ADD     p1, #4
                        RDLONG  p3, p1                  ' get start type (-1 == pointer, 0 == normal)

                        ADD     p1, #4
                        MOV     done_addr, p1           ' get "completed" mark address

                        ADD     p1, #4
                        MOV     chl_addr, p1            ' output value address

                        ADD     p1, #4
                        MOV     wd_addr, p1             ' watchdog timeout address

                        ADD     p1, #4
                        MOV     out_addr, p1            ' output value address

                        ADD     p1, #4
                        MOV     count_addr, p1          ' get sample count value address

                        ADD     p1, #4
                        MOV     cmd_addr, p1            ' get input command address

                        TJNZ    p3, #:pointer_start     ' pointers

                        ADD     p1, #4
                        MOV     state_addr, p1          ' get state address  

                        ADD     p1, #32
                        MOV     chval_addr, p1          ' get state address  

                        ADD     p1, #32
                        MOV     max_addr, p1            ' get channel max address

                        ADD     p1, #32
                        MOV     min_addr, p1            ' get channel min address

                        JMP     #:cont   

:pointer_start          ADD     p1, #4
                        RDLONG  state_addr, p1          ' get state address  

                        ADD     p1, #32
                        RDLONG  chval_addr, p1          ' get state address  

                        ADD     p1, #32
                        RDLONG  max_addr, p1            ' get channel max address

                        ADD     p1, #32
                        RDLONG  min_addr, p1            ' get channel min address                                                
:cont

                        MOV     OUTA, CSPin             ' set CS pin high (inactive) 
                        MOV     DIRA, CPin              ' set pins we use to output
                        OR      DIRA, CSPin             ' set pins we use to output
                                                                                
                        MOV     val, mval     
                        MOV     val2, val               ' backup
                                      
                        MOV     chmin, #1
                        TEST    chmin, #1     WC        ' set C
                        RCL     chmin, bitssin1         ' rotate 1's into val_min to set 1 to all bits bitssin deep
                        MOV     adcmax, chmin           ' store maximum value
                        
                        MOVD    :setmax, #chmax         ' probably not necessary, but just in case (only happens during setup)
                        MOV     idx, #8                 ' do to all eight channels
:setmax                 MOV     chmax, #0               ' set to zero
                        ADD     :setmax, dplus1         ' move pointer
                        DJNZ    idx, #:setmax

                        MOVD    :setmin, #chmin         ' probably not necessary, but just in case (only happens during setup)
                        MOV     idx, #8                 ' do to all eight channels
:setmin                 MOV     chmin, adcmax           ' set to max value
                        ADD     :setmin, dplus1         ' move pointer
                        DJNZ    idx, #:setmin                         

                        MINS    chlow, #0               ' make sure low value is not below 0
                        SUB     adcmax, #1              ' reduce max by one so "high" is possible
                        MAXS    chhigh, adcmax          ' make sure high value is not above max ADC value
                        ADD     adcmax, #1              ' return adcmax back to original location                        
                        
                        MOV     idx, #0                 ' clear any possible values
                        MOV     cmd, #0                 ' clear any possible values
                        MOV     output, #0              ' clear any possible values
                        MOV     clkready, #0            ' clear any possible values  
                        MOV     strt, #0                ' clear any possible values
                        MOV     roll, #0                ' clear any possible values
                        MOV     curchl, #0              ' clear any possible values                                                          


                        CMP     adcchs, #1      WZ
              IF_NZ     MOV     CTRA, nco
              IF_NZ     ADD     CTRA, DPin2             ' NCO on this pin number 
                        
                        TJZ     fs, #mainloop           ' if in slow mode, skip CTRB setup
                        MOV     CTRB, nco
                        ADD     CTRB, CPin2             ' NCO on this pin number
                        MOV     FRQB, #1   

'-----[ MAIN LOOP ]-------------------------------------
mainloop
                        MOV     bits_in, bitssin        ' set to reset value  

                        MOV     PHSA, val2              ' get backup 
                        TJNZ    fs, #fast_shift         ' if fast mode, go to fast shift

                        MOV     Bits, #4                ' 5 bit output
                        
                        ANDN    OUTA, CSPin             ' set CS pin low (active)

                        
'-----[ SHIFT COMMAND OUT ]-----------------------------
                        CMP     adcchs, #1      WZ      ' if single channel ADC, no info to give
              IF_Z      JMP     #:skip
              
                        OR      DIRA, DPin              ' set pins we use to output

                        OR      OUTA, CPin              ' start clock cycle
                        ANDN    OUTA, CPin              ' end clock cycle
:shift_out_slow                                                                                    
                                                                                                                        
                        SHL     PHSA, #1                ' shift output value 
                        OR      OUTA, CPin              ' start clock cycle
                        ANDN    OUTA, CPin              ' end clock cycle

                        DJNZ    Bits, #:shift_out_slow

                        ANDN    DIRA, DPin              ' set pins we use to input (so same IO can be used for RX and TX)
                        
:skip                        
'-----[ NULL BITS ]-------------------------------------
                        TJZ     nullbits, #:cont        ' if zero ignore bits, skip this
                        MOV     emptyclk, nullbits      ' ignore bits
:empty                                                  ' generate empty clocks to ditch unwanted bits
                        OR      OUTA, CPin              ' start clock cycle
                        ANDN    OUTA, CPin              ' end clock cycle
                                               
                        DJNZ    emptyclk, #:empty   
                        
:cont                        
'-----[ SHIFT MSB VALUE IN ]----------------------------
                        MOV     val_out, #0             ' set to reset value (0)      
shift_in_slow
                        TEST    NPin, INA       WC      ' if data input pin is high  
                        RCL     val_out, #1             ' add input pin value to output
                       
                        OR      OUTA, CPin              ' start clock cycle
                        ANDN    OUTA, CPin              ' end clock cycle                       
                        ''NOP                             ' slow down input (slowest part of ADC) add this NOP if not reading information at 80MHz (or faster)

                        DJNZ    bits_in, #shift_in_slow ' continue to end of input value
                        
                        
'-----[ SHIFT LSB IN AND IGNORE ]-----------------------
                        CMP     adcchs, #2      WZ      ' if 2-channel ADC
              IF_NZ     CMP     adcchs, #1      WZ      ' or 1-channel ADC
              IF_Z      JMP     #:skip                  ' skip the ignore bits
              
                        MOV     emptyclk, bitssin1
:empty                                                  ' generate empty clocks to ditch unwanted bits   
                        OR      OUTA, CPin              ' start clock cycle
                        ANDN    OUTA, CPin              ' end clock cycle
                                               
                        DJNZ    emptyclk, #:empty
                          
:skip                   OR      OUTA, CSPin             ' set CS pin high (inactive)
                        JMP     #maxch1                                    
'=====[ END OF SLOW SHIFT ]=============================

fast_shift                                                                                        
                        ANDN    OUTA, CSPin             ' set CS pin low (active)

                        
'-----[ SHIFT COMMAND OUT ]-----------------------------
                        OR      DIRA, DPin              ' set pins we use to output
shift_out                                                                                        
                        NEG     PHSB, #3                ' Send a pulse 3 clocks long                                                                                                
                        SHL     PHSA, #1                ' shift output value 
                        NEG     PHSB, #3                ' Send a pulse 3 clocks long                       
                        SHL     PHSA, #1                ' shift output value 
                        NEG     PHSB, #3                ' Send a pulse 3 clocks long                       
                        SHL     PHSA, #1                ' shift output value  
                        NEG     PHSB, #3                ' Send a pulse 3 clocks long                       
                        SHL     PHSA, #1                ' shift output value  
                        NEG     PHSB, #3                ' Send a pulse 3 clocks long
                                                
                        ANDN    DIRA, DPin              ' set pins we use to input (so same IO can be used for RX and TX)

        
'-----[ NULL BITS ]-------------------------------------
                        TJZ     nullbits, #:cont        ' if zero ignore bits, skip this
                        MOV     emptyclk, nullbits      ' ignore bits
:empty                                                  ' generate empty clocks to ditch unwanted bits
                        NEG     PHSB, #3                ' Send a pulse 3 clocks long
                        DJNZ    emptyclk, #:empty   
                        
:cont                        
'-----[ SHIFT MSB VALUE IN ]----------------------------
                        MOV     val_out, #0             ' set to reset value (0)      
shift_in                                                                 
                        TEST    NPin, INA       WC      ' if data input pin is high  
                        RCL     val_out, #1             ' add input pin value to output
                        NEG     PHSB, #3                ' Send a pulse 3 clocks long
                        
                        DJNZ    bits_in, #shift_in      ' continue to end of input value
                        
                        
'-----[ SHIFT LSB IN AND IGNORE ]-----------------------
                        CMP     adcchs, #2      WZ      ' if 2-channel ADC
              IF_Z      JMP     #:skip                  ' skip the ignore bits
              
                        MOV     emptyclk, bitssin1
:empty                                                  ' generate empty clocks to ditch unwanted bits   
                        NEG     PHSB, #3                ' Send a pulse 3 clocks long
                        DJNZ    emptyclk, #:empty  

:skip                   OR      OUTA, CSPin             ' set CS pin high (inactive)
'=====[ END OF FAST SHIFT ]=============================                                    
                        

'-----[ DETERMINE MAX/MIN VALUE ]-----------------------
maxch1                  MIN     chmax, val_out          ' set val_max to whichever is highest 
minch1                  MAX     chmin, val_out          ' set val_min to whichever is lowest


{'-----[ READ COMMANDS ]---------------------------------
                        TJNZ    cmd, #check_cmd         ' check if command already is set
                        RDLONG  cmd, cmd_addr   WZ      ' read input command
              IF_Z      JMP     #end_mode
              
                        RDLONG  p1, pr1_addr            ' get applicable parameter1
                        RDLONG  p2, pr2_addr            ' get applicable parameter2
                        RDLONG  sectime, wd_addr        ' get applicable watchdog timer limit
                        RDLONG  chl, chl_addr           ' get applicable channel
                        
                        WRLONG  zero, cmd_addr          ' clear input command value
                        

'-----[ EXCECUTE COMMANDS ]-----------------------------
check_cmd
                        CMP     cmd, #1         WZ
              IF_Z      JMP     #set_thresh
                        CMP     cmd, #2         WZ
              IF_Z      JMP     #reset_maxmin
                        CMP     cmd, #3         WZ   
              IF_Z      JMP     #reset_max
                        CMP     cmd, #4         WZ
              IF_Z      JMP     #reset_min
                        CMP     cmd, #5        WZ
              IF_Z      JMP     #standby

                        CMP     chl, curchl     WZ      ' if current channel does not match command channel skip the rest
              IF_NZ     JMP     #no_mode 
              
                        CMP     cmd, #6         WZ  
              IF_Z      JMP     #wait_high
                        CMP     cmd, #7         WZ  
              IF_Z      JMP     #wait_low
                        CMP     cmd, #8         WZ   
              IF_Z      JMP     #det_freq
                        CMP     cmd, #9         WZ   
              IF_Z      JMP     #avg_samp
                        CMP     cmd, #10        WZ   
              IF_Z      JMP     #avg_time              

no_mode
                        CMP     cmd, negone     WZ
              IF_NZ     JMP     #end_mode
                        WRLONG  zero, cmd_addr          ' clear input command value
                        MOV     cmd, #0
                        WRLONG  negone, done_addr }      

'-----[ READ COMMANDS ]---------------------------------
                        TJNZ    cmd, #check_cmd         ' check if command already is set
                        RDLONG  cmd, cmd_addr   WZ      ' read input command
              IF_Z      JMP     #end_mode

                        RDLONG  p1, pr1_addr            ' get applicable parameter1
                        MOVS    jchang, #cmdtable-1     ' prep jump-to
                        ADD     jchang, cmd             ' set jump-to
                        RDLONG  p2, pr2_addr            ' get applicable parameter2
                        RDLONG  sectime, wd_addr        ' get applicable watchdog timer limit
                        RDLONG  chl, chl_addr           ' get applicable channel
                        
                        WRLONG  zero, cmd_addr          ' clear input command value


'-----[ CLEAR/IGNORE STANDBY_DISABLE ]------------------
                        CMP     cmd, negone     WZ
              IF_NZ     JMP     #check_cmd
                        WRLONG  zero, cmd_addr          ' clear input command value
                        MOV     cmd, #0
                        WRLONG  negone, done_addr
                        JMP     #end_mode

'-----[ EXCECUTE COMMANDS ]-----------------------------
check_cmd
                        CMP     cmd, #6         WZ, WC  ' check if command is channel specific            
              IF_B      JMP     #jchang     
                        CMP     chl, curchl     WZ      ' if current channel does not match command channel skip
              IF_NZ     JMP     #end_mode 
jchang                  JMP     #0-0                    ' set when cmd is read

cmdtable                JMP     #set_thresh             ' cmd 1 
                        JMP     #reset_maxmin           ' cmd 2 
                        JMP     #reset_max              ' cmd 3 
                        JMP     #reset_min              ' cmd 4 
                        JMP     #standby                ' cmd 5
                                                                
                        JMP     #wait_high              ' cmd 6 
                        JMP     #wait_low               ' cmd 7 
                        JMP     #det_freq               ' cmd 8 
                        JMP     #avg_samp               ' cmd 9 
                        JMP     #avg_time               ' cmd 10

end_mode                                                    

'-----[ END OF LOOP ]-----------------------------------
                        WRLONG  val_out, chval_addr     ' put current value in channel's value
                        ADD     curchl, #1              ' move current channel one position
                        CMP     val_out, chlow  WZ, WC
              IF_BE     WRLONG  zero, state_addr
                        ADD     val2, valplus1          ' add one channel to value
                        CMP     val_out, chhigh WZ, WC
              IF_A      WRLONG  negone, state_addr
                        ADD     state_addr, #4          ' move one long
                        ADD     chval_addr, #4          ' move one long
maxch2                  WRLONG  chmax, max_addr         ' max voltage over the second-long sample
                        ADD     max_addr, #4            ' move one long
                        ADD     maxch1, dplus1          ' move one destination
minch2                  WRLONG  chmin, min_addr         ' min voltage over the second-long sample
                        ADD     min_addr, #4            ' move one long
                        ADD     minch1, dplus1          ' move one destination
                        ADD     maxch2, dplus1          ' move one destination
                        ADD     minch2, dplus1          ' move one destination
                        ADD     roll, #4 

                        CMP     curchl, chs     WZ, WC  ' if it hasn't exceded the number of channels to be scanned
              IF_B      JMP     #mainloop

                        MOV     curchl, #0              ' set current channel to 0
                        MOV     val2, mval              ' add one channel to value
                        SUB     state_addr, roll         ' move back eight longs 
                        SUB     chval_addr, roll         ' move back eight longs
                        SUB     max_addr, roll           ' move back eight longs
                        SUB     min_addr, roll           ' move back eight longs
                        MOVD    maxch1, #chmax          ' move back to original destination
                        MOVD    maxch2, #chmax          ' move back to original destination
                        MOVD    minch1, #chmin          ' move back to original destination
                        MOVD    minch2, #chmin          ' move back to original destination  
                        MOV     roll, #0
                        JMP     #mainloop               ' do it again!



              
'=====[ SUBROUTNIES ]===================================
                        
'-----[ SET ALL CHANNELS' THRESHOLD ]-------------------
set_thresh
                        MINS    p1, #0                  ' make sure low value is not below 0
                        SUB     adcmax, #1              ' reduce max by one so "high" is possible
                        MAXS    p2, adcmax              ' make sure high value is not above max ADC value
                        ADD     adcmax, #1              ' return adcmax back to original location

                        CMP     p1, p2          WZ, WC  ' make sure low is not above high
              IF_BE     JMP     #:skip
                        MOV     p3, p1
                        MOV     p1, p2
                        MOV     p2, p3

:skip                   MOV     chlow, p1               ' set low
                        MOV     chhigh, p2              ' set high

                        MOV     cmd, #0
                        JMP     #end_mode

                        
'-----[ RESET ALL MAX/MINS ]----------------------------
reset_maxmin
                        MOVD    :setmax, #chmax         ' clear any previous movement  
                        MOVD    :setmin, #chmin         ' clear any previous movement
                        MOV     idx, #8                 ' repeat for all 8 locations
:setmax                 MOV     chmax, #0               ' clear max in current address
:setmin                 MOV     chmin, adcmax           ' clear min in current address
                        ADD     :setmax, dplus1         ' move up one address
                        ADD     :setmin, dplus1         ' move up one address
                        DJNZ    idx, #:setmax



                        {MOVD    :setmax, #chmax         ' clear any previous movement  
                        MOV     idx, #8                 ' repeat for all 8 locations
:setmax                 MOV     chmax, #0               ' clear max in current address
                        ADD     :setmax, dplus1         ' move up one address
                        DJNZ    idx, #:setmax

                        MOVD    :setmin, #chmin         ' clear any previous movement
                        MOV     idx, #8                 ' repeat for all 8 locations
:setmin                 MOV     chmin, adcmax           ' clear min in current address
                        ADD     :setmin, dplus1         ' move up one address
                        DJNZ    idx, #:setmin
                        }
                        MOV     cmd, #0
                        JMP     #end_mode

                        
'-----[ RESET CHANNEL'S MAX ]---------------------------
reset_max
                        MOV     p1, #chmax              ' get address
                        ADD     p1, chl                 ' add channel count to it
                        MOVD    :setmax, p1             ' set destination
                        MOV     cmd, #0                 ' need one instruction between setting and using modified instruction
:setmax                 MOV     chmax, #0               ' clear max in current address

                        JMP     #end_mode

                        {MOVD    :setmax, #chmax         ' clear any previous movement
                        MOV     p1, chl                 ' get selected channel
                        SHL     p1, #9
                        ADD     :setmax, p1             ' move address to selected channel
                        MOV     cmd, #0                 ' need one instruction between setting and using modified instruction
:setmax                 MOV     chmax, #0               ' clear max in current address
  
                        JMP     #end_mode
                        }
                        
'-----[ RESET CHANNEL'S MIN ]---------------------------
reset_min
                        MOVD    :setmin, #chmin         ' clear any previous movement
                        MOV     p1, chl                 ' get selected channel
                        SHL     p1, #9
                        ADD     :setmin, p1             ' move address to selected channel
                        MOV     cmd, #0                 ' need one instruction between setting and using modified instruction
:setmin                 MOV     chmin, adcmax           ' clear min in current address

                        JMP     #end_mode

                        
'-----[ WAIT FOR CHANNEL HIGH ]-------------------------
wait_high
                        TJNZ    strt, #:arstarted       ' already started

                        CMP     p1, #0          WZ      ' if mode is not 0
              IF_NZ     RDLONG  p3, state_addr  WZ      ' if current state is -1 (high)
              IF_NZ     JMP     #:done                  ' say it is done
                                                                        
                        MOV     output, #0              ' default low output
                        MOV     idx, #0                 ' set index count to 0

                        MOV     strt, cnt               ' start timer
                        NEG     strt, strt              ' get negative (used in place of SUB later on)
:arstarted                        
                        CMP     val_out, chhigh WZ, WC
              IF_BE     JMP     #check_watchdog         ' if still low, check watchdog timer  
                        
:done                   MOV     output, negone          ' make output current value
                        JMP     #alldone                ' continue normal operation

                        
'-----[ WAIT FOR CHANNEL LOW ]--------------------------
wait_low
                        TJNZ    strt, #:arstarted       ' already started

                        TJZ     p1, #:skip              ' if mode is not 0
                        RDLONG  p3, state_addr  WZ      ' if current state is 0 (low)
              IF_Z      JMP     #:done                  ' say it is done
:skip                                                                          
                        MOV     output, negone          ' default high output
                        MOV     idx, #0                 ' set index count to 0

                        MOV     strt, cnt               ' start timer
                        NEG     strt, strt              ' get negative (used in place of SUB later on)
:arstarted                        
                        CMP     val_out, chlow  WZ, WC
              IF_A      JMP     #check_watchdog         ' if still low, check watchdog timer     
                        
:done                   MOV     output, #0              ' make output current value
                        JMP     #alldone                ' continue normal operation
                        

'-----[ DETERMINE FREQUENCY ]---------------------------
det_freq
                        TJNZ    strt, #:arstarted       ' already started
                                                                        
                        MOV     cumul, #0              
                        MOV     idx, #0                 
                        MOV     clkready, #0
                        MOV     track, #0
                        MOV     tmstrt, #0

                        MOV     freqcycls, p1           ' get exponent of times to double check frequency
                        MOV     cyclesshl, #1
                        SHL     cyclesshl, freqcycls    ' move exponent value to left
                        MOV     highhld, p2   
                        
                        MOV     strt, cnt               ' start timer
                        NEG     strt, strt              ' get negative (used in place of SUB later on)
:arstarted

                        CMP     val_out, chhigh WZ, WC  ' if current value is below or equal to "threshold value"  
              IF_BE     JMP     #vbelow

vabove
                        CMP     track, highhld  WZ, WC  ' if val_out has been above "threshold value" for this many times
              IF_AE     MOV     clkready, #1            ' set value to 1 so when val_out goes below "threshold value" we can clock a Hz
              IF_B      ADD     track, #1               
                        JMP     #check_watchdog

vbelow
                        MOV     track, #0               ' clear tracking value
                        CMP     val_out, chlow  WZ, WC
              IF_A      JMP     #check_watchdog

                        CMP     clkready, #0    WZ, WC
                        MOV     clkready, #0            ' reset clock ready value
              IF_BE     JMP     #check_watchdog
                        ADD     cumul, #1               ' add a clock to Hz value

                        CMP     cumul, cyclesshl WZ, WC
              IF_BE     JMP     #:again
                        MOV     p1, cnt                 ' stop timer
                        SUB     p1, tmstrt              ' get difference between timer start and end

                        'SHR     p1, freqcycls           ' simple "divide" method .. to get average period (clock speed divided by period == frequency)

                        ' Nifty way to round LSB when "dividing" the average:
                        SHL     p1, #1
                        SHR     p1, freqcycls
                        ADD     p1, #1
                        SHR     p1, #1
                {        TJZ     freqcycls, #:skip       ' skip if only one value was obtained...no averaging needed
                        SUB     freqcycls, #1           ' shift one less bit than needed
                        SHR     p1, freqcycls           ' "divide" to get average period (clock speed divided by period == frequency)
                        SHR     p1, #1          WC      ' put "half" bit in c
                        ADDX    p1, #0                  ' if "half" bit is set, round up
:skip   }
                        
                        MOV     output, p1                        
                        JMP     #alldone
:again
                        TJNZ    tmstrt, #check_watchdog
                               
                        MOV     tmstrt, cnt             ' start first clock cycle timer
                        JMP     #check_watchdog

                        
'-----[ COLLECT SUM OF VALUES TO AVERAGE ]--------------
avg_samp
                        TJNZ    strt, #:arstarted       ' already started

                        MOV     cumul, #0
                        MOV     idx, #0        

:arstarted                                               
                        ADD     cumul, val_out          ' add current value to existing output
                        ADD     strt, #1
                        CMP     strt, p1         WZ, WC ' if enough samples have been taken 
                        ADD     idx, #1
              IF_AE     MOV     output, cumul
              IF_AE     JMP     #alldone                ' then we are all done
                        JMP     #mainloop                        

              
'-----[ COLLECT SUM OF VALUES TO AVERAGE ]--------------
avg_time
                        TJNZ    strt, #:arstarted       ' already started

                        MOV     cumul, #0
                        MOV     idx, #0

                        MOV     strt, cnt               ' start timer
                        NEG     strt, strt              ' get negative (used in place of SUB later on)                             

:arstarted
                        ADD     cumul, val_out
                        ADD     idx, #1
                        
                        MOV     waitlen, cnt            ' get now
                        ADDS    waitlen, strt           ' difference of start and now
                        CMP     waitlen, sectime WZ, WC ' if less than watchdog...do another loop
                        
              IF_B      JMP     #mainloop               ' do it again!
                        MOV     output, cumul 
                        JMP     #alldone                         


'-----[ GO INTO STANDBY, WAIT FOR EXIT COMMAND ]--------
standby
                        MOV     FRQB, #0                ' zero FRQB to prevent pin toggling
                        MOV     waitlen, cnt
                        ADD     waitlen, p1
:wait                   RDLONG  cmd, cmd_addr   WZ      ' if no command yet
              IF_Z      WAITCNT waitlen, p1             ' wait for a time (longer the less power)
              IF_Z      JMP     #:wait                  ' look for command again

                        MOV     cmd, #0                 ' trick it into re-reading the info at the normal command read area (so it execults the command that pulled it out of standby)
                        TJZ     fs, #end_mode           ' if slow mode, skip setting of FRQB
                        MOV     FRQB, #1                ' if fast mode, re-retup FRQB
                        
                        JMP     #end_mode

                        
'-----[ WATCHDOG ]--------------------------------------
check_watchdog                        
                        ADD     idx, #1
                        TJZ     sectime, #mainloop      ' if watchdog is disabled...skip it
                        MOV     waitlen, cnt            ' get now
                        ADDS    waitlen, strt           ' difference of start and now
                        CMP     waitlen, sectime WZ, WC ' if below one second...do another loop
                        
              IF_B      JMP     #mainloop               ' do it again!             

alldone
                        WRLONG  output, out_addr        ' output value
                        MOV     strt, #0                ' clear any timer
                        WRLONG  idx, count_addr         ' number of loops to address
                        MOV     cmd, #0
                        WRLONG  negone, done_addr       ' tell method, PASM command is done
                        MOV     output, #0              ' if timed out, no output
                        JMP     #end_mode               ' move on to next channel
              

negone                  LONG    -1                      ' $FF_FF_FF_FF
zero                    LONG    0                       ' used for cog memory writes
dplus1                  LONG    1 << 9                  ' destination plus one value
nco                     LONG    %00100 << 26            ' numerically controlled oscillator counter setting                     

sval_8                  LONG    %11000 << 27            ' single-ended channel 0 output value (for 8/4 channel ADC)
dval_8                  LONG    %10000 << 27            ' differential channel 0 output value (for 8/4 channel ADC)  
valplus1_8              LONG    1 << 27                 ' add one channel (for 8/4 channel ADC)
sval_2                  LONG    %1101 << 28             ' single-ended channel 0 output value (for 2 channel ADC)
dval_2                  LONG    %1001 << 28             ' differential channel 0 output value (for 2 channel ADC)  
valplus1_2              LONG    1 << 29                 ' add one channel (for 2 channel ADC)

output                  LONG    0                       ' output value
clkready                LONG    0                       ' ready to add one to frequency ("high" criteria met)
strt                    LONG    0                       ' watchdog start time
roll                    LONG    0                       ' number of bytes to roll back (when looping back to channel 0)
curchl                  LONG    0                       ' current cycle's channel

sval                    RES                             ' single-ended channel 0 output value
dval                    RES                             ' differential channel 0 output value  
valplus1                RES                             ' add one channel
nullbits                RES                             ' null bits between output and input

DPin                    RES                             ' tx
DPin2                   RES                             ' tx
CPin                    RES                             ' clock
CPin2                   RES                             ' clock
CSPin                   RES                             ' cs (reset)
NPin                    RES                             ' rx

sectime                 RES                             ' watchdog period
waitlen                 RES                             ' tmp time
tmstrt                  RES                             ' start timer at first clock
emptyclk                RES                             ' number of empty clocks to excecute

out_addr                RES                             ' output address
max_addr                RES                             ' output address
min_addr                RES                             ' output address
done_addr               RES                             ' output address
count_addr              RES                             ' output address
state_addr              RES                             ' output address
chval_addr              RES                             ' output address           

cmd_addr                RES                             ' input address
chl_addr                RES                             ' input address
pr1_addr                RES                             ' input address
pr2_addr                RES                             ' input address
wd_addr                 RES                             ' input address

cmd                     RES                             ' command value
chl                     RES                             ' channel value  

cumul                   RES                             ' output value cumulator
track                   RES                             ' store number of times above "threshold value"
idx                     RES
adcmax                  RES                             ' maximum ADC value based on number of bits_s_in
chs                     RES                             ' number of channels to scan (1-8)
fs                      RES                             ' setting for runnnig fast or slow mode
adcchs                  RES                             ' track which ADC is being used (for different dataschemes)

Bits                    RES                             ' number of bits to shift out
bits_in                 RES                             ' number of value bits to shift in (10 or 12)
mval                    RES                             ' stored value for single/differential changes
val                     RES                             ' output value (channel number plus mval)
val2                    RES                             ' "backup" of val
val_out                 RES                             ' shifted in value                      

freqcycls               RES                             ' number of cycles to count for frequency
cyclesshl               RES                             ' number of shifts to act as a fast divider
highhld                 RES                             ' number of cycles to see as "high" before alowing a "low" value to count a Hz
bitssin                 RES                             ' number of value bits to shift in (10 or 12)
bitssin1                RES                             ' number of value bits to shift in minus 1 (9 or 11) 

p1                      RES                             ' address pointer (for value/pin/address setup) and parameter1
p2                      RES                             ' temperary value read from address and parameter2
p3                      RES                             ' tmp value storrage

chhigh                  RES                             ' all channels' threshold before considered "high"
chlow                   RES                             ' all channels' threshold before considered "low" 
chmax                   RES     8                       ' channel's maxinum value since last reset
chmin                   RES     8                       ' channel's minimum value since last reset

                        ' 15 longs free...(as of 8/4/11)
                        FIT

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