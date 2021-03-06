'******************************************************************************
' Serial Driver for the C Function Library in Spin
' Author: Dave Hein
' Copyright (c) 2010
' See end of file for terms of use.
'******************************************************************************
'******************************************************************************
' Revison History
' v1.0 - 4/2/2010 First official release
'******************************************************************************
{{
  This is a modified version of Ghip Gracey's Full-Duplex Serial Driver.  This
  serial driver has the following new features:
 
  - Multiple serial ports may be started from any object or cog
  - Any serial port is accessable from any object or cog using a device handle
  - Transmit and receiver buffers can be different sizes
  - Buffer sizes are defined by calling parameters
  - Mode bit 4 enables the use of a lock to make the transmit multi-cog safe
 
  The original FullDuplexSerial routines are retained for compatibility.  A
  handle is maintained locally so that the caller does not have to provide the
  buffers or handle for the first serial port.
 
  The enhanced methods use a handle, which is a pointer to a memory buffer that
  contains the serial port's state information and transmit and receive buffers.
  The size of the memory buffer is equal to header_size + rxsize + txsize in
  bytes.  The buffer must be long aligned.  The transmit and receive buffer
  sizes must be a power of 2.  They can range anywhere from a value of 2 up to
  the size of the available memory.
}}
CON
' Data structure byte offsets
  ' long variables
  bit_ticks        =  0
  ' word variables
  rx_head          =  4
  rx_tail          =  6
  tx_head          =  8
  tx_tail          = 10
  rx_buffer        = 12
  tx_buffer        = 14
  rx_mask          = 16
  tx_mask          = 18
  ' byte variables
  cog              = 20
  lock             = 21
  rx_pin           = 22
  tx_pin           = 23
  rxtx_mode        = 24
  header_size      = 28

' Data structure storage for the default serial port  
DAT
  handle1     long 0
  data_struct long 0[(header_size+16+16)/4]

''
''*****************************************************************************
''Original FullDuplexSerial routines for compatibility
''*****************************************************************************
PUB start(rxpin, txpin, mode, baudrate)
'' Start serial driver - starts a cog
'' returns false if no cog available
''
'' mode bit 0 = invert rx
'' mode bit 1 = invert tx
'' mode bit 2 = open-drain/source tx
'' mode bit 3 = ignore tx echo on rx
'' mode bit 4 = use lock
  return start1(@data_struct, rxpin, txpin, mode, baudrate, 16, 16)

PUB stop
'' Stop serial driver - frees a cog
  if handle1
    stop1(handle1)
    handle1 := 0

PUB  rxflush
'' Flush receive buffer
  rxflush1(handle1)
  
PUB  rxcheck
'' Check if byte received (never waits)
'' returns -1 if no byte received, $00..$FF if byte
  return rxcheck1(handle1)
  
PUB  rxtime(ms)
'' Wait ms milliseconds for a byte to be received
'' returns -1 if no byte received, $00..$FF if byte
  return rxtime1(handle1, ms)

PUB  rx
'' Receive byte (may wait for byte)
'' returns $00..$FF
  return rx1(handle1)
  
PUB  tx(txbyte)
'' Send byte (may wait for room in buffer)
  tx1(handle1, txbyte)
  
PUB  str(stringptr)
'' Send string
  str1(handle1, stringptr)

PUB dec(value)
'' Print a decimal number
  dec1(handle1, value)

PUB hex(value, digits)
'' Print a hexadecimal number
  hex1(handle1, value, digits)

PUB bin(value, digits)
'' Print a binary number
  bin1(handle1, value, digits)

''
''*****************************************************************************
''Enhanced routines
''*****************************************************************************
PUB start1(handle, rxpin, txpin, mode, baudrate, rxsize, txsize) : okay
'' Start serial driver - starts a cog
'' returns false if no cog available
''
'' mode bit 0 = invert rx
'' mode bit 1 = invert tx
'' mode bit 2 = open-drain/source tx
'' mode bit 3 = ignore tx echo on rx
'' mode bit 4 = use lock
  if (handle1)
    if (handle1 == handle)
      stop1(handle)
  else
    handle1 := handle
  wordfill(handle+rx_head, 0, 4)
  byte[handle+rx_pin] := rxpin
  byte[handle+tx_pin] := txpin
  byte[handle+rxtx_mode] := mode
  long[handle+bit_ticks] := clkfreq / baudrate
  word[handle+rx_buffer] := handle + header_size
  word[handle+tx_buffer] := handle + header_size + rxsize
  word[handle+rx_mask] := rxsize - 1
  word[handle+tx_mask] := txsize - 1
  if (mode & %10000)
    okay := byte[handle+lock] := locknew + 1
    if (okay == 0)
      return 0
  okay := byte[handle+cog] := cognew(@entry, handle) + 1

