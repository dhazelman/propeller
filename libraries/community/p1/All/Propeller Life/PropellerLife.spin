''***********************************
''*  Propeller Life v1.0            *
''*  December 28, 2007              *
''***********************************
''┌──────────────────────────────────────────┐
''│ Copyright (c) 2007 Ken Pitts             │               
''│     See end of file for terms of use.    │               
''└──────────────────────────────────────────┘
''
''Cellular Automaton based on John Conway's Game of Life
''http://en.wikipedia.org/wiki/Conway's_Game_of_Life
''
''Use LEFT mouse button to draw live cells in cell area
''Use RIGHT mouse button to erase live cells
CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  vga_base_pin = 16
  mouse_data_pin = 24
  mouse_clock_pin = 25

  cols = vgatext#cols 'number of screen columns
  rows = vgatext#rows 'number of screen rows
  chrs = cols * rows 'number of screen character locations
  
  'screen items
  gendispx = 7 'generation count display location
  gendispy = 5

  celldispx = 7 'live cell count display location
  celldispy = 7  
 
  cellx = 34 'cell area location
  celly = 2

  cellwidth = 88 'cell area size
  cellheight = 60
  numcells = cellwidth * cellheight 'number of cell area cells   

  livecell = $85 'cell characters  
  deadcell = $A0

  numbtns = 10 'number of buttons on screen
  btnlen = 4 'length of screen button descriptors

DAT

        'screen button descriptors: x, y, width, text address
        btn1            byte    7, 10, 5, @strRun
        btn2            byte    7, 14, 5, @strStop
        btn3            byte    7, 18, 5, @strClear
        btn4            byte    7, 22, 5, @strTurbo
        btn5            byte    6, 38, 19, @strSample1
        btn6            byte    6, 41, 19, @strSample2
        btn7            byte    6, 44, 19, @strSample3
        btn8            byte    6, 47, 19, @strSample4
        btn9            byte    6, 50, 19, @strSample5
        btn10           byte    7, 26, 5, @strExit                    

        strRun          byte    " RUN ", 0
        strStop         byte    "STOP ", 0
        strClear        byte    "CLEAR", 0
        strTurbo        byte    "TURBO", 0
        strExit         byte    "EXIT ", 0
        strGens         byte    "GENERATIONS:", 0
        strCells        byte    "LIVE CELLS:", 0
        strClrFld       byte    "          ", 0 'to blank count fields
        
        strSample1      byte    "     Spaceship", 0
        strSample2      byte    " Gosper Glider Gun", 0
        strSample3      byte    "       Acorn", 0
        strSample4      byte    "      Diehard", 0  
        strSample5      byte    "   Switch Engine", 0         
        
        sample1         word    3953, 4080, 4208, 4336, 4337, 4338, 4339, 4212, 0
        sample2         word    1320, 1321, 1448, 1449, 1330, 1458, 1586, 1203
                        word    1076, 1077, 1207, 1336, 1464, 1592, 1465, 1462
                        word    1719, 1715, 1844, 1845, 1340, 1341, 1212, 1213
                        word    1084, 1085, 1470, 958, 960, 832, 1472, 1600
                        word    1098, 1099, 1226, 1227, 0
        sample3         word    6755, 6756, 6500, 6630, 6759, 6760, 6761, 0
        sample4         word    6589, 6590, 6718, 6722, 6723, 6724, 6467, 0
        sample5         word    3897, 3898, 3899, 3900, 3901, 3902, 3903, 3904
                        word    3906, 3907, 3908, 3909, 3910, 3914, 3915, 3916
                        word    3923, 3924, 3925, 3926, 3927, 3928, 3929, 3931
                        word    3932, 3933, 3934, 3935, 0                          

OBJ

  vgatext : "vga_hires_text"
  mouse   : "mouse"

VAR

  long  sync
  long  screen[cols * rows / 4] 'screen buffer
  word  colors[rows] 'row colors
  byte  cx0, cy0, cm0, cx1, cy1, cm1 'cursor control bytes
  byte  cellbuff[numcells] 'cell work buffer
  byte  turboflg '= true in turbo mode
  byte  gencogID 'generator cog ID
  long  numgens 'generation count
  long  livecells 'live cell count

  'shared screen, cell work buffer, and counter addresses - must be contiguous and in this order
  long  screenaddr
  long  celladdr    
  long  cellarea
  long  gencounter
  long  cellcounter
  long  turboflgaddr    

