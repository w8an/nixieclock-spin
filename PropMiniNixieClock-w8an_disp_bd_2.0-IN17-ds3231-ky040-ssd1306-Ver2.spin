{{   PropMiniNixieClock-w8an_disp_bd_2.0-IN17-ds3231-ky040.spin
     for MINI

    Steven R. Stuart, W8AN
    Apr-Sep 2021
    Feb 2025

    Nixie clock

       -using-
       DS3231 I2C time module
       KY-040 rotary encoder

  ┌───────────────────────┐
  │     Keyes KY-040      │
  │                       │
  │clk  dt   sw    +   gnd│
  │                  │
  └─┼────┼────┼────┼────┼─┘
    │    │    │    │    │
    │    │    ┣    ┫    │
    │    │    │        
    │    │    │   Vcc
    │    │    └──────── ENC_SW  -Switch goes LO when pressed
    │    └───────────── ENC_DT
    └────────────────── ENC_CLK

Threaded encoder has sw (switch) pullup resistor included.
Rotation logic also has changed.
}}

CON

  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

CON

'' I/O pin settings

  'Nixie multiplexer object
  ANODE_0_PIN   = 0 '(P0-P5)    Rightmost digit anode pin
  BCD_A_PIN     = 8 '(P8-P11)   BCD data A pin

  'DS3231 Realtime clock object
  RTC_CLOCK_PIN = 6
  RTC_DATA_PIN  = 7

  '12/24 hour switch
  SW_HOURS_PIN = 12

  'Separator lamps
  COLON1_PIN   = 14
  COLON2_PIN   = 15

  'Rotary encoder
  ENC_SW_PIN   = 16
  ENC_DT_PIN   = 17
  ENC_CLK_PIN  = 18


'' Constants

  'setmode_idx indices
  IDX_HOUR      = 0
  IDX_MINUTE    = 1
  IDX_MONTH     = 2
  IDX_DAY       = 3
  IDX_YEAR      = 4

  TIMEOUT       = 5    'Seconds to exit the time set routine when no user activity

VAR

  long year, month, day, hour, minute, second, dow
  long clock_set_mode           'TRUE when in setup mode
  long button_was_pressed       'TRUE during unhandled button press event
  long cnt_at_action            'CNT counter at moment of the button press or knob turn
  long enc_val                  'encoder value used by KnobHasTurned()
  long setmode_val[6]           'time set mode value and index
  long setmode_idx              'index IDX_HOUR..IDX_YEAR

  long is_am                    'AM/PM flag
  long stack[96]                'cog stacks

  long high_micros, low_micros  'pwm microseconds for colon brightness
  long colon_state              '1=on; else off

OBJ

  rtc   : "DS1307_RTCEngine.spin"
  nixie : "NixieMultiplexer-IN17"
  term  : "Parallax Serial Terminal"

