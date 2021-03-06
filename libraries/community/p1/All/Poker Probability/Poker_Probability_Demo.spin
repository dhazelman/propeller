{{
┌───────────────────────────────┬───────────────────┬────────────────────┐
│  Poker_Probability_Demo v1.0  │ Author: I.Kövesdi │  Rel.: 15.01.2012  │
├───────────────────────────────┴───────────────────┴────────────────────┤
│                    Copyright (c) 2012 CompElit Inc.                    │               
│                   See end of file for terms of use.                    │               
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  This PST demo estimates the probability of a given poker hand being   │
│ the best hand at the table in Texas Hold'em.                           │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│ Background and Detail:                                                 │
│  The program calculates 1000 random dealings against 1 to 9 opponents  │
│ for a given own cards/community cards situation to figure out the      │
│ number of winning hands. This number is used to estimate the chance    │
│ of winning the game with the given cards.                              │
│                                                                        │ 
├────────────────────────────────────────────────────────────────────────┤
│ Note:                                                                  │
│  This SPIN code is to test the algorithm that is based on primes. The  │
│ PASM version of the code can be used in pocket sized poker player      │
│ machine. This application uses 6 COGs for parallel computation.        │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
}}


CON

_CLKMODE         = XTAL1 + PLL16x
_XINFREQ         = 5_000_000

'Constants for prime algorithm
'Primes of suits
_CLUBS           = 1
_DIAMONDS        = 2
_HEARTS          = 3
_SPADES          = 5

'Primes of ranks
_TWO             = 2
_THREE           = 3
_FOUR            = 5
_FIVE            = 7
_SIX             = 11
_SEVEN           = 13
_EIGHT           = 17
_NINE            = 19
_TEN             = 23
_JACK            = 29
_QUEEN           = 31
_KING            = 41
_ACE             = 43

'Card numbers
'  │  2  3  4  5  6  7  8  9  T  J  Q  K  A
'──┼───────────────────────────────────────
'c │  0  1  2  3  4  5  6  7  8  9 10 11 12
'd │ 13 14 15 16 17 18 19 20 21 22 23 24 25
'h │ 26 27 28 29 30 31 32 33 34 35 36 37 38
's │ 39 40 41 42 43 44 45 46 47 48 49 50 51

'Streets
_PREFLOP         = 0
_FLOP            = 1
_TURN            = 2
_RIVER           = 3


VAR

LONG             seed, stage, nofPlayers

LONG             card, suit, rank

LONG             npool

LONG             val1, wins1
LONG             val2, wins2
LONG             val3, wins3
LONG             val4, wins4
LONG             val5, wins5
LONG             val6, wins6

LONG             nofdeals, wins, winprob
 
LONG             stack[600] 

'Common data for evaluator COGs
BYTE             held[3]
BYTE             table[6]
BYTE             pool[8]

'Separate data area for evaluator COGs
BYTE             deck1[52]
BYTE             held1[3]
BYTE             hand1[6] 
BYTE             board1[6]
BYTE             suit1[6]
BYTE             rank1[6]
BYTE             kick1[6]
BYTE             plyr1[20]

BYTE             deck2[52]
BYTE             held2[3]
BYTE             hand2[6] 
BYTE             board2[6]
BYTE             suit2[6]
BYTE             rank2[6]
BYTE             kick2[6]
BYTE             plyr2[20]

BYTE             deck3[52]
BYTE             held3[3]
BYTE             hand3[6] 
BYTE             board3[6]
BYTE             suit3[6]
BYTE             rank3[6]
BYTE             kick3[6]
BYTE             plyr3[20]

BYTE             deck4[52]
BYTE             held4[3]
BYTE             hand4[6] 
BYTE             board4[6]
BYTE             suit4[6]
BYTE             rank4[6]
BYTE             kick4[6]
BYTE             plyr4[20]

BYTE             deck5[52]
BYTE             held5[3]
BYTE             hand5[6] 
BYTE             board5[6]
BYTE             suit5[6]
BYTE             rank5[6]
BYTE             kick5[6]
BYTE             plyr5[20]

BYTE             deck6[52]
BYTE             held6[3]
BYTE             hand6[6] 
BYTE             board6[6]
BYTE             suit6[6]
BYTE             rank6[6]
BYTE             kick6[6]
BYTE             plyr6[20]


OBJ

'PST----------------------------------------------------------------------
PST        : "Parallax Serial Terminal"  'From Parallax Inc. v1.0
'SPIN TrigPack Qs15_16 32-bit Fixed-point package-------------------------
Q          : "SPIN_TrigPack"             'v2.0 CompElit Ltd.


PUB Start_Application|r,i,se,c,done,prob,cdone,su,ra,cc,sui,ran,j,ip,jp
'-------------------------------------------------------------------------
'----------------------------┌───────────────────┐------------------------
'----------------------------│ Start_Application │------------------------
'----------------------------└───────────────────┘------------------------
'-------------------------------------------------------------------------
''     Action: - Loads PST driver
''             - Initialise SPIN_TrigPack driver
''             - Reads poker situation
''             - Calclulates 1002 random dealings with 6 COGs
'' Parameters: None                                 
''     Result: None                    
''+Reads/Uses: PST CONs                  
''    +Writes: None                                    
''      Calls: Parallax Serial Terminal---------->PST.Star
''                                                PST.Char
''                                                PST.CharIn
''                                                PST.Str
''                                                PST.Dec
''             SPIN_TrigPack--------------------->Some procedures
''             RandomDealer
'-------------------------------------------------------------------------
'Start Parallax Serial Terminal. It will launch 1 COG 
PST.Start(57600)

WAITCNT((CLKFREQ / 10) + CNT)

'Start SPIN_TrigPack driver
Q.Start_Driver 