PUB start | i, j, oldlivecells, oldnumgens, btn_num, mousedown, mousex, mousey

  'stop generator cog
  stopgen

  'set up to pass shared variable addresses to generator cog
  screenaddr := @screen
  celladdr := @cellbuff
  cellarea := @screen + (celly * cols) + cellx 'location of cell display in screen buffer
  gencounter := @numgens
  cellcounter := @livecells
  turboflgaddr := @turboflg  

  'set cursor mode
  cm0 := %001

  'start vga text driver
  vgatext.start(vga_base_pin, @screen, @colors, @cx0, @sync)

  'start mouse and set bound parameters
  mouse.start(mouse_data_pin, mouse_clock_pin)
  mouse.bound_limits(0, 0, 0, cols - 1, rows - 1, 0)
  mouse.bound_scales(2, -3, 0)

  'set up row colors
  repeat i from 0 to rows - 1
    colors[i] := %%0020_3333 'set all rows to white foreground, blue background
      
  'fill screen with space character
  bytefill(@screen, $20, chrs)

  'draw the screen buttons
  j := @btn1
  repeat i from 1 to numbtns
    drawbutton(byte[j], byte[j + 1], byte[j + 2])
    displaytext(byte[j] + 1, byte[j + 1] + 1, @@byte[j + 3], false) 
    j += btnlen

  'draw generation count display
  displaytext(gendispx, gendispy, @strGens, false)

  'draw cell count display
  displaytext(celldispx, celldispy, @strCells, false)
  displaynum(celldispx + 14, celldispy, livecells)          

  'initialize the cell area
  clear
 
  'main loop
  repeat

    cx0 := mouse.bound_x 'cursor always follows mouse
    cy0 := mouse.bound_y

    if mouse.button(0) 'left mouse button pressed?
      ifnot mousedown 'come thru here only on initial left mouse button press (can't "drag" onto screen button)
        mousex := cx0 'save mouse location where left button was pressed
        mousey := cy0
        not mousedown '= true, block re-entry until left mouse button has been released 

        'do hit test on screen buttons
        btn_num := 0
        j := @btn1
        repeat i from 1 to numbtns 'on exit btn_num will = screen button number, or 0 for no hit
          if hit_test(mousex, mousey, byte[j], byte[j + 2], byte[j + 1], 3)
            btn_num := i
            quit 'can't be over more than one screen button at a time                      
          j += btnlen

      'mouse pointer over cell area? (OK to drag to draw multiple live cells)
      if not gencogID and hit_test(cx0, cy0, cellx, cellwidth, celly, cellheight)
        i := cols * cy0 + cx0 
        if screen.byte[i] == deadcell
          screen.byte[i] := livecell 'draw live cell
          livecells++ 'inc the live cell count

    else 'left mouse button released?
      if mousedown
        not mousedown '= false
        if btn_num
            
          'do screen button actions here on left mouse button release
          'if we're not still over the screen button we clicked, then do nothing
          j := @btn1 + (btn_num - 1) * btnlen
          if hit_test(cx0, cy0, byte[j], byte[j + 2], byte[j + 1], 3)          
            case btn_num
             
              1: 'run button
                if livecells > 0
                  startgen   
             
              2: 'stop button
                stopgen
              
              3: 'clear button
                clear                                                                                                                               
             
              4: 'turbo button
                not turboflg 'toggle
                displaytext(byte[@btn4] + 1, byte[@btn4 + 1] + 1, @@byte[@btn4 + 3], turboflg)
                                 
              5: 'sample 1
                ifnot gencogID
                  displaysample(@sample1)

              6: 'sample 2
                ifnot gencogID
                  displaysample(@sample2)

              7: 'sample 3
                ifnot gencogID
                  displaysample(@sample3)

              8: 'sample 4
                ifnot gencogID
                  displaysample(@sample4)
                  
              9: 'sample 5
                ifnot gencogID
                  displaysample(@sample5)

              10: 'exit
                reboot                                        
                                
    if mouse.button(1) 'right mouse button pressed?
      'mouse pointer over cell area? (OK to drag to kill multiple live cells)
      if not gencogID and hit_test(cx0, cy0, cellx, cellwidth, celly, cellheight)      
        i := cols * cy0 + cx0
        if screen.byte[i] == livecell
          screen.byte[i] := deadcell 'kill this cell
          livecells-- 'dec the live cell count
          
    if livecells <> oldlivecells 'the number of live cells has changed
      displaytext(celldispx + 14, celldispy, @strClrFld, false) 'to blank live cell count field    
      displaynum(celldispx + 14, celldispy, livecells) 'display number of live cells
      oldlivecells := livecells
    
    if numgens <> oldnumgens 'the generation number has changed
      displaynum(gendispx + 14, gendispy, numgens) 'display number of generations
      oldnumgens := numgens
      
    ifnot livecells 'no more live cells - stop generation
      stopgen    
                     
