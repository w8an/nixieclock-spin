{{
// DS1307 Real Time Clock Engine
//
// Author: Kwabena W. Agyeman
// Updated: 7/27/2010
// Designed For: P8X32A
// Version: 1.4
//
// Copyright (c) 2010 Kwabena W. Agyeman
// See end of file for terms of use.
//
// Update History:
//
// v1.0 - Original release - 2/8/2009.
// v1.1 - Made code faster - 4/18/2009.
// v1.2 - Included error checking code - 2/27/2010.
// v1.3 - Added variable pin setup and locks - 4/17/2010.
// v1.4 - Fixed possible user error bugs - 7/27/2010.
//

// I2C Circuit:
//
//                  3.3V
//                   |
//                   R 10KOHM
//                   |
// Data Pin Number  --- DS1307 SDA Pin.
//
//                  3.3V
//                   |
//                   R 10KOHM
//                   |
// Clock Pin Number --- DS1307 SCL Pin.
}}

CON

  #1, Sunday, Monday, Tuesday, Wednesday, Thursday, Friday, Saturday
  #1, January, February, March, April, May, June, July, August, September, October, November, December

VAR

  byte timeTemporary, time[7]

PUB clockSecond '' 3 Stack Longs

''Returns the cached second (0 - 59) from the real time clock.

  return time

PUB clockMinute  '' 3 Stack Longs

''Returns the cached minute (0 - 59) from the real time clock.

  return time[1]

PUB clockHour '' 3 Stack Longs

''Returns the cached hour (0 - 23) from the real time clock.

  return time[2]

PUB clockDay '' 3 Stack Longs

''Returns the cached day (1 - 7) from the real time clock.

  return time[3]

PUB clockDate '' 3 Stack Longs


''Returns the cached date (1 - 31) from the real time clock.

  return time[4]

PUB clockMonth '' 3 Stack Longs

''Returns the cached month (1 - 12) from the real time clock.

  return time[5]

PUB clockYear '' 3 Stack Longs

''Returns the cached year (2000 - 2099) from the real time clock.

  return (time[6] + 2_000)

PUB clockMeridiemHour '' 6 Stack Longs

