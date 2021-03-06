{

┌──────────────────────────────────────────────────────────┐
│       Bell 202 Soft Modem (1200 baud, half-duplex).      │
│(c) Copyright 2009 Philip C. Pilgrim (propeller@phipi.com)│
│            See end of file for terms of use.             │
└──────────────────────────────────────────────────────────┘
This object performs the transmit and receive functions of a Bell 202-style modem,
requiring minimal external circuitry. For a full description, download the
documentation PDF from the Parallax website: www.parallax.com.

Version History
───────────────

2009.02.18: Initial release

}

CON

  BUFSIZE       = 128           'Buffer size (must be a power of two no larger than 256).
  BUFMAX        = BUFSIZE - 1   'Maximum index into buffers.
  NONE          = $8000_0000    'Null value.
   
  LVL0          = 7             'Transmit levels.
  LVL1          = 8
  LVL2          = 9
  LVL3          = 10
  LVL4          = 11
  LVL5          = 12
  LVL6          = 13
  LVL7          = 14
  LVL8          = 15
  
  AUTOXR        = $10           'Mode bit to signal automatic transmit/receive switching.

  STSPAR        = %00001000     'Status bit set to indicate a parameter is available to change.
  STSAUT        = %00000100     'Status bit signalling automatic transmit/receive switching in effect.
  STSXMT        = %00000010     'Status bit set when transmitting.
  STSRCV        = %00000001     'Status bit set when receiving.

  HYST          = %00000000     'ORed to status when STSPAR is set to indicate parameter to change.
  SLICE         = %00010000
  NOISE         = %00110000  

VAR

  byte  started, xbuf[BUFSIZE], xenq, xdeq, rbuf[BUFSIZE], renq, rdeq, status
  long  sig, paramvalue

OBJ

  u : "umath"                   'Unsigned and double-precision math routines.

PUB start_simple(rcvpin, xmtpin, pttpin, mode)

{ Start the modem software using the simplest hardware setup, as shown below:

                  Vdd
                                     xmtpin  ─┳────┳─ Audio Out
                                                         
    Audio Inp ───╋── rcvpin                       │
                                     pttpin  ──────                    
                                                       │
                                                        
  NOTE: All resistors are 2.2K; all caps, 0.1uF; transistor, 2N3904 (or nearly any general-purpose NPN).

  The mode argument can be any one of LVL0 through LVL8 (transmit level) boolean ored, optionally, with
  AUTOXR for automatic transmit/receive switching. If set to zero, LVL6 | AUTOXR is used as the default.                                                   
                                                        
}

  if (mode == 0)
    mode := AUTOXR | LVL6
  rcvpin := (rcvpin => 0) & |<rcvpin 
  xmtpin := (xmtpin => 0) & |<xmtpin 
  pttpin := (pttpin => 0) & |<pttpin
  return start_explicit(rcvpin, 0, 0, pttpin, xmtpin, pttpin, 0, 0, pttpin, mode)

PUB start_bp(mode)

{ Start the modem using the Propeller Backpack.

  The mode argument can be any one of LVL0 through LVL8 (transmit level) boolean ored, optionally, with
  AUTOXR for automatic transmit/receive switching. If set to zero, LVL6 | AUTOXR is used as the default.                                                   
                                                        
}

  if (mode == 0)
    mode := AUTOXR | LVL6
  return start_explicit(|<16, |<12, |<13, |<17 + |<15 + |<23, |<20, |<23, |<22, 0, |<23, mode)  

PUB start_explicit(rcvmask, rfbmask, rhimask, rlomask, xmtmask, xhimask, xlomask, shimask, slomask, mode)

