{{  NixieMultiplexer-IN17.spin

General purpose Nixie multiplexer display object.

    Author:  Steven R. Stuart
    History: 0.01 25-Dec-2012 adapted from the 16seg object
             0.02 21-Dec-2014 fixed @
             0.03 11-Jan-2022 disable anode voltage when digit is blanked
             0.04 03-Jun-2019 configure to use passed vars
             0.5  26-Mar-2025 add dat table constants for left-to-right multiplexing

  Digit Select

                      ┌────────┳─── +170VDC
                      │        │
                  10K         │
                      │        │
                      ┣─────── MPS-A92
                      │        │
                   1M         │
           10K        │         10K
    EN ──────┳──── MPS-   │
                │     │ A42    └─── nixie anode
            10K      │
                │     │
                     

                                                      PC817
                                                     Opto-Iso
             PC817 ┌─── +170VDC                    ┌────────┐
                   │                               1┤─┐  ┌─├4
    EN ────┐   10K                           │   │  │
         680    │  └───── nixie anode           2┤───┘  └─├3
                                                   └────────┘

  7441,74141,K155ID1 BCD to Decimal Decoder Driver

    0  1  5  4 GND 6  7  3
  ┌─┴──┴──┴──┴──┴──┴──┴──┴──┐      A-D = inputs
  │°                        │      0-9 = outputs
  │                         │
  └─┬──┬──┬──┬──┬──┬──┬──┬──┘
    8  9  A  D Vcc B  C  2

  Character positions
       MSD  LSD
            
        543210

}}

VAR
  long LsdPin, MsdPin            'The pins for specifying the nixie Least Significant char
                                 ' and Most Significant Digit char enable pins.
                                 ' Pins must be contiguous.
  long BcdPinA, BcdPinD          'The pins for the binary coded decimal (BCD) segments.
                                 ' Pins must be contiguous
  long DspBuff                   'Address of the shared display buffer
  long stack[32], runningCogID   'Cog data

PUB Start(data_A_pin, tube_0_pin, data_addr)
''Start the display
''Parameters:
''   data_A_pin - the pin number of BCD data line A (data B, C and D are the next 3 pins respectively)
''   tube_0_pin - the anode pin number of the rightmost nixie
''   data_addr  - address of the numeric data to display  "0"-"9" or ":" for blank

  LsdPin := tube_0_pin         'The rightmost tube is tube 0
  MsdPin := tube_0_pin + 5     '6 tubes, Most Significant Digit
  BcdPinA := data_A_pin        '74141 pin A
  BcdPinD := data_A_pin + 3    '    ..pin D
  DspBuff := data_addr
  Stop
  runningCogID := cognew(ShowStr, @stack) + 1

PUB Stop
''Shutdown the display
  if runningCogID
    cogstop(runningCogID~ - 1)

CON

  MPLEXFREQ = 360       ' Multiplex frequency

PRI ShowStr | digitPos, char
' ShowStr runs in its own cog and continually updates the display
  dira[BcdPinA..BcdPinD]~~                     'Set segment pins to outputs
  dira[LsdPin..MsdPin]~~                       'Set character pins to outputs

  repeat
    repeat digitPos from 0 to MsdPin - LsdPin  'Get next char position

      char := byte[DspBuff+digitPos]-"0"       'Get char and adjust string to value
      if char > 9                              'Disable anode voltage on blank
        outa[LsdPin..MsdPin] := word[@NixieBlank]   'norm scan
        'outa[MsdPin..LsdPin] := word[@NixieBlank]  'reverse scan
      else
        outa[LsdPin..MsdPin] := word[@NixieSel +digitPos *2] 'Enable the next character
        'outa[MsdPin..LsdPin] := word[@NixieSel +digitPos *2] 'rev scan

      outa[BcdPinD..BcdPinA] := byte[@BcdTab +char]  'Output the BCD pattern

      waitcnt(clkfreq/MPLEXFREQ + cnt)      'Slows the multiplexing to prevent bleed over

DAT

' Binary Coded Decimal table
'
{
  {{ B5755R Nixie tubes on V1.1 board }}
  BcdTab            'DCBA
  Bcd_0      byte   %0000  '0     Standard pin assignment
  Bcd_1      byte   %0001  '1
  Bcd_2      byte   %0010  '2
  Bcd_3      byte   %0011  '3
  Bcd_4      byte   %0100  '4
  Bcd_5      byte   %0101  '5
  Bcd_6      byte   %0110  '6
  Bcd_7      byte   %0111  '7
  Bcd_8      byte   %1000  '8
  Bcd_9      byte   %1001  '9
  Bcd_NUL    byte   %1111  'blank
}

  {{  IN-17 Nixie tubes on V2.0 board  }}
  BcdTab            'DCBA
  Bcd_0      byte   %1000  '8     Rather than rewire the pc board for a tube
  Bcd_1      byte   %0111  '7     with different pin positions, we just
  Bcd_2      byte   %0110  '6     reassign the data lines by altering
  Bcd_3      byte   %0101  '5     the BCD code going to the decoder.
  Bcd_4      byte   %0100  '4
  Bcd_5      byte   %0011  '3     Nixie tube digit 3 is in pc board line 5
  Bcd_6      byte   %0010  '2       "    "   digit 2 is in  "   "   line 6
  Bcd_7      byte   %0001  '1     ..etc
  Bcd_8      byte   %0000  '0
  Bcd_9      byte   %1001  '9
  Bcd_NUL    byte   %1111  'blank


' Nixie tube displays are activated by bringing the anode to +170V
'
  NixieBlank word   %00000000_00000000 'None selected

{{  Comment out one of the NixieSel groups depending on the  }}
{{  orientation of your Nixie tubes                          }}
{{                                                           }}
{{  Right-to-Left scan  -vs-  Left-To-Right scan             }}

  NixieSel   'Tube position selection during multiplex operation

{
             word   %00000000_00000001 'Rightmost char (LSD, Least Significant Digit)
             word   %00000000_00000010
             word   %00000000_00000100
             word   %00000000_00001000
             word   %00000000_00010000
             word   %00000000_00100000  'Leftmost char (MSD, Most Significant Digit)
}

''  IN-17 Nixie tubes are inverted so reverse the multiplex scan direction
             word   %00000000_00100000  'Leftmost char (MSD, Most Significant Digit)
             word   %00000000_00010000
             word   %00000000_00001000
             word   %00000000_00000100
             word   %00000000_00000010
             word   %00000000_00000001  'Rightmost char (LSD, Least Significant Digit)

'end