PUB stop1(handle) | cog1
'' Stop serial driver - frees a cog
  cog1 := byte[handle+cog]
  if cog1
    cogstop(cog1 - 1)
  longfill(handle, 0, header_size >> 2)

PUB rxflush1(handle)
'' Flush receive buffer
  word[handle+rx_tail] := word[handle+rx_head]
    
PUB rxcheck1(handle) : rxbyte | rx_tail1, rx_buffer1
'' Check if byte received (never waits)
'' returns -1 if no byte received, $00..$FF if byte
  rxbyte--
  rx_tail1 := word[handle+rx_tail]
  if rx_tail1 <> word[handle+rx_head]
    rx_buffer1 := word[handle+rx_buffer]
    rxbyte := byte[rx_buffer1+rx_tail1]
    word[handle+rx_tail] := (rx_tail1 + 1) & word[handle+rx_mask]

PUB rxtime1(handle, ms) : rxbyte | t
'' Wait ms milliseconds for a byte to be received
'' returns -1 if no byte received, $00..$FF if byte
  t := cnt
  repeat until (rxbyte := rxcheck1(handle)) => 0 or (cnt - t) / (clkfreq / 1000) > ms
  
PUB rx1(handle) : rxbyte
'' Receive byte (may wait for byte)
'' returns $00..$FF
  repeat while (rxbyte := rxcheck1(handle)) < 0

PRI txchar(handle, txbyte) | tx_mask1, tx_buffer1, tx_head1, tx_head2
'' Send byte (may wait for room in buffer)
  tx_mask1 := word[handle+tx_mask]
  tx_buffer1 := word[handle+tx_buffer]
  tx_head1 := word[handle+tx_head]
  tx_head2 := (tx_head1 + 1) & tx_mask1
  repeat until (word[handle+tx_tail] <> tx_head2)
  byte[tx_buffer1+tx_head1] := txbyte
  word[handle+tx_head] := tx_head2

  if byte[handle+rxtx_mode] & %1000
    rx1(handle)

PUB tx1(handle, txbyte) | uselock, locknum
'' Send byte - Use lock if mode bit 4 is set
  uselock := byte[handle+rxtx_mode] & %10000
                     
  if (uselock)
    locknum := byte[handle+lock] - 1
    repeat until not lockset(locknum)

  txchar(handle, txbyte)

  if (uselock)
    lockclr(locknum)

PUB str1(handle, stringptr) | uselock, locknum, value
'' Send string - Use lock if mode bit 4 is set
  uselock := byte[handle+rxtx_mode] & %10000
                     
  if (uselock)
    locknum := byte[handle+lock] - 1
    repeat until not lockset(locknum)

  repeat strsize(stringptr)
    txchar(handle, byte[stringptr++])

  if (uselock)
    lockclr(locknum)

PUB dec1(handle, value) | i
'' Print a decimal number
  if (value < 0)
    tx1(handle, "-")
    if (value == NEGX)
      tx1(handle, "2")
      value += 2_000_000_000
    value := -value

  i := 1_000_000_000
  repeat while (i > value and i > 1)
    i /= 10
  repeat while (i > 0)
    tx1(handle, value/i + "0")
    value //= i
    i /= 10

PUB hex1(handle, value, digits)
'' Print a hexadecimal number
  value <<= (8 - digits) << 2
  repeat digits
    tx(lookupz((value <-= 4) & $F : "0".."9", "A".."F"))

PUB bin1(handle, value, digits)
'' Print a binary number
  value <<= 32 - digits
  repeat digits
    tx((value <-= 1) & 1 + "0")
    
PUB gethandle1
'' Get the local handle
  return handle1    

DAT

'***********************************
'* Assembly language serial driver *
'***********************************

                        org