{ The following schematic illustrates the meaning of the various pin options.
  Not all hardware will have all these pins, and some "pins" may be
  hard-wired to Vdd or Vss. The "mask" arguments are bitmasks comprising the
  effective pins. For example, if xmtpin is pin 5, then xmtmask would equal
  |<5.

  The "lo" masks include pins that must be pulled low during the affected
  operations. In the case of filter capacitors, it is recommended that these
  remain low all the time, which can be accommodated by including them in ALL
  the "lo" masks. The "hi" masks include pins that must be pulled high during the
  affected operations. In the case of voltage dividers, switching pins on and
  off in this fashion can save power when the affected circuit is not in use.
  The input voltage divider is particularly important, since it biases the AC
  input to the Propeller's logic threshold level.
  
  The rcvpin (input) and rfbpin (feedback) comprise a sigma-delta ADC.
  
  The xmtpin is a DUTY mode counter output that is lowpass filtered for audio.
  
                  ┌────────── rhipins     xhipins ─────┐
                  │    ┌───── rhipins                    
                     ┌─ rfbpin      xmtpin  ─┳─╋──┳─ Audio Out
    Audio Inp ──╋──╋─┻─── rcvpin                    │
                                       xlopins ───┘ │    2.2K
                  │    └───── rlopins     xlopins ─────┘   │
                  └────────── rlopins     xhipins ────────
                                                             

  The mode argument can be any one of LVL0 through LVL8 (transmit level) boolean ored, optionally, with
  AUTOXR for automatic transmit/receive switching. If set to zero, LVL6 | AUTOXR is used as the default.                                                   
                                                        
}

  stop
  ctra0 := (%00110 << 26 | >|xmtmask - 1) & (xmtmask <> 0)
  if (rfbmask and rcvmask)
    ctrb0 := %01001 << 26 | (>|rfbmask - 1) << 9 | >|rcvmask - 1
  elseif (rcvmask)
    ctrb0 := %01000 << 26 | >|rcvmask - 1
  else
    ctrb0~
  xdira := xmtmask | xhimask | xlomask
  xouta := xhimask
  rdira := rfbmask | rhimask | rlomask
  routa := rhimask
  sdira := shimask | slomask
  souta := shimask
    
  xbufaddr := @xbuf
  xenqaddr := @xenq
  xdeqaddr := @xdeq
  stataddr := @status
  rbufaddr := @rbuf
  renqaddr := @renq
  rdeqaddr := @rdeq
  parmaddr := @paramvalue
  sigmonaddr := @sig
  
  frq1200 := 268_520_632
  frq2200 := 492_287_824
  delay := u.multdiv(4167, clkfreq, 80_000_000)
  outlevel := mode & 15
  status := (mode & AUTOXR > 0) & STSAUT

  standby
  return started := cognew(@modem, 0) + 1

PUB stop

{ Stop the modem software and free its cog. }

  if (started)
    standby
    cogstop(started - 1)
    started~

PUB outstr(stringaddr) | char

{ Send a string whose address is given by stringaddr. }

  repeat while char := byte[stringaddr++]
    if (out(char) == false)
      return false
  return true

PUB out(char) | xmtstatus

{ Send a single character. }

  xmtstatus := status & constant(STSAUT | STSXMT)
  if (xmtstatus == STSAUT)
    transmit
  repeat while ((xenq - xdeq) & BUFMAX == BUFMAX)
    if (xmtstatus == 0)
      return false
  xbuf[xenq] := char
  xenq := (xenq + 1) & BUFMAX
  return true

PUB waitstr(straddr, maxtime) : success | len, chr, ptr, time0

  { Wait for an incoming string that matches the string whose address is given by
    straddr, waiting a maximum of maxtime milliseconds (not to exceed a full cnt cycle).
    If maxtime == 0, the timeout is ignored. This method returns true for success
    and false for a timeout. This method blocks until it completes, times out, or
    the input buffer is empty and the modem is transmitting or in standby. }

  ptr~
  len := strsize(straddr)
  time0 := cnt
  success~
  repeat
    if ((chr := inp0) <> NONE)
      ptr := (chr == byte[straddr][ptr]) & (ptr + 1)
    elseif (status & STSRCV == 0)
      abort
  until (success := ptr => len) or maxtime and u.gt((cnt - time0) / (clkfreq / 1000), maxtime)

PUB inpstr(straddr, terminator, maxlen, maxtime) | chr, ptr, time0

{ Receive a string whose address is given by straddr, with a maximum length of maxlen,
  terminated by the character given by terminator, and waiting a maximum of maxtime milliseconds
  (not to exceed a full cnt cycle). If maxtime == 0, the timeout is ignored. If maxtime > 0
  and the routine times out, the characters up to that point will be returned. The array
  pointed to by straddr must be at least maxlen + 1 bytes long. This method blocks until
  it completes, times out, or the input buffer is empty and the modem is transmitting or in
  standby. }

  ptr~
  time0 := cnt
  if (maxlen)
    repeat
      if ((chr := inp0) <> NONE)
        byte[straddr][ptr++] := chr
      elseif (status & STSRCV == 0)
        abort
    until ptr == maxlen or chr == terminator or maxtime and u.gt((cnt - time0) / (clkfreq / 1000), maxtime)
  byte[straddr][ptr]~
  return strsize(straddr)
     
