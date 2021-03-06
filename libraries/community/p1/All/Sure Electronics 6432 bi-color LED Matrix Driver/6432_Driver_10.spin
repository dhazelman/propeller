' 6432 3mm Bi-color display Driver... 1.0

' This is the small 64x32 Bi-color LED matrix from Sure Electronics.
' The driver was written with Brad's Spin tool on Ubuntu... ;-)

' P0 to P3 data to display, R1, R2, G1, G2
' P4 to P7 Row address A,B,C,D
' P8 clk for data. S
' P9 latch data L
' P10 Enable for Row address. E

' If you are using the 5mm LED, you need to change the code for the Enable signal.
' According to the docs, the Enable signal is inverted for the 5mm compared to the 3mm.
' The code have the 5mm code commented out so you can just comment out the 3mm Enable
' and un comment the enable signal for 5mm if desired.


' I've been using this driver for a while in my Pong game and it seem to work great.

' Have fun...

VAR

   long displayBitmap[2*32*2]   ' Bitmap for display, need to be long aligned

' The bitmap (64x32) is arranged with 8 bytes per row aligned on long.
' The upper 32 rows controls the Red LED's
' The lower 32 rows controls the Green LED's
' To get yellow, set both green and red at the same time... ;-)

   long displayParams[1]        ' Parameters for driver in assembler

PUB start

  displayParams[0] := @displayBitmap       ' Pass pointer to bitmap
  ' Start Display driver
  cognew(@entry,@displayParams)            ' Start the driver in a separate cog.

  clear_Display

' Turn all LEDs off
PUB clear_Display | i

  repeat i from 0 to 127
    displayBitmap[i] := 0

' Return the pointer to the bitmap
PUB getBitmap : pointer

    pointer := @displayBitmap

DAT

'******************************************************************
'* Assember driver for updating the 6432 LED Matrix from a bitmap *
'******************************************************************

                        org     0
entry                   jmp     #display_main                                   'Start here...

direction               long    $00_00_07_FF                                    ' Port direction, 0-10 as output.
clk                     long    $00_00_01_00                                    ' Clock pin
latch                   long    $00_00_02_00                                    ' Latch pin
enable                  long    $00_00_04_00                                    ' Enable pin
clear_row               long    $00_00_00_F0                                    ' Mask row in Matrix
clear_data              long    $00_00_00_0F                                    ' Mask data for Matrix
endian_mask             long    $FF00FF00                                       ' Phipi's endian mask

display_delay           long    40_000                                          ' 0.5 ms delay
delay_counter           long    0                                               ' Counter for waitcnt
par_pointer             long    0                                               ' Pointer to parameters
bitmap_prt              long    0                                               ' Pointer to bitmap

display_long0_red1      long    0                                               ' Data from bitmap
display_long1_red1      long    0                                               ' Read 8 longs, two longs per row.
display_long0_red2      long    0                                               ' The red1 are the top row.
display_long1_red2      long    0                                               ' red2 are 16 rows down.
display_long0_green1    long    0                                               ' Then green1 is another 16 down on it's own bitmap
display_long1_green1    long    0                                               ' And green2 is another 16 rows down.
display_long0_green2    long    0
display_long1_green2    long    0

current_row             long    0                                               ' Current row for bitmap
row_counter             long    16                                              ' Row counter, counting down, used for the display row as well
bit_counter             long    64                                              ' Counting the bits to shift out 64 bits from two longs.
temp                    long    0                                               ' Yes, you guessed it, a temprary variable
swap_be                 long    0                                               ' Temporary swap for Big Endian
swap_le                 long    0                                               ' Temporary swap for Little Endian

display_main
                        mov     par_pointer, par                                ' Get parameter pointer.
                        rdlong  bitmap_prt, par_pointer                         ' Get pointer to paramters

                        mov     dira, direction                                 ' 0-10 as output.
                        mov     outa, #0                                        ' Set them low.
                        or      outa, clk                                       ' Reset clock
                        andn    outa, latch                                     ' Reset latch
                        or      outa, enable                                    ' disable display

                        mov     bit_counter, #64                                ' Init variables.
                        mov     row_counter, #16
                        mov     current_row, #0