'
'
' Entry
'
entry                   mov     t1, par
                        add     t1, #rx_pin
                        rdbyte  t2,t1                 'get rx_pin
                        mov     rxbitmask,#1
                        shl     rxbitmask,t2

                        add     t1,#1                 'get tx_pin
                        rdbyte  t2,t1
                        mov     txbitmask,#1
                        shl     txbitmask,t2

                        add     t1,#1                 'get rxtx_mode
                        rdbyte  rxtxmode,t1

                        mov     t1, par
                        add     t1, #bit_ticks        'get bit_ticks
                        rdlong  bitticks,t1

                        mov     t1, par
                        add     t1, #rx_buffer        'get rx_buffer ptr
                        rdword  rxbuff,t1

                        add     t1,#2                 'get tx_buffer ptr
                        rdword  txbuff,t1

                        add     t1,#2                 'get rx_mask
                        rdword  rxmask,t1

                        add     t1,#2                 'get tx_mask
                        rdword  txmask,t1

                        test    rxtxmode,#%100  wz    'init tx pin according to mode
                        test    rxtxmode,#%010  wc
        if_z_ne_c       or      outa,txbitmask
        if_z            or      dira,txbitmask

                        mov     txcode,#transmit      'initialize ping-pong multitasking
'
'
' Receive
'
receive                 jmpret  rxcode,txcode         'run a chunk of transmit code, then return

                        test    rxtxmode,#%001  wz    'wait for start bit on rx pin
                        test    rxbitmask,ina      wc
        if_z_eq_c       jmp     #receive

                        mov     rxbits,#9             'ready to receive byte
                        mov     rxcnt,bitticks
                        shr     rxcnt,#1
                        add     rxcnt,cnt                          

:bit                    add     rxcnt,bitticks        'ready next bit period

:wait                   jmpret  rxcode,txcode         'run a chuck of transmit code, then return

                        mov     t1,rxcnt              'check if bit receive period done
                        sub     t1,cnt
                        cmps    t1,#0           wc
        if_nc           jmp     #:wait

                        test    rxbitmask,ina      wc    'receive bit on rx pin
                        rcr     rxdata,#1
                        djnz    rxbits,#:bit

                        shr     rxdata,#32-9          'justify and trim received byte
                        and     rxdata,#$FF
                        test    rxtxmode,#%001  wz    'if rx inverted, invert byte
        if_nz           xor     rxdata,#$FF

                        mov     t1, par
                        add     t1, #rx_head
                        rdword  t2, t1                'save received byte and inc head
                        add     t2,rxbuff
                        wrbyte  rxdata,t2
                        sub     t2,rxbuff
                        add     t2,#1
                        and     t2,rxmask
                        wrword  t2,t1

                        jmp     #receive              'byte done, receive next byte
'
'
' Transmit
'
transmit                jmpret  txcode,rxcode         'run a chunk of receive code, then return

                        mov     t1,par                'check for head <> tail
                        add     t1,#tx_head
                        rdword  t2,t1
                        add     t1,#2
                        rdword  t3,t1
                        cmp     t2,t3           wz
        if_z            jmp     #transmit

                        add     t3,txbuff             'get byte and inc tail
                        rdbyte  txdata,t3
                        sub     t3,txbuff
                        add     t3,#1
                        and     t3,txmask
                        wrword  t3,t1

                        or      txdata,#$100          'ready byte to transmit
                        shl     txdata,#2
                        or      txdata,#1
                        mov     txbits,#11
                        mov     txcnt,cnt

:bit                    test    rxtxmode,#%100  wz    'output bit on tx pin according to mode
                        test    rxtxmode,#%010  wc
        if_z_and_c      xor     txdata,#1
                        shr     txdata,#1       wc
        if_z            muxc    outa,txbitmask        
        if_nz           muxnc   dira,txbitmask
                        add     txcnt,bitticks        'ready next cnt

:wait                   jmpret  txcode,rxcode         'run a chunk of receive code, then return

                        mov     t1,txcnt              'check if bit transmit period done
                        sub     t1,cnt
                        cmps    t1,#0           wc
        if_nc           jmp     #:wait

                        djnz    txbits,#:bit          'another bit to transmit?

                        jmp     #transmit             'byte done, transmit next byte
'
'
' Uninitialized data
'
t1                      res     1
t2                      res     1
t3                      res     1

rxtxmode                res     1
bitticks                res     1

rxbitmask               res     1
rxbuff                  res     1
rxdata                  res     1
rxbits                  res     1
rxcnt                   res     1
rxcode                  res     1
rxmask                  res     1

txbitmask               res     1
txbuff                  res     1
txdata                  res     1
txbits                  res     1
txcnt                   res     1
txcode                  res     1
txmask                  res     1

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