''Returns the cached meridiem hour (12 - 11) from the real time clock.

  result := (clockHour // 12)
  ifnot(result)
    result += 12

PUB clockMeridiemTime '' 6 Stack Longs

''Returns true if the cached meridiem hour is post meridiem and false if the meridiem cached hour is ante meridiem.

  return (clockHour => 12)

PUB clockSquareWaveOut(frequency, state) '' 14 Stack Longs

''Changes the current real time clock square wave output driver settings. Returns true on success and false on failure.

''Frequency - Selects the frequency of the square wave pin. (0 - 1HZ), (1 - 4.096KHZ), (2 - 8.192KHZ), (3 - 32.768KHZ).
''State - Selects the state of the square wave pin. (0 - SQW Off pin low), (1 - SQW On default low).
''                                                  (2 - SQW Off pin high), (3 - SQW On default high).

  state := ((state <# 3) #> 0)
  return setRAM(7, (((state & $2) << 6) | (state & $1) | ((frequency <# 3) #> 0)))

PUB readTime '' 11 Stack Longs

''Caches the current real time clock settings. Returns true on success and false on failure.

''Call "checkSecond" to get the real time clock second after calling this function first.
''Call "checkMinute" to get the real time clock minute after calling this function first.
''Call "checkHour" to get the real time clock hour after calling this function first.
''Call "checkDay" to get the real time clock day after calling this function first.
''Call "checkDate" to get the real time clock date after calling this function first.
''Call "checkMonth" to get the real time clock month after calling this function first.
''Call "checkYear" to get the real time clock year after calling this function first.
''Call "checkMeridiemHour" to get the real time clock meridiem hour after calling this function first.
''Call "checkMeridiemTime" to get the real time clock meridiem time after calling this function first.

  return getRam(0)

PUB writeTime(second, minute, hour, day, date, month, year) | information[7] '' 26 Stack Longs

''Changes the current real time clock time settings. Returns true on success and false on failure.
''
''Second - Number to set the second to between 0 - 59.
''Minute - Number to set the minute to between 0 - 59.
''Hour - Number to set the hour to between 0 - 23.
''Day - Number to set the day to between 1 - 7.
''Date - Number to set the date to between 1 - 31.
''Month - Number to set the month to between 1 - 12.
''Year - Number to set the year to between 2000 - 2099.

  information := ((second <# 59) #> 0)
  information[1] := ((minute <# 59) #> 0)
  information[2] := ((hour <# 23) #> 0)
  information[3] := ((day <# 7) #> 1)
  information[4] := ((date <# 31) #> 1)
  information[5] := ((month <# 12) #> 1)
  information[6] := (((year <# 2_099) #> 2_000) - 2_000)
  return setRAM(0, @information)

PUB readSRAM(index) '' 12 Stack Longs

''Returns the selected SRAM value at the specified index on sucess and false on failure.
''
''Index - The byte location in SRAM to check. (0 - 55).

  return getRam(((index <# 55) #> 0) + 8)

PUB writeSRAM(index, value) '' 14 Stack Longs

''Changes the selected SRAM value at the specified index to the specified value.
''
''Returns true on success and false on failure.
''
''Index - The byte location in SRAM to change. (0 - 55).
''Value - The value to change the byte location to. (0 - 255).

  return setRam((((index <# 55) #> 0) + 8), ((value <# 255) #> 0))

PUB pauseForSeconds(number) '' 4 Stack Longs

''Pauses execution for a number of seconds.
''
''Number - Number of seconds to pause for between 0 and 2,147,483,647.

  result := cnt

  repeat (number #> 0)

    result += clkfreq
    waitcnt(result)

PUB pauseForMilliseconds(number) '' 4 Stack Longs

''Pauses execution for a number of milliseconds.
''
''Number - Number of milliseconds to pause for between 0 and 2,147,483,647.

  result := cnt

  repeat (number #> 0)

    result += (clkfreq / 1_000)
    waitcnt(result)

PUB RTCEngineStart(dataPinNumber, clockPinNumber, lockNumberToUse) '' 9 Stack Longs

''Checks out a lock for the driver and changes the I2C Circuit pins.
''
''Returns true on success and false on failure.
''
''DataPinNumber - Pin to use to drive the SDA data line circuit.
''ClockPinNumber - Pin to use to drive the SCL clock line circuit.
''LockNumberToUse - Lock number to use if sharing the I2C bus (0 - 7). -1 to request a new lock number.

  RTCEngineStop

  dataPin := ((dataPinNumber <# 31) #> 0)
  clockPin := ((clockPinNumber <# 31) #> 0)
  if((dataPin <> clockPin) and (chipver == 1))
    lockNumber := lockNumberToUse
    if(lockNumberToUse == -1)
      lockNumber := locknew
    result or= ++lockNumber

PUB RTCEngineStop '' 3 Stack Longs

''Returns the lock used by the driver.

  if(lockNumber)
    lockret(-1 + lockNumber~)

PRI setRAM(index, value) ' 9 Stack Longs

  setLock
  startDataTransfer

  result := transmitPacket(constant(104 << 1))
  result and= transmitPacket(index)

  if(index)
    result and= transmitPacket(value)

  else
    repeat 7
      timeTemporary := long[value][index++]
      result and= transmitPacket(((timeTemporary / 10) << 4) + (timeTemporary // 10))

  stopDataTransfer
  clearLock

PRI getRAM(index) ' 8 Stack Longs

  setLock
  startDataTransfer

  result := transmitPacket(constant(104 << 1))
  result and= transmitPacket(index)

  stopDataTransfer
  startDataTransfer

  result and= transmitPacket(constant((104 << 1) | 1))

  if(index)
    result &= receivePacket(false)

  else
    bytefill(@time, 0, 7)
    if(result)
      repeat 7
        timeTemporary := receivePacket(6 <> index)
        time[index++] := (((timeTemporary >> 4) * 10) + (timeTemporary & $F))

  stopDataTransfer
  clearLock

PRI transmitPacket(value) ' 4 Stack Longs

  value := ((!value) >< 8)

  repeat 8
    dira[dataPin] := value
    dira[clockPin] := false
    dira[clockPin] := true
    value >>= 1

  dira[dataPin] := false
  dira[clockPin] := false
  result := not(ina[dataPin])
  dira[clockPin] := true
  dira[dataPin] := true

PRI receivePacket(aknowledge) ' 4 Stack Longs

  dira[dataPin] := false

  repeat 8
    result <<= 1
    dira[clockPin] := false
    result |= ina[dataPin]
    dira[clockPin] := true

  dira[dataPin] := (not(not(aknowledge)))
  dira[clockPin] := false
  dira[clockPin] := true
  dira[dataPin] := true

PRI startDataTransfer ' 3 Stack Longs

  outa[dataPin] := false
  outa[clockPin] := false
  dira[dataPin] := true
  dira[clockPin] := true

PRI stopDataTransfer ' 3 Stack Longs

  dira[clockPin] := false
  dira[dataPin] := false

PRI setLock ' 3 Stack Longs

  if(lockNumber)
    repeat while(lockset(lockNumber - 1))

PRI clearLock ' 3 Stack Longs

  if(lockNumber)
    lockclr(lockNumber - 1)

DAT

' Variable Array

dataPin                 byte 29 ' Default data pin.
clockPin                byte 28 ' Default clock pin.
lockNumber              byte 00 ' Driver lock number.


{{
//                                                  TERMS OF USE: MIT License
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
// Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
// WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}}