PRI startgen

  ifnot gencogID
    gencogID := cognew(@_generate, @screenaddr) + 1
  displaytext(byte[@btn1] + 1, byte[@btn1 + 1] + 1, @@byte[@btn1 + 3], true) 'invert run button text 
  displaytext(byte[@btn2] + 1, byte[@btn2 + 1] + 1, @@byte[@btn2 + 3], false) 'un-invert stop button text       

PRI stopgen

  if gencogID
    cogstop(gencogID~ - 1)
  displaytext(byte[@btn1] + 1, byte[@btn1 + 1] + 1, @@byte[@btn1 + 3], false) 'un-invert run button text
  displaytext(byte[@btn2] + 1, byte[@btn2 + 1] + 1, @@byte[@btn2 + 3], true) 'invert stop button text     
                
PRI hit_test(x, y, tx, width, ty, height) : hit

  if x => tx and x =< tx + width + 1 and y => ty and y =< ty + height - 1
    hit := true

PRI drawbutton(col, row, width) | pos, offset, i

  pos := cols * row + col
  offset := cols << 1
  repeat i from 1 to width
    screen.byte[pos + i] := $0E  
    screen.byte[pos + i + offset] := $0E
  screen.byte[pos] := $0A
  screen.byte[pos + width + 1] := $0B
  screen.byte[pos + offset] := $0C
  screen.byte[pos + offset + width + 1] := $0D
  screen.byte[pos + cols] := $0F
  screen.byte[pos + cols + width + 1] := $0F

PRI displaytext(col, row, textptr, invert) | pos, len, i, j

  pos := cols * row + col
  len := strsize(textptr)
  repeat i from 1 to len
    j := byte[textptr++]
    if invert
      j |= $80
    screen.byte[pos++] := j

PRI displaynum(col, row, value) | pos, i

  pos := cols * row + col
  i := 1_000_000_000
  repeat 10
    if value => i
      screen.byte[pos++] := value / i + "0"
      value //= i
      result~~
    elseif result or i == 1
      screen.byte[pos++] := "0"
    i /= 10

PRI displaysample(sampleaddr) | pos

  repeat
    pos := WORD[sampleaddr]
    if pos == 0
      quit
    if screen.byte[pos] == deadcell  
      screen.byte[pos] := livecell
      livecells++      
    sampleaddr += 2
         
PRI clear | j

  stopgen
  repeat j from celly to celly + cellheight - 1 'fill screen cell area with dead cells
    bytefill(@screen + j * cols + cellx, deadcell, cellwidth)   
  numgens := 1 'reset generation counter
  displaytext(gendispx + 14, gendispy, @strClrFld, false) 'to blank generation count field
  displaynum(gendispx + 14, gendispy, numgens) 'display number of generations ( = 1) 
  livecells := 0 'clear live cell counter
   
DAT 'assembly code for generator cog

                        org     0
_generate               mov     addr, par 'get shared variable addresses
                        rdlong  scrnaddr, addr
                        add     addr, #4
                        rdlong  celaddr, addr
                        add     addr, #4                          
                        rdlong  celarea, addr
                        add     addr, #4 
                        rdlong  gencountaddr, addr
                        add     addr, #4 
                        rdlong  cellcountaddr, addr
                        add     addr, #4 
                        rdlong  turboaddr, addr
                                                
                        rdlong  gencount, gencountaddr 'get current generation count
                        rdlong  cellcount, cellcountaddr 'get current live cell count

                        'scan every cell and build cell work buffer for new generation