PUB inp : char

{ Receive a single character. This routine blocks until a character has been received. } 

  repeat until (char := inp0) <> NONE or status & constant(STSAUT | STSRCV) == 0

PUB inp0 : char

{ Receive a single character. Return NONE if no character is present in buffer. }

  if (status & constant(STSAUT | STSRCV) == STSAUT)
    receive
  if (renq == rdeq)
    char := NONE
  else
    char := rbuf[rdeq]
    rdeq := (rdeq + 1) & BUFMAX
     
PUB outchars

{ Return the number of characters in output buffer awaiting transmission. }

  return (xenq - xdeq) & BUFMAX

PUB inpchars

{ Return the number of characters waiting in input buffer. }

  return (renq - rdeq) & BUFMAX
    
PUB transmit | save

{ Change mode to transmit, enable outputs, and send 1/2 second of marking to open receiver's squelch. }

  if (status & STSXMT)
    return
  save := xenq
  xenq := xdeq
  status := status & STSAUT | STSXMT
  waitcnt(cnt + clkfreq >> 1)
  xenq := save

PUB receive

{ Wait until all characters in transmit buffer have been sent (if transmitting) then switch to receive. }

  if (status & STSXMT)
    repeat while outchars
    waitcnt(cnt + clkfreq >> 2)
  status := status & STSAUT | STSRCV

PUB standby

{ Wait until all characters in transmit buffer have been sent (if transmitting) then switch to standby. }

  if (status & STSXMT)
    repeat while outchars
    waitcnt(cnt + clkfreq >> 2)
  status &= STSAUT

PUB set(param, value)

{ Set modem's hysteresis, bit slice, or noise threshold parameter.
  param should be one of "H" or HYST, "S" or SLICE, or "N" or NOISE.
  value is the new value of the chosen parameter. }

  if (param == "H")
    param := HYST
  elseif (param == "S")
    param := SLICE
  elseif (param == "N")
    param := NOISE
  if (param == HYST or param == SLICE or param == NOISE)
    paramvalue := value
    status |= param | STSPAR
    repeat while (status & STSPAR)
    return true
  else
    return false
        
PUB signal

{ Return latest instantaneous signal stats in the form:

  %zLLLLLLLLLLL_oHHHHHHHHHHH_nnnnnnnn, where

  z and o (bits 31 and 19) are coded as follows:

  0     0 : Signal is below noise threshold.
  0     1 : Signal is marking (1).
  1     0 : Signal is spacing (0).
  1     1 : Signal is in hysteresis band between mark and space.

  LLLLLLLLLLL (bits 30 .. 20) sum-of-squares of 1200 Hz demodulator outputs. 
  HHHHHHHHHHH (bits 18 ..  8) sum-of-squares of 2200 Hz demodulator outputs.
  nnnnnnnn    (bits  7 ..  0) -16 (pure 0) to 16 (pure 1) level count for latest bit (2's complement).

} 

  return sig

DAT

              org       0
modem         mov       ctra,ctra0              'Initialize ctra for transmit.
              mov       ctrb,ctrb0              'Initialize ctrb for receive.
              mov       frqb,#1                 'Sigma-delta count-up is 1.
              movd      :zaplp,#i1200buf        'Clear the I and Q buffers.
              mov       ctr,#64

:zaplp        mov       0-0,#0
              add       :zaplp,_0x0200
              djnz      ctr,#:zaplp
              
              mov       time,cnt                'Setup first phase delay.
              add       time,delay

'=======[Standby, waiting for something to do]=================================

standingby    and       dira,sdira              'Set dira and outa to standby settings.
              mov       outa,souta
              mov       dira,sdira

:stbylp       call      #getstat                'Check status.
              test      acc,#STSRCV wz          'Are we now receiving?
        if_nz jmp       #receiver               '  Yes: Go do receive.
        
              test      acc,#STSXMT wz          'If not, are we transmitting?
        if_nz jmp       #transmitter            '  Yes: Go do transmit.

              waitcnt   time,delay              'If not, just bide our time.
              jmp       #:stbylp                'Go back and check again.       

'=======[Demodulator]==========================================================

receiver      and       dira,rdira              'Configure pins for input.
              mov       outa,routa
              mov       dira,rdira

rcvlp         call      #getstat                'Are we still receiving?
              test      acc,#STSRCV wz
        if_z  jmp       #standingby             '  No:   Go back to standby.

              call      #pollinp                '  Yes:  Detecting a legitimate low?
   if_nz_or_c jmp       #rcvlp                  '          No:  Try again.

              call      #getbit15               'Take 15 more samples.
   if_nz_or_c jmp       #rcvlp                  'Noise blip unless a supermajority are low.

              mov       bitcnt,#8               'Detected start bit, so start receiving 8 more bits.
              mov       data,#0                 'Clear result.
:bitlp        call      #getbit                 'Get the next bit.
        if_c  jmp       #rcvlp                  'If not a valid bit, then forget it and start over.
              shr       data,#1                 'Valid bit, so shift it into result.
              muxnz     data,#$80
              djnz      bitcnt,#:bitlp          'Back for next bit.

              call      #getbit                 'Get stop bit.
    if_z_or_c jmp       #rcvlp                  'If non-zero or a bad bit, forget it and start over.

              rdbyte    deq,rdeqaddr            'Good byte. Is there room in receive buffer?
              rdbyte    enq,renqaddr
              sub       deq,enq
              and       deq,#BUFMAX
              cmp       deq,#1 wz
        if_z  jmp       #rcvlp                  '  No:  Can't buffer, so forget it and start over.
              add       enq,rbufaddr            '  Yes: Put byte in buffer.
              wrbyte    data,enq
              sub       enq,rbufaddr
              add       enq,#1
              and       enq,#BUFMAX
              wrbyte    enq,renqaddr
              jmp       #rcvlp                  '       And back for another.

'-------[Input one bit.]-------------------------------------------------------

getbit        mov       samplecnt,#16           'Setup tp sample level 16 times.
              jmp       #dogetbit

getbit15      mov       samplecnt,#15           'Finish sampling start bit (15 times).

dogetbit      mov       highsamples,#0          'Initialize high sample count.

:getbitlp     call      #pollinp                'Sample the level. Is it a legitimate bit?
        if_c  jmp       getbit_ret              '  No:  Just return.
        if_nz sub       highsamples,#1          '  Yes: Add to high sample count if a one.
        if_z  add       highsamples,#1          '       Subtract from high sample count if a zero.
              djnz      samplecnt,#:getbitlp    '  Back for another sample.

              xor       sigmon,highsamples      'Insert highsamples, bits 7..0, into sigmon, bits 7..0.
              andn      sigmon,#$ff
              xor       sigmon,highsamples

              test      highsamples,_0x8000_0000 wz     'Set Z according to sign of high sample count.
              abs       highsamples,highsamples 'Find the absolute magnitude of count. (16 is a perfect score.)
              cmp       highsamples,#6 wc       'Is it at least 6 (i.e. 11:5)? Set carry if not.
getbit15_ret
getbit_ret    ret                               'Return to caller.

'-------[Sample and demodulate the input line: 1/16th of one bit.]-------------
                 
pollinp       waitcnt   time,delay              'Wait for the 1/(1200 * 16) second interval.
              mov       adc,phsb                'Read the accumulated signal amplitude.
              sub       adc,padc                'Subtract the previous value.
              add       padc,adc                'Add the difference back to prev (i.e. prev := new).
              add       phs1200,frq1200         'Advance the 1200 Hz virtual local oscillator.
              add       phs2200,frq2200         'Advance the 2200 Hz virtual local oscillator.
              
              mov       acc,phs1200             'Find the sine of the 1200 Hz (I) local oscillator.
              call      #sine
              mov       accx,adc                'Multiply it by the signal amplitude.
              call      #smult16
              mov       ctr,#i1200buf           'Point to current entry in FIFO (revolving) buffer.
              add       ctr,iqindex
              movs      :i1200sub,ctr           'Setup for sub and mov indirect access.
              movd      :i1200mov,ctr
              add       i1200sum,acc            'Add current amplitude to running sum.
:i1200sub     sub       i1200sum,0-0            'Subtract value from 16 samples back.
:i1200mov     mov       0-0,acc                 'Save current sample in buffer.
                
              mov       acc,phs1200             'Same for 1200 Hz (Q) local oscillator.
              call      #cosine
              mov       accx,adc
              call      #smult16
              mov       ctr,#q1200buf
              add       ctr,iqindex
              movs      :q1200sub,ctr
              movd      :q1200mov,ctr
              add       q1200sum,acc
:q1200sub     sub       q1200sum,0-0
:q1200mov     mov       0-0,acc                
              
              mov       acc,phs2200             'Same for 2200 Hz (I) local oscillator.
              call      #sine
              mov       accx,adc
              call      #smult16
              mov       ctr,#i2200buf
              add       ctr,iqindex
              movs      :i2200sub,ctr
              movd      :i2200mov,ctr
              add       i2200sum,acc
:i2200sub     sub       i2200sum,0-0
:i2200mov     mov       0-0,acc
                
              mov       acc,phs2200             'Same for 2200 Hz (Q) local oscillator.
              call      #cosine
              mov       accx,adc
              call      #smult16
              mov       ctr,#q2200buf
              add       ctr,iqindex
              movs      :q2200sub,ctr
              movd      :q2200mov,ctr
              add       q2200sum,acc
:q2200sub     sub       q2200sum,0-0
:q2200mov     mov       0-0,acc

              add       iqindex,#1              'Increment FIFO index and wrap around from 15 to 0.
              and       iqindex,#$0f

              mov       acc,ssq1200             'Compute moving averages:
              shr       acc,#2                  '  ssq1200 = ssq1200 * 3/4 + i1200sum**2 + q1200sum**2
              sub       ssq1200,acc
              mov       acc,i1200sum
              sar       acc,#1
              call      #square32
              add       ssq1200,acc
              mov       acc,q1200sum
              sar       acc,#1
              call      #square32
              add       ssq1200,acc
                              
              mov       acc,ssq2200             '  ssq2200 = ssq2200 * 3/4 + i2200sum**2 + q2200sum**2
              shr       acc,#2
              sub       ssq2200,acc              
              mov       acc,i2200sum
              sar       acc,#1
              call      #square32
              add       ssq2200,acc
              mov       acc,q2200sum
              sar       acc,#1
              call      #square32
              add       ssq2200,acc

              and       sigmon,#$ff             'Put ssq data into sigmon for signal stats.
              mov       acc,ssq1200
              shr       acc,#20
              shl       acc,#20
              or        sigmon,acc
              mov       acc,ssq2200
              shr       acc,#20
              shl       acc,#8
              or        sigmon,acc
              or        sigmon,_0x8008_0000

              mov       acc,ssq1200             'Compare ssq1200 with ssq2200,
              sub       acc,ssq2200
              sub       acc,slicethld           '   biased by slicethld constant.
              cmps      acc,hysteresis wc       'Is ssq1200 - ssq2200 + slicethld => hysteresis?
        if_nc andn      cogflags,#INPBIT        '  Yes: Sample is a 0.
        if_nc andn      sigmon,_0x0008_0000     '       Clear the "detected 1" bit in sigmon.
              neg       acc,acc                 'Now compare ssq2200 - ssq1200 - slicethld
              cmps      acc,hysteresis wc       'to hysteresis. Is it bigger?
        if_nc or        cogflags,#INPBIT        '  Yes: Sample is a 1.
        if_nc andn      sigmon,_0x8000_0000     '       Clear the "detected 0" bit in sigmon.
              test      cogflags,#INPBIT wz     'Set Z according to bit.
              mov       acc,ssq1200             'Check overall level against noise threshold.
              add       acc,ssq2200

              cmp       acc,noisethld wc        'Is total signal above the noise threshold? Set C if not.
        if_c  andn      sigmon,_0x8008_0000     '  No:  Clear both "detected 0" and "detected 1" bits in sigmon.
              wrlong    sigmon,sigmonaddr       'Write sigmon to the hub.
pollinp_ret   ret              

'=======[Modulator]============================================================                                                

transmitter   and       dira,xdira              'Configure pins for output.
              mov       outa,xouta
              mov       dira,xdira

xmtlp         call      #getstat                'Are we still transmitting?
              and       acc,#STSXMT wz
        if_z  jmp       #standingby             '  No: Go back to standby.
                      
              rdbyte    enq,xenqaddr            'Is enqueue index <> deque index?
              rdbyte    deq,xdeqaddr
              cmp       enq,deq wz
        if_nz jmp       #:dodeq                 '  Yes: There's data to send; go dequeue it.

              call      #send1                  '  No:  Send a 1 bit (mark).
              jmp       #xmtlp                 '       Try again.

:dodeq        mov       acc,xbufaddr            'Point to next byte to send.
              add       acc,deq
              rdbyte    data,acc                'Get it.
              add       deq,#1                  'Increment dequeue index.
              and       deq,#BUFMAX             'Point back to beginning if past end.
              wrbyte    deq,xdeqaddr            'Write dequeue pointer back to xdeq.

              or        data,_0x0300              'OR in the stop bit.
              shl       data,#1                 'Shift left to create the start bit.
              mov       bitcnt,#11              'Bit count to send is 10.

:bitloop      shr       data,#1 wc              'Shift next bit into carry.
              call      #sendc
:xnext        djnz      bitcnt,#:bitloop        'Go back for another bit.

              jmp       #xmtlp

'-------[Output bit routines]--------------------------------------------------

sendc   if_nc jmp       #send0                  'Send a bit based on carry flag.

send1         mov       inc,frq2200             'Send a 1-bit.
              call      #sendbit
              jmp       send1_ret

send0         mov       inc,frq1200             'Send a 0-bit.
              call      #sendbit
send0_ret
send1_ret
sendc_ret     ret

sendbit       mov       phscnt,#16              'One bit is 16 times through.

:loop         add       phase,inc               'Increment phase
              mov       acc,phase               'Copy phase to scratch register.
              call      #sine
                                                  
:putfrqa      shl       acc,outlevel            'Scale it for proper audio level.
              add       acc,_0x8000_0000        'Add "zero" level.
              waitcnt   time,delay              'Wait for it. Waaaiiit for it...
              mov       padc,phsb               'Just to keep receiver ADC in sync.
              mov       frqa,acc                'Okay, write the level to frqa for DUTY output.
              djnz      phscnt,#:loop           'Back for another phase piece.

sendbit_ret   ret

'-------[Read current status and set params]-----------------------------------

getstat       rdbyte    acc,stataddr            'Read the status byte from the hub.
              test      acc,#STSPAR wz          'Is there a parameter that needs setting?
        if_z  jmp       getstat_ret             '  No:  Just return.

              test      acc,#NOISE wz,wc        '  Yes: Read the appropriate parameter value.
  if_z_and_nc rdlong    hysteresis,parmaddr     '         
  if_nz_and_c rdlong    slicethld,parmaddr
 if_nz_and_nc rdlong    noisethld,parmaddr
              andn      acc,#NOISE|STSPAR       '       Clear flag to alert hub.
              wrbyte    acc,stataddr
 
getstat_ret   ret

'-------[Cosine and Sine lookup routines]--------------------------------------  

'On entry, acc contains the angle: 0 to $ffff_ffff (unsigned).
'On exit, acc contains the sine or cosine: -$ffff to $ffff.  

cosine        add       acc,_0x4000_0000        'Add 90 degrees for cosine.

sine          test      acc,_0x4000_0000 wz     'nz = quadrants II or IV.
              test      acc,_0x8000_0000 wc     'c = quadrants III or IV.
              shr       acc,#18                 'Setup to index into ROM sine table.
              negnz     acc,acc                 'Negate offset if quadrants II or IV.
              or        acc,sine_table          'OR offset to index.
              rdword    acc,acc                 'Read the sine value into acc.
              negc      acc,acc                 'Negate if quadrants III or IV.
sine_ret
cosine_ret    ret                               'Return value (-65535 - 65535) in acc.

'-------[Multiply]-------------------------------------------------------------

'Multiply signed acc[15..0] by itself.

square16      mov       accx,acc
              jmp       #smult16

'Multiply signed acc[31..16] by itself.    

square32      mov       accx,acc

'Multiply signed acc[31..16] by accx[31..16].
              
smult32       sar       acc,#16
              sar       accx,#16

'Multiply signed acc[15..0] by accx[15..0].

smult16       xor       acc,accx
              test      acc,_0x8000_0000 wz
              xor       acc,accx              
              call      #absmult
        if_nz neg       acc,acc
smult16_ret              
smult32_ret
square16_ret
square32_ret  ret

'Multiply (||acc)[15..0] by (||accx)[15..0].

absmult       test      acc,_0x8000_0000 wc
        if_c  neg       acc,acc
              test      accx,_0x8000_0000 wc
        if_c  neg       accx,accx

'Multiply unsigned acc[15..0] by unsigned accx[15..0].

mult          and       acc,_0xffff
              mov       ctr,#16
              shl       accx,#16
              shr       acc,#1 wc
              
:mullp  if_c  add       acc,accx wc
              rcr       acc,#1 wc
              djnz      ctr,#:mullp

absmult_ret
mult_ret      ret

'=======[Constants]============================================================

sine_table    long      $e000                   'Beginning of sine table in ROM.
_0x0200       long      $0200
_0x0300       long      $0300
_0x8000       long      $8000
_0xffff       long      $ffff
_0x8000_0000  long      $8000_0000
_0x4000_0000  long      $4000_0000
_0x8008_0000  long      $8008_0000
_0x0008_0000  long      $0008_0000

'=======[Variables]============================================================

phs1200       long      0                       'Current phase of 1200 Hz local oscillator.
phs2200       long      0                       'Current phase of 2200 Hz local oscillator.
iqindex       long      0                       'Index into saved I and Q queue.
i1200sum      long      0                       'Sums of I and Q mixer outputs.
q1200sum      long      0
i2200sum      long      0
q2200sum      long      0

'-------[Runtime-settable parameters]------------------------------------------

hysteresis    long      $0200_0000              'Width of hysteresis band for mark/space transitions.
slicethld     long      $0250_0000              'Offset between normal 2200Hz and 1200Hz sum-of-squares.
noisethld     long      $1000_0000              'Threshold below which no bits are detected.

'-------[Initial values set before COGNEW to this code]------------------------

ctra0         long      0-0                     'Setup value for ctra.
ctrb0         long      0-0                     'Setup value for ctrb.
rdira         long      0-0                     'Value of dira for receiving.
routa         long      0-0                     'Value of outa for receiving.
xdira         long      0-0                     'Value of dira for transmitting.
xouta         long      0-0                     'Value of outa for transmitting.
sdira         long      0-0                     'Value of dira for standby.
souta         long      0-0                     'Value of outa for standby.                     
xbufaddr      long      0-0                     'Beginning address of transmit buffer.
xenqaddr      long      0-0                     'Address of transmit dequeue pointer.
xdeqaddr      long      0-0                     'Address of transmit enqueue pointer.
stataddr      long      0-0                     'Address of modem status byte.
rbufaddr      long      0-0                     'Beginning address of receive buffer.
renqaddr      long      0-0                     'Address of receive enqueue pointer.
rdeqaddr      long      0-0                     'Address of receive dequeue pointer.
delay         long      0-0                     'Correct delay for 1 / 1200 / 64 sec.
frq1200       long      0-0                     'Correct phase increment for 1200 Hz.
frq2200       long      0-0                     'Correct phase increment for 2200 Hz.
outlevel      long      0-0                     'Output audio level to transmitter.
sigmonaddr    long      0-0                     'Address of signal monitor long.
parmaddr      long      0-0                     'Address of incoming parameter to be set.
sigmon        long      0-0                     'Instantaneous value of signal monitor.

'-------[Scratch registers]----------------------------------------------------

acc           res       1                       'Accumulator.
accx          res       1                       'Accumulator extension.
ctr           res       1                       'Counter.
adc           res       1                       'ADC value.
padc          res       1                       'Previous ADC value.

enq           res       1                       'Scratch enqueue index.
deq           res       1                       'Scratch dequeue index.
data          res       1                       'Data value to send.   
time          res       1                       'Next time to write frqa.
phase         res       1                       'Audio phase register.
phscnt        res       1                       'Counter for audio phase increments.
bitcnt        res       1                       'Bit counter.
inc           res       1                       'Amount to increment audio phase at each step.

i1200buf      res       16                      'Buffers for I and Q mixer outputs.
q1200buf      res       16
i2200buf      res       16
q2200buf      res       16
ssq1200       res       1                       'Sum-of-squares values for 1200 Hz. and 2200 Hz. demodulators.
ssq2200       res       1
samplecnt     res       1                       'Counter for intra-bit mixer sampling.
highsamples   res       1                       'Number of high samples in bit - number of low samples.
cogflags      res       1                       'Locally-persistent flags.

CON

  INPBIT        = 1             'Bit position in cogflags.

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