PUB main    |coginfo

  dira[SW_HOURS_PIN]~             '12/24 hour switch input

  term.start( 115_200 )
  'waitcnt(clkfreq * 2 + cnt)
  term.clear
  term.str(string("PropMiniNixieClock-w8an_disp_bd_2.0-IN17-ds3231-ky040-ssd1306-Ver2.spin"))
  term.newline
  term.str(string("Written by:  Steven R. Stuart, W8AN"))
  term.newline
  term.str(string("April 2021 - March 2022"))
  term.newline
  term.str(string("Updated: Mar 2025"))
  term.newline

  'waitcnt(clkfreq + cnt)

  rtc.rtcEngineStart(RTC_DATA_PIN, RTC_CLOCK_PIN, -1) 'launch real time clock cog
  nixie.Start(BCD_A_PIN, ANODE_0_PIN, @displayBuff)   'launch multiplexer cog

  is_am := false

  coginfo := cognew(TimeProcess, @stack)           'Puts current time and date into their buffers
  coginfo := cognew(ButtonListener, @stack[32])    'Watches for control button activity

  high_micros := 500   '500uS - colon pwm time to reduce brightness
  low_micros  := 5000  '5mS
  coginfo := cognew(ColonControl(COLON1_PIN), @stack[64])   'Colon gets control message from colon_state
  coginfo := cognew(ColonControl(COLON2_PIN), @stack[80])

  Depoison                            'Nixie display test
  repeat 4                            'Colon display test
    colon_state := 1
    waitcnt(clkfreq/8+cnt)
    colon_state := 0
    waitcnt(clkfreq/8+cnt)

  repeat

    bytemove(@DisplayBuff, @TimeBuff, 6)  'show the current time

    if is_am and (hour => 2 and hour =< 5)  'run depoison process at night
      if (second // 5) == 1
        colon_state := 0  'colons off
        Depoison

    if second == 10 or second == 25 or second==40 or second == 55
      colon_state := 0  'colons off
      ShowDate                          'date display

    if second // 3 == 0
      colon_state := 1  'colons on
    else
      colon_state := 0  'colons off


    if button_was_pressed               'user call for action?
      button_was_pressed := false       'reset the button flag
      clock_set_mode := true            'enable time set mode
      colon_state := 1                  'colons on

      term.dec(hour)
      term.str(string(":"))
      term.dec(minute)
      term.str(string(":"))
      term.dec(second)
      term.str(string(" clock_set_mode:"))
      term.bin(clock_set_mode,2)

      SetClock                          'go into clock set mode

      term.str(string("-"))
      term.bin(clock_set_mode,2)
      term.newline

PUB ColonControl(colon_pin) | high_time, low_time, wait_time, state
'Runs in a cog
'Turns colon lamp on/off. Uses PWM to reduce brightness

  dira[colon_pin]~~  'output

  high_time := (clkfreq / 1_000_000) * high_micros
  low_time  := (clkfreq / 1_000_000) * low_micros

  repeat

    state := long[colon_state]

    if colon_state == 1       'colon active?

      wait_time := cnt        'grab the current clock time

      outa[colon_pin] := 1    'colon on
      wait_time += high_time
      waitcnt(wait_time)

      outa[colon_pin] := 0    'colon off
      wait_time += low_time
      waitcnt(wait_time)

    else

      outa[colon_pin] := 0    'colon off


DAT ''Nixie display routines
PUB SetDisplay(strAddr)
''Move the desired display string to local buffer
  bytemove(@DisplayBuff,strAddr,14)

PUB ShowHour(strAddr)
  bytemove(@DisplayBuff,strAddr,2)

PUB ShowMinute(strAddr)
  bytemove(@DisplayBuff+2,strAddr,2)

PUB ShowSecond(strAddr)
  bytemove(@DisplayBuff+4,strAddr,2)

PUB Blank10Hour
  bytemove(@DisplayBuff,string(":"),1)     'colon (:) displays as a blank

PUB BlankHour
  bytemove(@DisplayBuff,string("::"),2)

PUB BlankMinute
  bytemove(@DisplayBuff+2,string("::"),2)

PUB BlankSecond
  bytemove(@DisplayBuff+4,string("::"),2)

PUB BlankDisplay
  bytemove(@DisplayBuff,string("::::::"),6)

PUB ModeDisplay(strAddr1,strAddr2)            'Display the mode num at left pos, value at right
  bytemove(@DisplayBuff+2,string("::"),2) 'show the mode number
  bytemove(@DisplayBuff,  strAddr1,2)     'blank the center 2 digits
  bytemove(@DisplayBuff+4,strAddr2,2)     'show the set value at right

PUB Ack                             'flash a zero in the hi hours digit
  SetDigit0(string("0"))
  waitcnt( clkfreq /4 + cnt )
  SetDigit0(string(":"))

PUB SetDigit0(chrAddr)              'Set a numeric char in left-most display tube: [0]123456
  bytemove(@DisplayBuff,chrAddr,1)

PUB SetDigit1(chrAddr)              'Set a numeric char in the second display tube: 0[1]23456
  bytemove(@DisplayBuff+1,chrAddr,1)

PUB SetDigit2(chrAddr)
  bytemove(@DisplayBuff+2,chrAddr,1)

PUB SetDigit3(chrAddr)
  bytemove(@DisplayBuff+3,chrAddr,1)

PUB SetDigit4(chrAddr)
  bytemove(@DisplayBuff+4,chrAddr,1)

PUB SetDigit5(chrAddr)
  bytemove(@DisplayBuff+5,chrAddr,1)


PRI SetClock

      GetTimeArray               'populate the setmode_val[] array with current time
      setmode_idx := IDX_HOUR    'begin with setting the hour

      repeat until !clock_set_mode

           bytemove(@mval, decx(setmode_val[setmode_idx],2),3)
           BlankDisplay

           if (setmode_idx == IDX_HOUR) or (setmode_idx == IDX_MONTH)
             ShowHour(@mval)                'hour or month, display in left 2 digits
           elseif setmode_idx == IDX_YEAR
             ShowSecond(@mval)              'year, display in right 2 digits
           else
             ShowMinute(@mval)              'minute or day, display in center 2 digits

           enc_val := setmode_val[setmode_idx]   'set with current date or time value

         if KnobHasTurned           'user is choosing among the valid values
           cnt_at_action := cnt     'reset the action counter

           if setmode_idx == IDX_HOUR
             if enc_val < 0
               enc_val := 23
             if enc_val > 23
               enc_val := 0

           elseif setmode_idx == IDX_MINUTE
             if enc_val < 0
               enc_val := 59
             if enc_val > 59
               enc_val := 0

           elseif setmode_idx == IDX_MONTH
             if enc_val < 1
               enc_val := 12
             if enc_val > 12
               enc_val := 1

           elseif setmode_idx == IDX_DAY
             if (setmode_val[IDX_YEAR] // 4) == 0 'leap year?
               byte[@DaysInMonth+1] := 29  'set Feb days
             else
               byte[@DaysInMonth+1] := 28
             if enc_val < 1
               enc_val := byte[@DaysInMonth + setmode_val[IDX_MONTH] -1]
             if enc_val > byte[@DaysInMonth + setmode_val[IDX_MONTH] -1]
               enc_val := 1

           else  'setmode_idx == IDX_YEAR
             if enc_val < 0
               enc_val := 99
             if enc_val > 99
               enc_val := 0

           setmode_val[setmode_idx] := enc_val    'save the user's input

         if button_was_pressed
           'set hour then minute, month, day, etc.
           button_was_pressed := false

           setmode_idx := setmode_idx + 1
           if setmode_idx > IDX_YEAR  '4
             setmode_idx := IDX_HOUR  '0

         if ((cnt - cnt_at_action) / clkfreq) > TIMEOUT    'escape the set routine and set clock
           clock_set_mode := false                         'when no activity for timeout seconds

           if (setmode_val[IDX_YEAR] // 4) == 0 'leap year?
             byte[@DaysInMonth+1] := 29
           else
             byte[@DaysInMonth+1] := 28

           'ensure there is no day of month overflow
           setmode_val[IDX_DAY] <#= byte[@DaysInMonth + setmode_val[IDX_MONTH] -1]

           'now save the time to DS3231
           setmode_val[IDX_YEAR] := setmode_val[IDX_YEAR] + 2000  'add the century
           PutTimeArray                 'store it


DAT
  DisplayBuff               'data that is muliplexed to the Nixies
    hr10        byte "1"
    hr1         byte "2"
    min10       byte "0"
    min1        byte "0"
    sec10       byte "0"
    sec1        byte "0"
    overflow0   byte 0,0

  TimeBuff
    hr_d10      byte "0"
    hr_d1       byte "0"
    min_d10     byte "0"
    min_d1      byte "0"
    sec_d10     byte "0"
    sec_d1      byte "0"
    overflow1   byte 0,0

  DateBuff
    year_d10    byte "0"
    year_d1     byte "0"
    mon_d10     byte "0"
    mon_d1      byte "0"
    day_d10     byte "0"
    day_d1      byte "0"
    overflow2   byte 0,0

  blank         byte ":"  'leading zero blanking

                   ''Jn Fb Mr Ap Ma Jn Jl Ag Sp Oc Nv Dc
  DaysInMonth   byte 31,28,31,30,31,30,31,31,30,31,30,31

  ModeBuff
    mnum        byte "00",0  'mode_num
    mval        byte "00",0  'mode_val


PRI GetTimeArray
''populate the timeset array with the current time

    rtc.readTime                       'Read time from rtc chip into registers

    setmode_val[IDX_HOUR]   := rtc.clockHour    'get values from registers
    setmode_val[IDX_MINUTE] := rtc.clockMinute
    setmode_val[IDX_MONTH]  := rtc.clockMonth
    setmode_val[IDX_DAY]    := rtc.clockDate
    setmode_val[IDX_YEAR]   := rtc.clockYear-2000


PRI PutTimeArray
''store setmode_vals into RTC chip
''(note that day_of_week is a value from 1..7 and is not used in this application)

                  'sec, min,                   hour,                 day_of_week,
    rtc.writeTime( 0, setmode_val[IDX_MINUTE], setmode_val[IDX_HOUR], 1, {
                  'date,                 month,                  year
    }              setmode_val[IDX_DAY], setmode_val[IDX_MONTH], setmode_val[IDX_YEAR] )


VAR ''KnobHasTurned

    long enc_detent
    long clockwise  'boolean

PRI KnobHasTurned | encoder

    'return true if turned

     encoder := ina[ENC_DT_PIN..ENC_CLK_PIN]    'rotation inputs

     if encoder <> enc_detent
       'encoder has moved
       if enc_detent == 0
          if encoder == 2
            clockwise := true  'cw
          else
            clockwise := false 'ccw
       else 'enc_detent = 3
          if encoder == 1
            clockwise := true  'cw
          else
            clockwise := false 'ccw

       repeat   'wait for detent position
         encoder := ina[ENC_DT_PIN..ENC_CLK_PIN]
       until encoder == 3  'or encoder == 0     'use both if older encoder
       enc_detent := encoder

       if clockwise
         enc_val += 1
       else
         enc_val -= 1

       return true

     return false


PRI ButtonListener

'' Monitor the rotary encoder switch
'' Run this function in a cog

    dira[ENC_SW_PIN]~             'button as input
    button_was_pressed := false   'initilaze flag

    repeat

      if ina[ENC_SW_PIN] == 0         'button press detected
        waitcnt(clkfreq/10 + cnt)     'delay 1/10th second
        if ina[ENC_SW_PIN] == 0       'is it still pressed?
          repeat until ina[ENC_SW_PIN] == 1  'wait until released
          button_was_pressed := true         'set action flag
          cnt_at_action := cnt               'get action time


PRI ShowDate | i
''
    'scroll the full date into display
    repeat i from 0 to 5
      SingleInDigits( DateBuff[i], i )
    if !button_was_pressed    'bypass if user calls for action
      waitcnt(clkfreq*2+cnt)

    'scroll the date digits out of display
    repeat i from 0 to 5
      SingleOutDigits( i )

    'drop the time into display one digit at a time from left
    repeat i from 0 to 5
      if !button_was_pressed
        waitcnt(clkfreq/8+cnt)
      DisplayBuff[i] := TimeBuff[i]
    if !button_was_pressed
      waitcnt(clkfreq/8+cnt)


PRI SingleInDigits(digit,position) | i
   'scroll in from right a single digit to position.
   'digit is the ascii representation "0".."9"

    repeat i from 5 to position
      if i < 6
        DisplayBuff[i+1] := blank
      DisplayBuff[i] := digit
      if !button_was_pressed    'bypass if user calls for action
        waitcnt(clkfreq/20 + cnt)


PRI SingleOutDigits(position) | i
    'scroll out to left a single digit from position

    repeat i from position to 0
      if i > 0
        DisplayBuff[i-1] := DisplayBuff[i]
      DisplayBuff[i]   := blank
      if !button_was_pressed   'bypass if user calls for action
        waitcnt(clkfreq/15 + cnt)


PRI DecToChar( decimal )
''convert 0 to "0", 1 to "1", etc.

  return decimal + 48     'add ascii "0"

PRI Depoison | i, char
''Nixie conditioner process

    repeat i from 0 to 9
      char := DecToChar( i )
      DisplayBuff[0] := char
      DisplayBuff[1] := char
      DisplayBuff[2] := char
      DisplayBuff[3] := char
      DisplayBuff[4] := char
      DisplayBuff[5] := char
      waitcnt(clkfreq/4 + cnt)


PRI TimeProcess | d0,d1,d2,d3,d4,d5, hour_sel
'Runs in its own cog
'Keep the time and date display registers current

  repeat

    rtc.readTime                       'Read time from rtc chip into registers

    year   := rtc.clockYear-2000
    month  := rtc.clockMonth
    day    := rtc.clockDate
    hour   := rtc.clockHour            'get tokens from rtc registers
    minute := rtc.clockMinute
    second := rtc.clockSecond

    if hour < 12
      is_am := true
    else
      is_am := false

    'set up date
    d0 := (month - month // 10) / 10     'separate the date digits
    d1 :=  month - d0 * 10
    d2 := (day - day // 10 ) / 10
    d3 :=  day - d2 * 10
    d4 := (year - year // 10) / 10
    d5 :=  year - d4 * 10

    'move date into DateBuff
    DateBuff[0] := DecToChar(d0)
    DateBuff[1] := DecToChar(d1)
    DateBuff[2] := DecToChar(d2)
    DateBuff[3] := DecToChar(d3)
    DateBuff[4] := DecToChar(d4)
    DateBuff[5] := DecToChar(d5)

    'get the 12/24 hour switch
    hour_sel := ina[SW_HOURS_PIN]        'hi = 12 hour display

    'adjust am/pm hours if desired
    if hour_sel == 1                   'true if 12 hour is selected
      if hour == 0
        hour := 12         'midnite
      if hour > 12
        hour := hour - 12  'adj for PM

    'set up time
    d0 := (hour - hour // 10) / 10       'separate the time digits
    d1 :=  hour - d0 * 10
    d2 := (minute - minute // 10) / 10
    d3 :=  minute - d2 * 10
    d4 := (second - second // 10) / 10
    d5 :=  second - d4 * 10

    'move time into TimeBuff
    if (hour_sel == 1) and (d0 == 0)    'leading zero blanking
      TimeBuff[0] := ":"  'blank
    else
      TimeBuff[0] := DecToChar(d0)

    TimeBuff[1] := DecToChar(d1)
    TimeBuff[2] := DecToChar(d2)
    TimeBuff[3] := DecToChar(d3)
    TimeBuff[4] := DecToChar(d4)
    TimeBuff[5] := DecToChar(d5)


DAT ''decx is from object Simple_Numbers.spin
CON
    MAX_LEN = 64                                          ' 63 chars + zero terminator

VAR
    long  idx                                             ' pointer into string
    byte  nstr[MAX_LEN]                                   ' string for numeric data

PUB decx(value, digits) | div

'' Returns pointer to zero-padded, signed-decimal string
'' -- if value is negative, field width is digits+1

  bytefill(@nstr, 0, MAX_LEN)                            ' clear string to zeros
  idx~                                                  ' reset index

  digits := 1 #> digits <# 10

  if (value < 0)                                        ' negative value?
    -value                                              '   yes, make positive
    nstr[idx++] := "-"                                  '   and print sign indicator

  div := 1_000_000_000                                  ' initialize divisor
  if digits < 10                                        ' less than 10 digits?
    repeat (10 - digits)                                '   yes, adjust divisor
      div /= 10

  value //= (div * 10)                                  ' truncate unused digits

  repeat digits
    nstr[idx++] := (value / div + "0")                  ' convert digit to ASCII
    value //= div                                       ' update value
    div /= 10                                           ' update divisor

  return @nstr


DAT
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