mainloop                mov     screenoffset, celarea 'point to start of cell display in screen buffer
                        mov     celloffset, celaddr 'point to cell work buffer
                        mov     row1, #cellheight 'row count
rowloop                 mov     col1, #cellwidth 'column count

                        'first, count the neighboring live cells
colloop                 mov     nbrcount, #0 'clear the neighbor counter                         
                        
                        sub     screenoffset, #cols 'north 
                        rdbyte  cell, screenoffset
                        cmp     cell, #livecell wz
              if_z      add     nbrcount, #1
              
                        add     screenoffset, #1 'northeast
                        rdbyte  cell, screenoffset
                        cmp     cell, #livecell wz
              if_z      add     nbrcount, #1
              
                        add     screenoffset, #cols 'east  
                        rdbyte  cell, screenoffset
                        cmp     cell, #livecell wz
              if_z      add     nbrcount, #1
              
                        add     screenoffset, #cols 'southeast  
                        rdbyte  cell, screenoffset
                        cmp     cell, #livecell wz
              if_z      add     nbrcount, #1
              
                        sub     screenoffset, #1 'south 
                        rdbyte  cell, screenoffset
                        cmp     cell, #livecell wz
              if_z      add     nbrcount, #1
              
                        sub     screenoffset, #1 'southwest
                        rdbyte  cell, screenoffset
                        cmp     cell, #livecell wz
              if_z      add     nbrcount, #1
              
                        sub     screenoffset, #cols 'west     
                        rdbyte  cell, screenoffset
                        cmp     cell, #livecell wz
              if_z      add     nbrcount, #1
              
                        sub     screenoffset, #cols 'northwest
                        rdbyte  cell, screenoffset
                        cmp     cell, #livecell wz
              if_z      add     nbrcount, #1

                        'get the cell from the screen buffer
                        add     screenoffset, #cols + 1 'point back to original cell
                        rdbyte  cell, screenoffset 
                        cmp     cell, #livecell wz 'see if the cell is currently dead or alive
              if_nz     jmp     #nolivecell
              
                        cmp     nbrcount, #2    wz '2 neighbors?
              if_z      jmp     #writecell 'cell survives
              
                        cmp     nbrcount, #3    wz '3 neighbors?
              if_z      jmp     #writecell 'cell survives      

                        mov     cell, #deadcell 'cell died
                        sub     cellcount, #1
                        jmp     #writecell                
                        
nolivecell              cmp     nbrcount, #3    wz 'check for birth (3 neighbors) here
              if_z      mov     cell, #livecell
              if_z      add     cellcount, #1

                        'put the cell in the cell work buffer                             
writecell               wrbyte  cell, celloffset

                        'increment the screen and cell work buffer pointers
                        add     screenoffset, #1
                        add     celloffset, #1

                        'and do the loop thing
                        djnz    col1, #colloop
                        add     screenoffset, #cols - cellwidth
                        djnz    row1, #rowloop                           

                        'transfer cell work buffer to screen buffer at the end of this generation
                        mov     screenoffset, celarea
                        mov     celloffset, celaddr
                        mov     row1, #cellheight 'row count
loop3                   mov     col1, #cellwidth 'column count
loop4                   rdbyte  cell, celloffset
                        wrbyte  cell, screenoffset
                        add     screenoffset, #1
                        add     celloffset, #1
                        djnz    col1, #loop4
                        add     screenoffset, #cols - cellwidth
                        djnz    row1, #loop3                                                

                        'update the cell and generation counts in main cog
                        add     gencount, #1 
                        wrlong  gencount, gencountaddr
                        wrlong  cellcount, cellcountaddr

                        'slow us down if not in turbo mode
                        rdbyte  screenoffset, turboaddr     wz
              if_z      mov     screenoffset, #100
              if_z      shl     screenoffset, #19
              if_z      add     screenoffset, cnt                        
              if_z      waitcnt screenoffset, #0
                                                
                        jmp     #mainloop

'shared variable addresses
addr                    res     1
scrnaddr                res     1
celaddr                 res     1
celarea                 res     1
gencountaddr            res     1
cellcountaddr           res     1
turboaddr               res     1

'local variables                        
cell                    res     1
celloffset              res     1
screenoffset            res     1
row1                    res     1
col1                    res     1
nbrcount                res     1
gencount                res     1
cellcount               res     1 

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
                             