PST.Char(PST#CS)
done := FALSE
PST.Str(STRING(" Number of players = (2..T) "))
REPEAT UNTIL done
  PST.RxFlush
  r := PST.CharIn
  CASE r
    "2" :
      nofPlayers := 1
      done := TRUE
    "3" :
      nofPlayers := 2
      done := TRUE
    "4" :
      nofPlayers := 3
      done := TRUE
    "5" :
      nofPlayers := 4
      done := TRUE
    "6" :
      nofPlayers := 5
      done := TRUE
    "7" :
      nofPlayers := 6
      done := TRUE
    "8" :
      nofPlayers := 7
      done := TRUE
    "9" :
      nofPlayers := 8
      done := TRUE
    "t", "T" :
      nofPlayers := 9
      done := TRUE

PST.Char(PST#CS)
PST.Str(STRING(" Number of players = "))
PST.Dec(nofPlayers + 1)
PST.Chars(PST#NL, 2)
PST.Str(STRING("Your cards in hand = (Rank:2..9,T,J,Q,A)(Suit:c,d,h,s) "))
done := FALSE
REPEAT UNTIL done
  cdone := FALSE
  REPEAT UNTIL cdone
    PST.RxFlush
    r := PST.CharIn
    CASE r
      "2" :
        ra := 0
        cdone := TRUE
      "3" :
        ra := 1
        cdone := TRUE
      "4" :
        ra := 2
        cdone := TRUE
      "5" :
        ra := 3
        cdone := TRUE
      "6" :
        ra := 4
        cdone := TRUE
      "7" :
        ra := 5
        cdone := TRUE
      "8" :
        ra := 6
        cdone := TRUE
      "9" :
        ra := 7
        cdone := TRUE
      "t", "T" :
        ra := 8
        cdone := TRUE
      "j", "J" :
        ra := 9
        cdone := TRUE
      "q", "Q" :
        ra := 10
        cdone := TRUE
      "k", "K" :
        ra := 11
        cdone := TRUE
      "a", "A" :
        ra := 12
        cdone := TRUE    

  cdone := FALSE
  REPEAT UNTIL cdone
    PST.RxFlush
    r := PST.CharIn
    CASE r
      "c", "C" :
        su := 0
        cdone := TRUE
      "d", "D" :
        su := 1 
        cdone := TRUE
      "h", "H" :
        su := 2 
        cdone := TRUE
      "s", "S" :
        su := 3 
        cdone := TRUE

  cc := ra + 13 * su
  held[1] := cc
  PST.Char(PST#CS)
  PST.Str(STRING(" Number of players = "))
  PST.Dec(nofPlayers + 1)
  PST.Chars(PST#NL, 2)
  decode(held[1], @sui, @ran)
  Spell(sui, ran)    
  PST.Str(STRING("Your cards in hand = "))
  PST.Str(@sp)
  PST.Chars(PST#NL, 2)        

  cdone := FALSE
  REPEAT UNTIL cdone
    PST.RxFlush
    r := PST.CharIn
    CASE r
      "2" :
        ra := 0
        cdone := TRUE
      "3" :
        ra := 1
        cdone := TRUE
      "4" :
        ra := 2
        cdone := TRUE
      "5" :
        ra := 3
        cdone := TRUE
      "6" :
        ra := 4
        cdone := TRUE
      "7" :
        ra := 5
        cdone := TRUE
      "8" :
        ra := 6
        cdone := TRUE
      "9" :
        ra := 7
        cdone := TRUE
      "t", "T" :
        ra := 8
        cdone := TRUE
      "j", "J" :
        ra := 9
        cdone := TRUE
      "q", "Q" :
        ra := 10
        cdone := TRUE
      "k", "K" :
        ra := 11
        cdone := TRUE
      "a", "A" :
        ra := 12
        cdone := TRUE    

  cdone := FALSE
  REPEAT UNTIL cdone
    PST.RxFlush
    r := PST.CharIn
    CASE r
      "c", "C" :
        su := 0
        cdone := TRUE
      "d", "D" :
        su := 1 
        cdone := TRUE
      "h", "H" :
        su := 2 
        cdone := TRUE
      "s", "S" :
        su := 3 
        cdone := TRUE

  cc := ra + (13 * su)
  held[2] := cc
  PST.Char(PST#CS)
  PST.Str(STRING(" Number of players = "))
  PST.Dec(nofPlayers + 1)
  PST.Chars(PST#NL, 2)
  PST.Str(STRING("Your cards in hand = "))
  decode(held[1], @sui, @ran)
  Spell(sui, ran)
  PST.Str(@sp)
  PST.Str(STRING(" "))
  decode(held[2], @sui, @ran)
  Spell(sui, ran)
  PST.Str(@sp)  
  PST.Chars(PST#NL, 2)
  done := TRUE  

PST.Str(STRING("(C)ommunity cards, (P)robability"))
PST.Char(PST#NL)

done := FALSE
prob := FALSE
REPEAT UNTIL done
  PST.RxFlush
  r := PST.CharIn
  CASE r
    "p", "P":
      done := TRUE
      prob := TRUE
      stage := _PREFLOP
      PST.Char(PST#CS)
      PST.Str(STRING(" Number of players = "))
      PST.Dec(nofPlayers + 1)
      PST.Chars(PST#NL, 2)
      PST.Str(STRING("Your cards in hand = "))
      decode(held[1], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)
      PST.Str(STRING(" "))
      decode(held[2], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)  
      PST.Chars(PST#NL, 2)
    "c", "C":  
      PST.Char(PST#CS)
      PST.Str(STRING(" Number of players = "))
      PST.Dec(nofPlayers + 1)
      PST.Chars(PST#NL, 2)
      PST.Str(STRING("Your cards in hand = "))
      decode(held[1], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)
      PST.Str(STRING(" "))
      decode(held[2], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)  
      PST.Chars(PST#NL, 2)      
      PST.Str(STRING("    Cards on board = "))

      cdone := FALSE
      REPEAT UNTIL cdone
        PST.RxFlush
        r := PST.CharIn
        CASE r
          "2" :
            ra := 0
            cdone := TRUE
          "3" :
            ra := 1
            cdone := TRUE
          "4" :
            ra := 2
            cdone := TRUE
          "5" :
            ra := 3
            cdone := TRUE
          "6" :
            ra := 4
            cdone := TRUE
          "7" :
            ra := 5
            cdone := TRUE
          "8" :
            ra := 6
            cdone := TRUE
          "9" :
            ra := 7
            cdone := TRUE
          "t", "T" :
            ra := 8
            cdone := TRUE
          "j", "J" :
            ra := 9
            cdone := TRUE
          "q", "Q" :
            ra := 10
            cdone := TRUE
          "k", "K" :
            ra := 11
            cdone := TRUE
          "a", "A" :
            ra := 12
            cdone := TRUE    

      cdone := FALSE
      REPEAT UNTIL cdone
        PST.RxFlush
        r := PST.CharIn
        CASE r
          "c", "C" :
            su := 0
            cdone := TRUE
          "d", "D" :
            su := 1 
            cdone := TRUE
          "h", "H" :
            su := 2 
            cdone := TRUE
          "s", "S" :
            su := 3 
            cdone := TRUE    

      cc := ra + (13 * su)
      table[1] := cc
            
      PST.Char(PST#CS)
      PST.Str(STRING(" Number of players = "))
      PST.Dec(nofPlayers + 1)
      PST.Chars(PST#NL, 2)
      PST.Str(STRING("Your cards in hand = "))
      decode(held[1], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)
      PST.Str(STRING(" "))
      decode(held[2], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)  
      PST.Chars(PST#NL, 2)      
      PST.Str(STRING("    Cards on board = "))
      decode(table[1], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)  
      PST.Chars(PST#NL, 2) 

      cdone := FALSE
      REPEAT UNTIL cdone
        PST.RxFlush
        r := PST.CharIn
        CASE r
          "2" :
            ra := 0
            cdone := TRUE
          "3" :
            ra := 1
            cdone := TRUE
          "4" :
            ra := 2
            cdone := TRUE
          "5" :
            ra := 3
            cdone := TRUE
          "6" :
            ra := 4
            cdone := TRUE
          "7" :
            ra := 5
            cdone := TRUE
          "8" :
            ra := 6
            cdone := TRUE
          "9" :
            ra := 7
            cdone := TRUE
          "t", "T" :
            ra := 8
            cdone := TRUE
          "j", "J" :
            ra := 9
            cdone := TRUE
          "q", "Q" :
            ra := 10
            cdone := TRUE
          "k", "K" :
            ra := 11
            cdone := TRUE
          "a", "A" :
            ra := 12
            cdone := TRUE    

      cdone := FALSE
      REPEAT UNTIL cdone
        PST.RxFlush
        r := PST.CharIn
        CASE r
          "c", "C" :
            su := 0
            cdone := TRUE
          "d", "D" :
            su := 1 
            cdone := TRUE
          "h", "H" :
            su := 2 
            cdone := TRUE
          "s", "S" :
            su := 3 
            cdone := TRUE    

      cc := ra + (13 * su)
      table[2] := cc
            
      PST.Char(PST#CS)
      PST.Str(STRING(" Number of players = "))
      PST.Dec(nofPlayers + 1)
      PST.Chars(PST#NL, 2)
      PST.Str(STRING("Your cards in hand = "))
      decode(held[1], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)
      PST.Str(STRING(" "))
      decode(held[2], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)  
      PST.Chars(PST#NL, 2)      
      PST.Str(STRING("    Cards on board = "))
      decode(table[1], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)
      PST.Str(STRING(" "))
      decode(table[2], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)  
      PST.Chars(PST#NL, 2)         

      cdone := FALSE
      REPEAT UNTIL cdone
        PST.RxFlush
        r := PST.CharIn
        CASE r
          "2" :
            ra := 0
            cdone := TRUE
          "3" :
            ra := 1
            cdone := TRUE
          "4" :
            ra := 2
            cdone := TRUE
          "5" :
            ra := 3
            cdone := TRUE
          "6" :
            ra := 4
            cdone := TRUE
          "7" :
            ra := 5
            cdone := TRUE
          "8" :
            ra := 6
            cdone := TRUE
          "9" :
            ra := 7
            cdone := TRUE
          "t", "T" :
            ra := 8
            cdone := TRUE
          "j", "J" :
            ra := 9
            cdone := TRUE
          "q", "Q" :
            ra := 10
            cdone := TRUE
          "k", "K" :
            ra := 11
            cdone := TRUE
          "a", "A" :
            ra := 12
            cdone := TRUE    

      cdone := FALSE
      REPEAT UNTIL cdone
        PST.RxFlush
        r := PST.CharIn
        CASE r
          "c", "C" :
            su := 0
            cdone := TRUE
          "d", "D" :
            su := 1 
            cdone := TRUE
          "h", "H" :
            su := 2 
            cdone := TRUE
          "s", "S" :
            su := 3 
            cdone := TRUE    

      cc := ra + (13 * su)
      table[3] := cc
            
      PST.Char(PST#CS)
      PST.Str(STRING(" Number of players = "))
      PST.Dec(nofPlayers + 1)
      PST.Chars(PST#NL, 2)
      PST.Str(STRING("Your cards in hand = "))
      decode(held[1], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)
      PST.Str(STRING(" "))
      decode(held[2], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)  
      PST.Chars(PST#NL, 2)      
      PST.Str(STRING("    Cards on board = "))
      decode(table[1], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)
      PST.Str(STRING(" "))
      decode(table[2], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)
      PST.Str(STRING(" "))
      decode(table[3], @sui, @ran)
      Spell(sui, ran)
      PST.Str(@sp)  
      PST.Chars(PST#NL, 2)
      done := TRUE

IF NOT prob
  PST.Str(STRING("Next (C)ommunity card, (P)robability"))
  PST.Char(PST#NL)
  done := FALSE
  REPEAT UNTIL done
    PST.RxFlush
    r := PST.CharIn
    CASE r
      "p", "P":
        done := TRUE
        prob := TRUE
        stage := _FLOP
        PST.Char(PST#CS)
        PST.Str(STRING(" Number of players = "))
        PST.Dec(nofPlayers + 1)
        PST.Chars(PST#NL, 2)
        PST.Str(STRING("Your cards in hand = "))
        decode(held[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(held[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)      
        PST.Str(STRING("    Cards on board = "))
        decode(table[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[3], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)
      "c", "C":
        PST.Char(PST#CS)
        PST.Str(STRING(" Number of players = "))
        PST.Dec(nofPlayers + 1)
        PST.Chars(PST#NL, 2)
        PST.Str(STRING("Your cards in hand = "))
        decode(held[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(held[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)      
        PST.Str(STRING("    Cards on board = "))
        decode(table[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[3], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)         

        cdone := FALSE
        REPEAT UNTIL cdone
          PST.RxFlush
          r := PST.CharIn
          CASE r
            "2" :
              ra := 0
              cdone := TRUE
            "3" :
              ra := 1
              cdone := TRUE
            "4" :
              ra := 2
              cdone := TRUE
            "5" :
              ra := 3
              cdone := TRUE
            "6" :
              ra := 4
              cdone := TRUE
            "7" :
              ra := 5
              cdone := TRUE
            "8" :
              ra := 6
              cdone := TRUE
            "9" :
              ra := 7
              cdone := TRUE
            "t", "T" :
              ra := 8
              cdone := TRUE
            "j", "J" :
              ra := 9
              cdone := TRUE
            "q", "Q" :
              ra := 10
              cdone := TRUE
            "k", "K" :
              ra := 11
              cdone := TRUE
            "a", "A" :
              ra := 12
              cdone := TRUE    

        cdone := FALSE
        REPEAT UNTIL cdone
          PST.RxFlush
          r := PST.CharIn
          CASE r
            "c", "C" :
              su := 0
              cdone := TRUE
            "d", "D" :
              su := 1 
              cdone := TRUE
            "h", "H" :
              su := 2 
              cdone := TRUE
            "s", "S" :
              su := 3 
              cdone := TRUE    

        cc := ra + (13 * su)
        table[4] := cc
            
        PST.Char(PST#CS)
        PST.Str(STRING(" Number of players = "))
        PST.Dec(nofPlayers + 1)
        PST.Chars(PST#NL, 2)
        PST.Str(STRING("Your cards in hand = "))
        decode(held[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(held[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)      
        PST.Str(STRING("    Cards on board = "))
        decode(table[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[3], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[4], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)
        done := TRUE

IF NOT prob
  PST.Str(STRING("Next (C)ommunity card, (P)robability"))
  PST.Char(PST#NL)
  done := FALSE
  REPEAT UNTIL done
    PST.RxFlush
    r := PST.CharIn
    CASE r
      "p", "P":
        done := TRUE
        prob := TRUE
        stage := _TURN
        PST.Char(PST#CS)
        PST.Str(STRING(" Number of players = "))
        PST.Dec(nofPlayers + 1)
        PST.Chars(PST#NL, 2)
        PST.Str(STRING("Your cards in hand = "))
        decode(held[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(held[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)      
        PST.Str(STRING("    Cards on board = "))
        decode(table[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[3], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[4], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)
      "c", "C":
        PST.Char(PST#CS)
        PST.Str(STRING(" Number of players = "))
        PST.Dec(nofPlayers + 1)
        PST.Chars(PST#NL, 2)
        PST.Str(STRING("Your cards in hand = "))
        decode(held[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(held[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)      
        PST.Str(STRING("    Cards on board = "))
        decode(table[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[3], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[4], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)        
        PST.Chars(PST#NL, 2)         
     
        cdone := FALSE
        REPEAT UNTIL cdone
          PST.RxFlush
          r := PST.CharIn
          CASE r
            "2" :
              ra := 0
              cdone := TRUE
            "3" :
              ra := 1
              cdone := TRUE
            "4" :
              ra := 2
              cdone := TRUE
            "5" :
              ra := 3
              cdone := TRUE
            "6" :
              ra := 4
              cdone := TRUE
            "7" :
              ra := 5
              cdone := TRUE
            "8" :
              ra := 6
              cdone := TRUE
            "9" :
              ra := 7
              cdone := TRUE
            "t", "T" :
              ra := 8
              cdone := TRUE
            "j", "J" :
              ra := 9
              cdone := TRUE
            "q", "Q" :
              ra := 10
              cdone := TRUE
            "k", "K" :
              ra := 11
              cdone := TRUE
            "a", "A" :
              ra := 12
              cdone := TRUE    

        cdone := FALSE
        REPEAT UNTIL cdone
          PST.RxFlush
          r := PST.CharIn
          CASE r
            "c", "C" :
              su := 0
              cdone := TRUE
            "d", "D" :
              su := 1 
              cdone := TRUE
            "h", "H" :
              su := 2 
              cdone := TRUE
            "s", "S" :
              su := 3 
              cdone := TRUE    

        cc := ra + (13 * su)
        table[5] := cc
            
        PST.Char(PST#CS)
        PST.Str(STRING(" Number of players = "))
        PST.Dec(nofPlayers + 1)
        PST.Chars(PST#NL, 2)
        PST.Str(STRING("Your cards in hand = "))
        decode(held[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(held[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)  
        PST.Chars(PST#NL, 2)      
        PST.Str(STRING("    Cards on board = "))
        decode(table[1], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[2], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[3], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[4], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)
        PST.Str(STRING(" "))
        decode(table[5], @sui, @ran)
        Spell(sui, ran)
        PST.Str(@sp)        
        PST.Chars(PST#NL, 2)
        stage := _RIVER
        done := TRUE


CASE stage
  _PREFLOP:
    npool := 2
    pool[1] := held[1]
    pool[2] := held[2]  
  _FLOP:
    npool := 5
    pool[1] := held[1]
    pool[2] := held[2]  
    pool[3] := table[1]
    pool[4] := table[2]
    pool[5] := table[3]  
  _TURN:
    npool := 6
    pool[1] := held[1]
    pool[2] := held[2]  
    pool[3] := table[1]
    pool[4] := table[2]
    pool[5] := table[3]
    pool[6] := table[4] 
  _RIVER:
    npool := 7
    pool[1] := held[1]
    pool[2] := held[2]  
    pool[3] := table[1]
    pool[4] := table[2]
    pool[5] := table[3]
    pool[6] := table[4]
    pool[7] := table[5]

REPEAT i FROM 1 TO (npool - 1)
  REPEAT j FROM (i + 1) TO npool
    IF pool[i] == pool[j]
      PST.Chars(PST#NL, 2) 
      PST.Str(STRING("Duplicate card...Rebooting"))
      WAITCNT((3 * CLKFREQ) + CNT)
      REBOOT
       
PST.Str(STRING("Calculating..."))

CASE stage
  _PREFLOP:
    PST.Str(STRING("Preflop"))  
  _FLOP:
    PST.Str(STRING("Flop"))
  _TURN:
    PST.Str(STRING("Turn"))
  _RIVER:
    PST.Str(STRING("River"))
PST.Chars(PST#NL, 2)                                                          

'Start 6 COGs for random dealings
wins1 := -1
COGNEW(RandomDealer(@deck1,@held,@table,@hand1,@board1,@suit1,@rank1,@kick1,@val1,{
       }@plyr1, nofPlayers, 167 , @wins1, stage), @stack[0])

wins2 := -1
COGNEW(RandomDealer(@deck2,@held,@table,@hand2,@board2,@suit2,@rank2,@kick2,@val2,{
       }@plyr2, nofPlayers, 167, @wins2, stage), @stack[100])

wins3 := -1
COGNEW(RandomDealer(@deck3,@held,@table,@hand3,@board3,@suit3,@rank3,@kick3,@val3,{
       }@plyr3, nofPlayers, 167, @wins3, stage), @stack[200])

wins4 := -1
COGNEW(RandomDealer(@deck4,@held,@table,@hand4,@board4,@suit4,@rank4,@kick4,@val4,{
       }@plyr4, nofPlayers, 167, @wins4, stage), @stack[300])

wins5 := -1
COGNEW(RandomDealer(@deck5,@held,@table,@hand5,@board5,@suit5,@rank5,@kick5,@val5,{
       }@plyr5, nofPlayers, 167, @wins5, stage), @stack[400])

wins6 := -1
COGNEW(RandomDealer(@deck6,@held,@table,@hand6,@board6,@suit6,@rank6,@kick6,@val6,{
       }@plyr6, nofPlayers, 167, @wins6, stage), @stack[500])                     

'Wait for all COGs to finish the job 
REPEAT UNTIL (wins1>-1)AND(wins2>-1)AND(wins3>-1)AND(wins4>-1)AND(wins5>-1)AND(wins6>-1)

nofdeals := Q.Qval(1002)
wins := Q.Qval(wins1+wins2+wins3+wins4+wins5+wins6)
winprob := Q.Qround(Q.Qmul(Q.Qdiv(wins, nofdeals), Q.Qval(100)))  
PST.Str(STRING("Chance to win = "))
PST.Str(Q.QvalToStr(winprob))
PST.Str(STRING(" %"))
PST.Chars(PST#NL, 2)

PST.Str(STRING("Press a key to continue"))
PST.Char(PST#NL)
done := FALSE
REPEAT UNTIL done
  PST.RxFlush
  r := PST.CharIn
  done := TRUE
PST.Char(PST#CS)
WAITCNT((CLKFREQ / 10) + CNT)  
REBOOT  
'------------------------End of Start_Application-------------------------


PRI Decode(crd, su_, ra_) | s, r
'-------------------------------------------------------------------------
'--------------------------------┌────────┐-------------------------------
'--------------------------------│ Decode │-------------------------------
'--------------------------------└────────┘-------------------------------
'-------------------------------------------------------------------------
'     Action: Decodes suit and rank primes from card number
' Parameters: - Card number
'             - Address of suit prime
'             - Address of rank prime                  
'    Returns: None
'    Effects: Suit and rank returned to specified address               
'+Reads/Uses: none
'    +Writes: See effects
'-------------------------------------------------------------------------
LONG[su_] := (crd / 13) + 1
IF LONG[su_] == 4
  LONG[su_] := 5
r := (crd // 13) + 2
CASE r
  4:
    r := 5
  5:
    r := 7
  6:
    r := 11
  7:
    r := 13
  8:
    r := 17
  9:
    r := 19
  10:
    r := 23
  11:
    r := 29   
  12:
    r := 31
  13:
    r := 41
  14:
    r := 43
LONG[ra_] := r
'------------------------------End of Decode------------------------------


PRI RandomDealer(deck_,held_,table_,hand_,board_,suit_,rank_,kick_,val_,plyr_,{
}nPlayers, n, wins_, stg) | se, p, i, ip1, j, k, l, m, c, maxov, maxpv, w
'-------------------------------------------------------------------------
'-----------------------------┌──────────────┐----------------------------
'-----------------------------│ RandomDealer │----------------------------
'-----------------------------└──────────────┘----------------------------
'-------------------------------------------------------------------------
'     Action: - Deals cards for opponents
'             - Deals missing cards for board
'             - Evaluates all combination for own hand
'             - Evaluates all combination for opponents hand
' Parameters: - Address of own hand and common board byte arrays
'             - Address of work byte arrays
'             - Number of opponent players
'             - Address of number of wins LONG
'             - Street                                
'    Returns: None
'    Effects: Writes number of wins to given address               
'+Reads/Uses: BYTE array block for a given COG
'    +Writes: - BYTE array block for a given COG
'             - See effect                                     
'      Calls: Evaluate
'------------------------------------------------------------------------
w~
REPEAT n
  BYTEFILL(deck_, 1, 52)
  CASE stg
  
    _PREFLOP:
      'Initialize Deck
      BYTE[deck_][BYTE[held_][1]]~
      BYTE[deck_][BYTE[held_][2]]~
      'Draw hand cards for the other players
      REPEAT i FROM 1 TO (2 * nPlayers)
        REPEAT
          se := (?se + 1) * CNT
          c := se >> 16
          c := ((c << 5) + (c << 4) + (c << 2)) >> 16 
          IF BYTE[deck_][c] == 1
            BYTE[deck_][c]~    
            BYTE[plyr_][i] := c
            QUIT

      'Draw 5 community cards
      REPEAT i FROM 1 TO 5
        REPEAT
          se := (?se + 1) * CNT
          c := se >> 16
          c := ((c << 5) + (c << 4) + (c << 2)) >> 16            
          IF BYTE[deck_][c] == 1
            BYTE[deck_][c]~    
            BYTE[board_][i] := c
            QUIT
                  
    _FLOP:
      'Initialize Deck
      BYTE[deck_][BYTE[held_][1]]~
      BYTE[deck_][BYTE[held_][2]]~
      BYTE[deck_][BYTE[table_][1]]~
      BYTE[deck_][BYTE[table_][2]]~
      BYTE[deck_][BYTE[table_][3]]~
      'Draw hand cards for the other players
      REPEAT i FROM 1 TO (2 * nPlayers)
        REPEAT
          se := (?se + 1) * CNT
          c := se >> 16
          c := ((c << 5) + (c << 4) + (c << 2)) >> 16 
          IF BYTE[deck_][c] == 1
            BYTE[deck_][c]~    
            BYTE[plyr_][i] := c
            QUIT

      'Initialise board
      BYTE[board_][1] := BYTE[table_][1]
      BYTE[board_][2] := BYTE[table_][2]
      BYTE[board_][3] := BYTE[table_][3]    
      'Draw 2 community cards
      REPEAT i FROM 4 TO 5
        REPEAT
          se := (?se + 1) * CNT
          c := se >> 16
          c := ((c << 5) + (c << 4) + (c << 2)) >> 16            
          IF BYTE[deck_][c] == 1
            BYTE[deck_][c]~    
            BYTE[board_][i] := c
            QUIT

    _TURN:
      'Initialize Deck
      BYTE[deck_][BYTE[held_][1]]~
      BYTE[deck_][BYTE[held_][2]]~
      BYTE[deck_][BYTE[table_][1]]~
      BYTE[deck_][BYTE[table_][2]]~
      BYTE[deck_][BYTE[table_][3]]~
      BYTE[deck_][BYTE[table_][4]]~
      'Draw hand cards for the other players
      REPEAT i FROM 1 TO (2 * nPlayers)
        REPEAT
          se := (?se + 1) * CNT
          c := se >> 16
          c := ((c << 5) + (c << 4) + (c << 2)) >> 16 
          IF BYTE[deck_][c] == 1
            BYTE[deck_][c]~    
            BYTE[plyr_][i] := c
            QUIT

      'Initialise board
      BYTE[board_][1] := BYTE[table_][1]
      BYTE[board_][2] := BYTE[table_][2]
      BYTE[board_][3] := BYTE[table_][3]
      BYTE[board_][4] := BYTE[table_][4]    
      'Draw 1 community card
      REPEAT
        se := (?se + 1) * CNT
        c := se >> 16
        c := ((c << 5) + (c << 4) + (c << 2)) >> 16            
        IF BYTE[deck_][c] == 1
          BYTE[deck_][c]~     
          BYTE[board_][5] := c
          QUIT

    _RIVER:
      'Initialize Deck
      BYTE[deck_][BYTE[held_][1]]~
      BYTE[deck_][BYTE[held_][2]]~
      BYTE[deck_][BYTE[table_][1]]~
      BYTE[deck_][BYTE[table_][2]]~
      BYTE[deck_][BYTE[table_][3]]~
      BYTE[deck_][BYTE[table_][4]]~
      BYTE[deck_][BYTE[table_][5]]~
      'Draw hand cards for the other players
      REPEAT i FROM 1 TO (2 * nPlayers)
        REPEAT
          se := (?se + 1) * CNT
          c := se >> 16
          c := ((c << 5) + (c << 4) + (c << 2)) >> 16 
          IF BYTE[deck_][c] == 1
            BYTE[deck_][c]~    
            BYTE[plyr_][i] := c
            QUIT

      'Initialise board
      BYTE[board_][1] := BYTE[table_][1]
      BYTE[board_][2] := BYTE[table_][2]
      BYTE[board_][3] := BYTE[table_][3]
      BYTE[board_][4] := BYTE[table_][4]
      BYTE[board_][5] := BYTE[table_][5]    
 
  'Start to evaluate own card combinations
  maxov := 0
  REPEAT i FROM 1 TO 6
    ip1 := i + 1
    REPEAT j FROM ip1  TO 7
      l := 1 
      REPEAT k FROM 1 TO 7
        IF (k<>i)AND(k<>j)
          CASE k
            1:
              BYTE[hand_][l++] := BYTE[held_][1]
            2:  
              BYTE[hand_][l++] := BYTE[held_][2]
            3:
              BYTE[hand_][l++] := BYTE[board_][1]
            4:
              BYTE[hand_][l++] := BYTE[board_][2]
            5:
              BYTE[hand_][l++] := BYTE[board_][3]
            6:
              BYTE[hand_][l++] := BYTE[board_][4]
            7:
              BYTE[hand_][l++] := BYTE[board_][5]

      Evaluate(hand_, suit_, rank_, kick_, val_)
      IF LONG[val_] > maxov
        maxov := LONG[val_]

  'Start to evaluate other player's hand value
  maxpv := 0
  REPEAT p FROM 1 TO nPlayers
    REPEAT i FROM 1 TO 6
      ip1 := i + 1
      REPEAT j FROM ip1  TO 7
        l := 1 
        REPEAT k FROM 1 TO 7
          IF (k<>i)AND(k<>j)
            CASE k
              1:
                BYTE[hand_][l++] := BYTE[plyr_][(p-1) * 2 + 1]
              2:  
                BYTE[hand_][l++] := BYTE[plyr_][(p-1) * 2 + 2]
              3:
                BYTE[hand_][l++] := BYTE[board_][1]
              4:
                BYTE[hand_][l++] := BYTE[board_][2]
              5:
                BYTE[hand_][l++] := BYTE[board_][3]
              6:
                BYTE[hand_][l++] := BYTE[board_][4]
              7:
                BYTE[hand_][l++] := BYTE[board_][5]

        Evaluate(hand_, suit_, rank_, kick_, val_)
        IF LONG[val_] > maxpv
          maxpv := LONG[val_]

        IF maxpv > maxov
          QUIT
          
      IF maxpv > maxov
        QUIT
        
    IF maxpv > maxov
      QUIT

  IF maxov => maxpv
    'We win
    w++
    
LONG[wins_] := w                                                                  
'---------------------------End of RandomDealer---------------------------


PRI Evaluate(h_, s_, r_, k_, val_)|{
}done,i,s,r,val,flush,straight,rflush,stflush,poker,boat,drill,pair
'-------------------------------------------------------------------------
'-------------------------------┌──────────┐------------------------------
'-------------------------------│ Evaluate │------------------------------
'-------------------------------└──────────┘------------------------------
'-------------------------------------------------------------------------
'     Action: None
' Parameters: None                                
'    Returns: None
'    Effects: None                
'+Reads/Uses: none
'    +Writes: None                                    
'      Calls: none
'------------------------------------------------------------------------
val := 0
done := FALSE
rflush := FALSE
stflush := FALSE
poker := FALSE
boat := FALSE
flush := FALSE
straight := FALSE
drill := FALSE
pair := 0
'BYTE[kick_][0] := 0
BYTE[k_][1] := 0
BYTE[k_][2] := 0
BYTE[k_][3] := 0
BYTE[k_][4] := 0
BYTE[k_][5] := 0 

REPEAT i FROM 1 TO 5
  Decode(BYTE[h_][i], @s, @r)
  BYTE[s_][i] := s
  BYTE[r_][i] := r

'Multiply suits
s := 1
REPEAT i FROM 1 TO 5
  s := s * BYTE[s_][i]

'Multiply ranks
r := 1
REPEAT i FROM 1 TO 5
  r := r * BYTE[r_][i]  

'Check for Flush
CASE s
  1,32,243,3125:
    flush := TRUE

'If Flush then sort cards
IF flush
  i := 1
  IF ((r // 43) == 0)
    BYTE[k_][i++] := 43
  IF ((r // 41) == 0)
    BYTE[k_][i++] := 41
  IF ((r // 31) == 0)
    BYTE[k_][i++] := 31
  IF ((r // 29) == 0)
    BYTE[k_][i++] := 29
  IF ((r // 23) == 0)
    BYTE[k_][i++] := 23 
  IF ((r // 19) == 0)
    BYTE[k_][i++] := 19
  IF ((r // 17) == 0)
    BYTE[k_][i++] := 17 
  IF ((r // 13) == 0)
    BYTE[k_][i++] := 13 
  IF ((r // 11) == 0)
    BYTE[k_][i++] := 11 
  IF ((r // 7) == 0)
    BYTE[k_][i++] := 7
  IF ((r // 5) == 0)
    BYTE[k_][i++] := 5
  IF ((r // 3) == 0)
    BYTE[k_][i++] := 3
  IF ((r // 2) == 0) 
    BYTE[k_][i++] := 2 

'Check for Strait and assign highest card
straight := FALSE 
CASE r
  2310:
    straight:= TRUE
    BYTE[k_][1] := 11
  8610:
    straight:= TRUE
    BYTE[k_][1] := 7
  15015:
    straight:= TRUE
    BYTE[k_][1] := 13    
  85085:
    straight:= TRUE
    BYTE[k_][1] := 17
  323323:
    straight:= TRUE
    BYTE[k_][1] := 19
  1062347:
    straight:= TRUE
    BYTE[k_][1] := 23
  2800733:
    straight:= TRUE
    BYTE[k_][1] := 29
  6678671:
    straight:= TRUE
    BYTE[k_][1] := 31
  16107383:
    straight:= TRUE
    BYTE[k_][1] := 41
  36453551:
    straight:= TRUE
    BYTE[k_][1] := 43

'Check for Royal Flush
IF flush AND straight
   IF BYTE[k_][1] == 43
     rflush := TRUE
   ELSE
     stflush := TRUE

IF rflush
  val := 9_00_00_00_00
  done := TRUE 

IF stflush
  val := 8_00_00_00_00 + BYTE[k_][1]
  done := TRUE

IF NOT done
  'Check for four of a kind
  IF ((r // 16) == 0) 
    poker := TRUE
    BYTE[k_][1] := 2
    BYTE[k_][2] := r / 16
  ELSEIF ((r // 81) == 0)
    poker := TRUE
    BYTE[k_][1] := 3
    BYTE[k_][2] := r / 81
  ELSEIF ((r // 625) == 0)
    poker := TRUE
    BYTE[k_][1] := 5
    BYTE[k_][2] := r / 625
  ELSEIF ((r // 2401) == 0)
    poker := TRUE
    BYTE[k_][1] := 7
    BYTE[k_][2] := r / 2401
  ELSEIF ((r // 14641) == 0)
    poker := TRUE
    BYTE[k_][1] := 11
    BYTE[k_][2] := r / 14641
  ELSEIF ((r // 28561) == 0)
    poker := TRUE
    BYTE[k_][1] := 13
    BYTE[k_][2] := r / 28561
  ELSEIF ((r // 83521) == 0)
    poker := TRUE
    BYTE[k_][1] := 17
    BYTE[k_][2] := r / 83521
  ELSEIF ((r // 130321) == 0)
    poker := TRUE
    BYTE[k_][1] := 19
    BYTE[k_][2] := r / 130321
  ELSEIF ((r // 279841) == 0)
    poker := TRUE
    BYTE[k_][1] := 23
    BYTE[k_][2] := r / 279841
  ELSEIF ((r // 707281) == 0)
    poker := TRUE
    BYTE[k_][1] := 29
    BYTE[k_][2] := r / 707281
  ELSEIF ((r // 923521) == 0)
    poker := TRUE
    BYTE[k_][1] := 31
    BYTE[k_][2] := r / 923521
  ELSEIF ((r // 2825761) == 0)
    poker := TRUE
    BYTE[k_][1] := 41
    BYTE[k_][2] := r / 2825761
  ELSEIF ((r // 3418801) == 0)
    poker := TRUE
    BYTE[k_][1] := 43
    BYTE[k_][2] := r / 3418801

  IF poker
    val := 7_00_00_00_00 + (100 * BYTE[k_][1]) + BYTE[k_][2]  
    done := TRUE

IF NOT done
  'Check for a Drill
  IF ((r // 8) == 0)
    drill := TRUE
    BYTE[k_][1] := 2
    r /= 8
  ELSEIF ((r // 27) == 0)
    drill := TRUE
    BYTE[k_][1] := 3
    r /= 27
  ELSEIF ((r // 125) == 0)
    drill := TRUE
    BYTE[k_][1] := 5
    r /= 125
  ELSEIF ((r // 343) == 0)
    drill := TRUE
    BYTE[k_][1] := 7
    r /= 343
  ELSEIF ((r // 1331) == 0)
    drill := TRUE
    BYTE[k_][1] := 11
    r /= 1331
  ELSEIF ((r // 2197) == 0)
    drill := TRUE
    BYTE[k_][1] := 13
    r /= 2197
  ELSEIF ((r // 4913) == 0)
    drill := TRUE
    BYTE[k_][1] := 17
    r /= 4913
  ELSEIF ((r // 6859) == 0)
    drill := TRUE
    BYTE[k_][1] := 19
    r /= 6859
  ELSEIF ((r // 12167) == 0)
    drill := TRUE
    BYTE[k_][1] := 23
    r /= 12167
  ELSEIF ((r // 24389) == 0)
    drill := TRUE
    BYTE[k_][1] := 29
    r /= 24389
  ELSEIF ((r // 29791) == 0)
    drill := TRUE
    BYTE[k_][1] := 31
    r /= 29791
  ELSEIF ((r // 68921) == 0)
    drill := TRUE
    BYTE[k_][1] := 41
    r /= 68921
  ELSEIF ((r // 79507) == 0)
    drill := TRUE
    BYTE[k_][1] := 43
    r /= 79507

  IF drill
    'Check for full hand
    CASE r
      4:
        boat := TRUE
        BYTE[k_][2] := 2  
      9:
        boat := TRUE
        BYTE[k_][2] := 3 
      25:
        boat := TRUE
        BYTE[k_][2] := 5 
      49:
        boat := TRUE
        BYTE[k_][2] := 7 
      121:
        boat := TRUE
        BYTE[k_][2] := 11 
      169:
        boat := TRUE
        BYTE[k_][2] := 13
      289:
        boat := TRUE
        BYTE[k_][2] := 17 
      361:
        boat := TRUE
        BYTE[k_][2] := 19 
      529:
        boat := TRUE
        BYTE[k_][2] := 23 
      841:
        boat := TRUE
        BYTE[k_][2] := 29 
      961:
        boat := TRUE
        BYTE[k_][2] := 31 
      1681:
        boat := TRUE
        BYTE[k_][2] := 41 
      1849:
        boat := TRUE
        BYTE[k_][2] := 43 

IF NOT done
  'It's time to enumerate boats, flushes, straights and drills
  IF boat
    val := 6_00_00_00_00 + (1_00 * BYTE[k_][1]) + BYTE[k_][2]
    done := TRUE  
  ELSEIF flush
    val := 5_00_00_00_00 + (1_00_00_00 * BYTE[k_][1]) + (1_00_00 * BYTE[k_][2])
    val := val + (1_00 * BYTE[k_][3]) + (2 * BYTE[k_][4]) + BYTE[k_][5]
    done := TRUE
  ELSEIF straight
    val := 4_00_00_00_00 + BYTE[k_][1]
    done := TRUE
  ELSEIF drill   
    'Sort the 2 kickers
    i := 2
    IF ((r // 43) == 0)
      BYTE[k_][i++] := 43
    IF ((r // 41) == 0)
      BYTE[k_][i++] := 41
    IF ((r // 31) == 0)
      BYTE[k_][i++] := 31
    IF ((r // 29) == 0)
      BYTE[k_][i++] := 29
    IF ((r // 23) == 0)
      BYTE[k_][i++] := 23 
    IF ((r // 19) == 0)
      BYTE[k_][i++] := 19
    IF ((r // 17) == 0)
      BYTE[k_][i++] := 17 
    IF ((r // 13) == 0)
      BYTE[k_][i++] := 13 
    IF ((r // 11) == 0)
      BYTE[k_][i++] := 11 
    IF ((r // 7) == 0)
      BYTE[k_][i++] := 7
    IF ((r // 5) == 0)
      BYTE[k_][i++] := 5
    IF ((r // 3) == 0)
      BYTE[k_][i++] := 3 
    IF ((r // 2) == 0) 
      BYTE[k_][i++] := 2
    val := 3_00_00_00_00 + (1_00_00 * BYTE[k_][1]) + (1_00 * BYTE[k_][2]) + BYTE[k_][3]
    done := TRUE

IF NOT done
  'Remained to evaluate 2 pairs, one pair and high card
  'Check for one or two Pairs
  i := 1
  IF ((r // 1849) == 0)
    pair++
    BYTE[k_][i++] := 43
    r /= 1849
  IF ((r // 1681) == 0)
    pair++
    BYTE[k_][i++] := 41
    r /= 1681
  IF ((r // 961) == 0)
    pair++
    BYTE[k_][i++] := 31
    r /= 961
  IF ((r // 841) == 0)
    pair++
    BYTE[k_][i++] := 29
    r /= 841
  IF ((r // 529) == 0)
    pair++
    BYTE[k_][i++] := 23
    r /= 529
  IF ((r // 361) == 0)
    pair++
    BYTE[k_][i++] := 19
    r /= 361
  IF ((r // 289) == 0)
    pair++
    BYTE[k_][i++] := 17
    r /= 289
  IF ((r // 169) == 0)
    pair++
    BYTE[k_][i++] := 13
    r /= 169
  IF ((r // 121) == 0)
    pair++
    BYTE[k_][i++] := 11
    r /= 121
  IF ((r // 49) == 0)
    pair++
    BYTE[k_][i++] := 7  
    r /= 49
  IF ((r // 25) == 0)
    pair++
    BYTE[k_][i++] := 5
    r /= 25
  IF ((r // 9) == 0)
    pair++
    BYTE[k_][i++] := 3
    r /= 9                        
  IF ((r // 4) == 0)
    pair++
    BYTE[k_][i++] := 2
    r /= 4

  'Sort the 5, 3 or 1 kickers
  i := pair + 1
  IF ((r // 43) == 0)
    BYTE[k_][i++] := 43
  IF ((r // 41) == 0)
    BYTE[k_][i++] := 41
  IF ((r // 31) == 0)
    BYTE[k_][i++] := 31
  IF ((r // 29) == 0)
    BYTE[k_][i++] := 29
  IF ((r // 23) == 0)
    BYTE[k_][i++] := 23 
  IF ((r // 19) == 0)
    BYTE[k_][i++] := 19
  IF ((r // 17) == 0)
    BYTE[k_][i++] := 17 
  IF ((r // 13) == 0)
    BYTE[k_][i++] := 13 
  IF ((r // 11) == 0)
    BYTE[k_][i++] := 11 
  IF ((r // 7) == 0)
    BYTE[k_][i++] := 7
  IF ((r // 5) == 0)
    BYTE[k_][i++] := 5
  IF ((r // 3) == 0)
    BYTE[k_][i++] := 3
  IF ((r // 2) == 0)
    BYTE[k_][i++] := 2 

  'Now enumerate 
  CASE pair
    2:
      val := 2_00_00_00_00 + (1_00_00 * BYTE[k_][1]) + (1_00 * BYTE[k_][2]) + BYTE[k_][3]
    1:
      val := 1_00_00_00_00 + (1_00_00_00 * BYTE[k_][1]) + (1_00_00 * BYTE[k_][2])
      val := val + (1_00 * BYTE[k_][3]) + BYTE[k_][4]
    0:
      val := (1_00_00_00 * BYTE[k_][1]) + (1_00_00 * BYTE[k_][2])
      val := val + (1_00 * BYTE[k_][3]) + (2 * BYTE[k_][4]) + BYTE[k_][5]

LONG[val_] := val     
'-----------------------------End of Evaluate-----------------------------


PRI Spell(su, ra) 
'-------------------------------------------------------------------------
'---------------------------------┌───────┐-------------------------------
'---------------------------------│ Spell │-------------------------------
'---------------------------------└───────┘-------------------------------
'-------------------------------------------------------------------------
'     Action: None
' Parameters: None                                
'    Returns: None
'    Effects: None                
'+Reads/Uses: none
'    +Writes: None                                    
'      Calls: none
'------------------------------------------------------------------------
BYTE[@sp][2] := 0
CASE ra
  2:
    BYTE[@sp][0] := "2"
  3:
    BYTE[@sp][0] := "3"
  5:
    BYTE[@sp][0] := "4"
  7:
    BYTE[@sp][0] := "5"
  11:
    BYTE[@sp][0] := "6"
  13:
    BYTE[@sp][0] := "7"
  17:
    BYTE[@sp][0] := "8"
  19:
    BYTE[@sp][0] := "9"
  23:
    BYTE[@sp][0] := "T"
  29:  
    BYTE[@sp][0] := "J"
  31:
    BYTE[@sp][0] := "Q"
  41:
    BYTE[@sp][0] := "K"
  43:
    BYTE[@sp][0] := "A"
CASE su
  1:
    BYTE[@sp][1] := "c"
  2:          
    BYTE[@sp][1] := "d"  
  3:
    BYTE[@sp][1] := "h"
  5:
    BYTE[@sp][1] := "s"             
'------------------------------End of Spell-------------------------------


DAT

sp BYTE "xxx"


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