display_loop
                        mov     temp, row_counter                               ' Get current row.
                        sub     temp, #1                                        ' Row counter goes from 16 so we need to subrtact one.
                        shl     temp, #4                                        ' Shift to correct position
                        andn    outa, clear_row                                 ' Clear row bits
                        or      outa, temp                                      ' Set row bits, weird row orientation.
                        mov     temp, current_row                               ' Get current row for bitmap
                        shl     temp, #3                                        ' Multiply by 8.
                        add     temp, bitmap_prt                                ' Add bitmap address, this is the red LED bitmap.

                        rdlong  display_long0_red2, temp                        ' Read first long in row
                        add     temp, #4                                        ' Point to next long
                        rdlong  display_long1_red2, temp                        ' Read second long in row
                        add     temp, #124                                      ' Point to 16 rows below
                        rdlong  display_long0_red1, temp                        ' Read first long in row
                        add     temp, #4                                        ' Point to next long
                        rdlong  display_long1_red1, temp                        ' Read second long in row

                        add     temp, #124                                      ' Point to 16 rows below, we are now in the green LED bitmap
                        rdlong  display_long0_green2, temp                      ' Read first long in row
                        add     temp, #4                                        ' Point to next long
                        rdlong  display_long1_green2, temp                      ' Read second long in row
                        add     temp, #124                                      ' Point to 16 rows below
                        rdlong  display_long0_green1, temp                      ' Read first long in row
                        add     temp, #4                                        ' Point to next long
                        rdlong  display_long1_green1, temp                      ' Read second long in row

                        movs    endian_source, #display_long0_red1              ' Switch endian...
                        movd    endian_dest, #display_long0_red1
                        call    #endian_switch
                        movs    endian_source, #display_long1_red1              ' Switch endian...
                        movd    endian_dest, #display_long1_red1
                        call    #endian_switch
                        movs    endian_source, #display_long0_red2              ' Switch endian...
                        movd    endian_dest, #display_long0_red2
                        call    #endian_switch
                        movs    endian_source, #display_long1_red2              ' Switch endian...
                        movd    endian_dest, #display_long1_red2
                        call    #endian_switch

                        movs    endian_source, #display_long0_green1            ' Switch endian...
                        movd    endian_dest, #display_long0_green1
                        call    #endian_switch
                        movs    endian_source, #display_long1_green1            ' Switch endian...
                        movd    endian_dest, #display_long1_green1
                        call    #endian_switch
                        movs    endian_source, #display_long0_green2            ' Switch endian...
                        movd    endian_dest, #display_long0_green2
                        call    #endian_switch
                        movs    endian_source, #display_long1_green2            ' Switch endian...
                        movd    endian_dest, #display_long1_green2
                        call    #endian_switch

bit_shift_loop
                        mov     temp, #0                                        ' Clear temp
                        rcr     display_long0_green2, #1 wc                     ' Rotate 'last' green upper bits
                        rcr     display_long1_green2, #1 wc                     ' Rotate 'last' green lower bits
                        rcl     temp, #1                                        ' Save bit in temp
                        rcr     display_long0_green1, #1 wc                     ' Rotate 'first' green upper bits
                        rcr     display_long1_green1, #1 wc                     ' Rotate 'first' green lower bits
                        rcl     temp, #1                                        ' Save bit in temp

                        rcr     display_long0_red2, #1 wc                       ' Rotate 'last' red upper bits
                        rcr     display_long1_red2, #1 wc                       ' Rotate 'last' red lower bits
                        rcl     temp, #1                                        ' Save bit in temp
                        rcr     display_long0_red1, #1 wc                       ' Rotate 'first' red upper bits
                        rcr     display_long1_red1, #1 wc                       ' Rotate 'first' red lower bits
                        rcl     temp, #1                                        ' Save bit in temp

                        xor     temp, #$0F                                      ' Invert bits for LED Matrix

                        andn    outa, clear_data                                ' Clear data bits
                        or      outa, temp                                      ' Set data bits
                        andn    outa, clk                                       ' Set bits by setting clock low.
                        or      outa, clk                                       ' Reset clock.
                        djnz    bit_counter, #bit_shift_loop                    ' Continue clocking bits.

                        andn    outa, enable                                    ' Enable display, 3mm
'                        or      outa, enable                                    ' Enable display, 5mm

                        or      outa, latch                                     ' Latch data
                        andn    outa, latch                                     ' Reset Latch

                        mov     delay_counter, cnt                              ' Get counter into delay_counter
                        add     delay_counter, display_delay                    ' Add actual delay
                        waitcnt delay_counter, display_delay                    ' Wait for 1ms per row.

                        or      outa, enable                                    ' Disable display, 3mm
'                        andn    outa, enable                                    ' Disable display, 5mm

                        mov     bit_counter, #64                                ' Reset bit counter.
                        add     current_row, #1                                 ' Next row...
                        djnz    row_counter, #display_loop                      ' Continue with the rows.
                        mov     row_counter, #16                                ' Reset the row counters.
                        mov     current_row, #0
                        jmp     #display_loop                                   ' Update forever....

endian_switch                                                                   ' Use Phipi's endian switch...
endian_source           mov   swap_le, 0-0                                      ' Get little endian.
                        mov   swap_be,swap_le                                   ' abcd            abcd
                        and   swap_be,endian_mask                               ' abcd            a_c_
                        xor   swap_le,swap_be                                   ' _b_d            a_c_
                        rol   swap_be,#8                                        ' _b_d            _c_a
                        ror   swap_le,#8                                        ' d_b_            _c_a
                        or    swap_be,swap_le                                   ' d_b_            dcba <-
endian_dest             mov   0-0, swap_be                                      ' Set swapped endian.
endian_switch_ret       ret


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
