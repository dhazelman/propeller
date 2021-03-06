''********************************************
''*  Solar_Almanac_Demo                      *
''*  Author: Gregg Erickson                  *
''*  December 2011                           *
''*  See MIT License for Related Copyright   *
''*  See end of file and objects for .       *
''*  related copyrights and terms of use     *
''*                                          *
''*  This uses code from FullFloat32 &       *
''*  equations and equations from a          *
''*  version of "Solar Energy Systems        *
''*  Design" by W.B.Stine and R.W.Harrigan   *
''*  (John Wiley and Sons,Inc. 1986)         *
''*  retitled "Power From The Sun"           *
''*  http://www.powerfromthesun.net/book.html*
''********************************************

{{This Demonstration uses the Solar Object to
calculate to create a daily almanac of solar times
as well as the azimuth and angle of the sun's
position during the day then outputs it to the
Parallax Serial Terminal.


The solar object calculates a good approximation
of the position (altitude and azimuth) of the sun
at any time (local clock or solar) during the day
as well as events such as solar noon, sunrise,
sunset, twilight(astronomical, nautical, civil),
and daylength. Derived values such as the equation
of time, time meridians, hour angle, day of the year
and declination are also provided.

Please note: The code is fully documented and is purposely less
compact than possible to allow the user to follow and/or
modify the formulas and code.
}}

{The inputs include date, local/solar time,latitude,
longitude and daylight savings time status. Adjustments
are made for value local time zones, daylight savings
time, leap year, seasonal tilt of the earth,
retrograde of earth rotation, and ecliptic earth
orbit (Perihelion,apihelion) and atmospheric refraction.

Please note: The code is fully documented and is purposely less
compact than possible to allow the user to follow and/or
modify the formulas and code.

Potential Level of Error: The equations used are good
approximations adequate for small photovoltaic panels,
flat panel or direct apeture thermal collectors. A quick
check against NOAA data indicates a match within a
degree and minute.  More refinement may be needed for
concentrating collectorsthat focus light through a lense
or parabolic reflector. The equation of time formula
achieves an error rate of roughly 16 seconds with a max of
38 seconds. The error would need to have an average error
in the seconds of degrees and seconds of time to effectively
target the whole image on the target.

Additional error from mechanical tracking devices will
also add to the error.  Some report that these low
precision forumulas may be within a degree of angle and
a minute or so of time compared to the apparent direction
from the perspective of the observer. However, precise
verification has not been verified as calculated by this
code and/or processor. The error also increases as the
altitude gets closer to the horizon due to atmospheric
disortion and diffraction, especially at sunset and sunrise.
It may be intuitive but the accuracy is not valid when
the sun dips below the horizon such as beyond the artic
and antartic circles or at night.

In summary, this code is appropriate for two axis flat
panel tracking applications where accuracy within a degree
or two would result in negligible losses according to the
cosine effect. It would also be an effective "predictive"
complement to light sensor tracking algorims that can "hunt"
or require rapid movement during cloudy condition.  The
user should verify function, accuracy and validity of
output for any specific application.  No warranty is implied
or expressed.  Use at your own risk...

.

}


CON
  _clkmode = xtal1 + pll16x  '80 mhz, compensates for slow FP Math
  _XinFREQ = 5_000_000       'Can run slower to save power

Ver_Equ=  80               'Day of Year at Vernal Equinox
Sum_Sol=  172              'Day of Year at Summer Solstice
Aut_Equ=  266              'Day of Year at Autuminal Equinox
Win_Sol=  355              'Day of Year at Winter Solstice

CivilAngle=-6.0            'Civil Twilight Occurs 0 o 6 Degrees Below the Horizon
NautAngle=-12.0            'Nautical "" "" 6 o 12 "" "" "" ""
AstroAngle=-18.0           'Astronomical"" "" 12 o 18 "" "" "" ""

VAR

'-------Angular Variables----(FP=Floating Point, I=Integer)
Long Latitude, Longitude    'FP:Latitude & Longitude of Observer
Long Altitude, Azimuth      'FP:Angle of Sun Above Horizon and Heading
Long North,East,Height      'FP:Northerning, Easterning, Height of Target A
Long HelioAz,HelioAlt,HelioE'FP:Angle to Point a Heliostat to Hit Target A with Error
Long Theta                  'FP:Angle of Reflect Between Sun and Target Vectors
Long SunriseAz,SunsetAz     'FP:Azimuth at Sunrise and Sunset
Long HourAngle              'FP:Angle ofSun from Noon, Due to Rotation
Long HorizonHourAngle       'FP:HourAngle at Sunset and Sunrise
Long HorizonRefraction      'FP:Angle of Atmospheric Refraction at Sunset and Sunrise
Long CivilHourAngle         'FP:Hour Angle at Civil Twilight Altitude
Long NautHourAngle          'FP:Hour Angle at Nautical Twilight Altitude
Long AstroHourAngle         'FP:Hour Angle at Astronomical Twilight Altitude
Long Declination            'FP:Tilt of Earth Relative to Solar Plain
Long Distance,ReflectionSize'FP:Distance through air to target and ImageSize
Long MirrorSize             'FP:Size of Heliostat Mirror

'-------Time Variable--------(FP=Floating Point, I=Integer)
Long Sunrise,Sunset         'FP:Solar Time at Sunrise and Sunset
Long CivilTwilightRise      'FP Solar Time of Civil Twilight
Long CivilTwilightSet       '   with adequate light for outdoor activities
Long NauticalTwilightRise   'FP Solar Time of Nautical Twilight
Long NauticalTwilightSet    '   with light to see silhouettes & bright stars
Long AstronomicTwilightRise 'FP Solar Time of Astronomic Twilight
Long AstronomicTwilightSet  '   with dark enough sky to see all stars
Long LCT,SCT                'FP:Local Clock Time, Solar Clock Time
Long Meridian               'FP:Longitude of Time Zone Meridian
Long Month,Day,Year         'Integer:Year,Month & Day of the Year
Long NDays                  'FP:Day of Year starting with Jan 1st=1
Long Hour,Minute, Second    'Integer:Local Time Hour, Min & Sec
Long SolarTime,ClockTime    'FP:Local Time in Hours Adj to Solar Noon
Long DST                    'FP:Day Light Saving Time, =1.0 if true
Long Daylight               'FP:Hours of Daylight in a Day
Long EOT,EOT2,EOT3          'FP:Equation of Time, Apparent Shift in
                               'Solar Noon Due to Earth's Orbital
                               'Elipse from Apogee(far) to Perigee(near)

Long ClkHr,ClkMin,ClkSec    'I:local clock in hours, minutes, seconds
Long LocalRise,LocalSet     'Local Clock Time for Sunrise and Sunset
Long ScoutTime
Obj

  S:    "Solar2.4"                 'Solar Almanac Object
  PST:  "Parallax Serial Terminal" 'For Output & Troubleshooting
  FStr: "FloatString"              'Conversions for Output
  Fmath:"Float32Full"              'The Full Version is needed for ATAN,ACOS,ASIN


Pub main| n,dt

'-------------------Start Objects-------------
Pst.start(57600)   'Start Parallax Serial Terminal
S.start            'Start Solar Object
Fmath.start        'Start Floating Point Math Object

'-------------------Set Time and Date Defaults--------------
Clocktime:=11.8    'FP:RTC Clock, Min/60 & Sec/3600 a fracs of Hr
SolarTime:=12.0    'FP:Sun Clock, Min/60 & Sec/3600 a fracs of Hr


Year:=2012         'I: Year Divisable by 4 are leap years
Month:=1           'I: Month Set for Testing
Day:=26            'I: Day Set for Testing
DST:=0.0           'FP:Daylight Saving, 1.0=true, 0.0=false

'--------- Set Location to 599 Menlo Park, Rocklin CA----------
Longitude:=121.296104  'FP:  (Positive to West)
Latitude:=38.813112    'FP:

'---------- Set Heliostat Target ---------------------
North:=100.0         'FP: Distance of Heliostat Target toward South
East:=10.0           'FP: Distance of Heliostat Target West of Center
Height:=3.0          'FP: Height of Heliostat Target Above Heliostat

'--------------------Calculate------------------

'------ Date Calculations
NDays:=fmath.ffloat(s.Day_Number(Year,Month,Day))
EOT:=s.Equation_of_Time(NDays)
EOT2:=s.Equation_of_Time2(NDays)
EOT3:=s.Equation_of_Time3(NDays)

Declination:=s.Declination_Degrees(NDays)

'-------Time Calculations
Meridian:=s.Meridian_Calc(Longitude)
LCT:=s.Local_Clock_Time(SolarTime,Longitude,Meridian,EOT,DST)
SCT:=s.Solar_Clock_Time(LCT,Longitude,Meridian,EOT,DST)
HourAngle:=s.Hour_Angle_SolarTime(SolarTime)
ClkHr:=s.Extract_Hour(LCT)
ClkMin:=s.Extract_Minute(LCT)

'-------Sunrise/Sunset and Daylight Calculations
HorizonRefraction:=s.refraction(0.0)
HorizonHourAngle:=s.Hour_Angle_Altitude(Declination, Latitude,fmath.fmul(HorizonRefraction,-1.0))

Daylight:=s.Daylight_Hours(HorizonHourAngle)
Sunrise:=s.Solar_Time_From_AngleHour(HorizonHourAngle)
LocalRise:=s.Local_Clock_Time(SunRise,Longitude,Meridian,EOT,DST)
Sunset:=s.Solar_Time_From_AngleHour(fmath.fmul(HorizonHourAngle,-1.0))
LocalSet:=s.Local_Clock_Time(SunSet,Longitude,Meridian,EOT,DST)

CivilHourAngle:=s.Hour_Angle_Altitude(Declination, Latitude,-6.0)
CivilTwilightRise:=s.Solar_Time_From_AngleHour(CivilHourAngle)
CivilTwilightRise:=s.Local_Clock_Time(CivilTwilightRise,Longitude,Meridian,EOT,DST)  
CivilTwilightSet:=s.Solar_Time_From_AngleHour(fmath.fmul(CivilHourAngle,-1.0))
CivilTwilightSet:=s.Local_Clock_Time(CivilTwilightSet,Longitude,Meridian,EOT,DST)

NautHourAngle:=s.Hour_Angle_Altitude(Declination, Latitude,-12.0)
NauticalTwilightRise:=s.Solar_Time_From_AngleHour(NautHourAngle)
NauticalTwilightRise:=s.Local_Clock_Time(NauticalTwilightRise,Longitude,Meridian,EOT,DST)
NauticalTwilightSet:=s.Solar_Time_From_AngleHour(fmath.fmul(NautHourAngle,-1.0))
NauticalTwilightSet:=s.Local_Clock_Time(NauticalTwilightSet,Longitude,Meridian,EOT,DST)
                                                          '
AstroHourAngle:=s.Hour_Angle_Altitude(Declination, Latitude,-18.0)
AstronomicTwilightRise:=s.Solar_Time_From_AngleHour(AstroHourAngle)
AstronomicTwilightRise:=s.Local_Clock_Time(AstronomicTwilightRise,Longitude,Meridian,EOT,DST)
AstronomicTwilightSet:=s.Solar_Time_From_AngleHour(fmath.fmul(AstroHourAngle,-1.0))
AstronomicTwilightSet:=s.Local_Clock_Time(AstronomicTwilightSet,Longitude,Meridian,EOT,DST)

'-------Solar Position Calculations

SunsetAz:=s.Azimuth_Calc(Declination,Latitude,HorizonHourAngle,0.0)
SunriseAz:=s.Azimuth_Calc(Declination,Latitude,fmath.fmul(-1.0,HorizonHourAngle),0.0)

Altitude:=s.Altitude_Calc (declination,Latitude,HourAngle)
Altitude:=fmath.fadd(Altitude,s.refraction(Altitude))
Azimuth:=s.Azimuth_Calc(Declination,Latitude,HourAngle,Altitude)







'-------------------Test Output to PST-----------------
pst.char(16)

pst.home
pst.char($0D)

pst.str(String("Example Location: 599 Menlo Park, Rocklin CA 95765"))
pst.char($0D)
pst.str(String("Latitude="))
pst.str(FStr.FloatToString(latitude))
pst.char($0D)
pst.str(String("Longitude="))
pst.str(FStr.FloatToString(longitude))
pst.char($0D)
pst.char($0D)

pst.str(string("----Daily Factors----"))
pst.char($0D)
pst.str(String("Date="))
pst.dec(Month)
pst.char("/")
pst.dec(Day)
pst.char("/")
pst.dec(Year)
pst.str(String(", N="))
PST.str(FStr.FloatToString(NDays))
pst.char($0D) 
pst.str(String("Declination="))
PST.str(FStr.FloatToString(declination))
pst.char($0D)   
pst.str(String("Horizon Hour Angle="))
PST.str(FStr.FloatToString(HorizonHourAngle))
pst.char($0D)
pst.str(String("Meridian="))
PST.str(FStr.FloatToString(Meridian))
pst.char($0D)
pst.str(String("Daylight Hours="))
PST.str(FStr.FloatToString(daylight)) 
pst.str(String(" (Hours="))
pst.dec(s.Extract_Hour(daylight))
pst.str(String(", Minutes="))
pst.dec(s.Extract_Minute(daylight))
pst.str(String(")"))   
pst.char($0D)
pst.str(String("Daylight Saving="))
PST.str(FStr.FloatToString(DST))
pst.char($0D)
pst.str(String("Equation of Time # 1(Stein and Geyer)="))
PST.str(FStr.FloatToString(EOT))
pst.char($0D)
pst.str(String("Equation of Time # 2 (Whitman)="))
PST.str(FStr.FloatToString(EOT2))
pst.char($0D)
 pst.str(String("Equation of Time # 3 (Urschel)="))
PST.str(FStr.FloatToString(EOT3))
pst.char($0D)
pst.char($0D)

pst.str(string("----Sunrise/Sunset----"))
pst.char($0D) 
pst.str(String("Sunrise Azimuth="))
PST.str(FStr.FloatToString(sunriseaz))
pst.char($0D)
pst.str(String("Astronomical Twilight Sunrise(Clock)="))
pst.str(FStr.FloatToString(AstronomicTwilightRise))
pst.str(String(" ("))
pst.dec(s.extract_hour(AstronomicTwilightRise))
pst.str(String(":"))
if s.Extract_Minute(AstronomicTwilightRise)<10
   pst.char("0")
pst.dec(s.extract_minute(AstronomicTwilightRise))
pst.str(String(")"))
pst.char($0D)
pst.str(String("Nautical Twilight Sunrise(Clock)="))
pst.str(FStr.FloatToString(NauticalTwilightRise))
pst.str(String(" ("))
pst.dec(s.extract_hour(NauticalTwilightRise))
pst.str(String(":"))
if s.Extract_Minute(NauticalTwilightRise)<10
   pst.char("0")
pst.dec(s.extract_minute(NauticalTwilightRise))
pst.str(String(")"))
pst.char($0D)
pst.str(String("Civil Twilight Sunrise(Clock)="))
pst.str(FStr.FloatToString(CivilTwilightRise))
pst.str(String(" ("))
pst.dec(s.extract_hour(CivilTwilightRise))
pst.str(String(":"))
if s.Extract_Minute(CivilTwilightRise)<10
   pst.char("0")
pst.dec(s.extract_minute(CivilTwilightRise))
pst.str(String(")"))
pst.char($0D)
pst.str(String("Sunrise Solar Time="))
PST.str(FStr.FloatToString(sunrise))
pst.str(String(" (Local Time="))
pst.dec(s.Extract_Hour(LocalRise))
pst.char(":")
if s.Extract_Minute(LocalRise)<10
   pst.char("0")
pst.dec(s.Extract_Minute(LocalRise))

pst.str(String(")"))
pst.char($0D)
pst.char($0D)

pst.str(String("Sunset Azimuth="))
pst.str(FStr.FloatToString(sunsetaz))
pst.char($0D)
pst.str(String("Sunset Solar Time="))
pst.str(FStr.FloatToString(sunset))
pst.str(String(" (Local Time="))
pst.dec(s.Extract_Hour(LocalSet))
pst.char(":")
if s.Extract_Minute(LocalSet)<10
   pst.char("0")
pst.dec(s.Extract_Minute(LocalSet))
pst.str(String(")"))
pst.char($0D)
pst.str(String("Civil Twilight Sunset(Clock)="))
pst.str(FStr.FloatToString(CivilTwilightset))
pst.str(String(" ("))
pst.dec(s.extract_hour(CivilTwilightset))
pst.str(String(":"))
if s.Extract_Minute(CivilTwilightset)<10
   pst.char("0")
pst.dec(s.extract_minute(CivilTwilightset))
pst.str(String(")"))
pst.char($0D)
pst.str(String("Nautical Twilight Sunset(Clock)="))
pst.str(FStr.FloatToString(NauticalTwilightset))
pst.str(String(" ("))
pst.dec(s.extract_hour(NauticalTwilightset))
pst.str(String(":"))
if s.Extract_Minute(NauticalTwilightset)<10
   pst.char("0")
pst.dec(s.extract_minute(NauticalTwilightset))
pst.str(String(")"))
pst.char($0D)
pst.str(String("Astronomical Twilight Sunset(Clock)="))
pst.str(FStr.FloatToString(AstronomicTwilightset))
pst.str(String(" ("))
pst.dec(s.extract_hour(AstronomicTwilightset))
pst.str(String(":"))
if s.Extract_Minute(AstronomicTwilightset)<10
   pst.char("0")
pst.dec(s.extract_minute(AstronomicTwilightset))
pst.str(String(")"))
pst.char($0D)

'-------------Solar Noon Information---------------
  
pst.char($0D)
pst.str(string("----Solar Noon----"))
pst.char($0D) 
pst.str(String("Solar Time ="))
pst.str(FStr.FloatToString(solartime))
pst.char($0D)
pst.str(String("Local Clock Time="))
pst.str(FStr.FloatToString(LCT))
pst.str(String(" ("))
pst.dec(Clkhr)
pst.str(String(":"))
pst.dec(Clkmin)
pst.str(String(")"))
pst.char($0D)
pst.str(String("Azimuth="))
pst.str(FStr.FloatToString(Azimuth))
pst.char($0D)
pst.str(String("Hour Angle ="))
pst.str(FStr.FloatToString(HourAngle))
pst.char($0D)
pst.str(String("Altitude="))
pst.str(FStr.FloatToString(Altitude))
pst.char($0D)

'-------- Print Heliostat Info -------
pst.char($0D)
pst.str(string("----Heliostat----"))
pst.char($0D)
pst.str(String("Distance North of Target="))
pst.str(FStr.FloatToString(North))
pst.char($0D)
pst.str(String("Distance East of Target="))
pst.str(FStr.FloatToString(East))
pst.char($0D)
pst.str(String("Height up to Target="))
pst.str(FStr.FloatToString(Height))

pst.char($0D)
pst.char($0D)



'--------------Hourly Direction to Sun -------------

pst.str(string("-----Hourly Direction to the Sun-----"))
pst.char($0D)

repeat Hour from (fmath.ftrunc(localrise)*2) to 36

      '------ Date Calculations
      NDays:=fmath.ffloat(s.Day_Number(Year,Month,Day))
      EOT:=s.Equation_of_Time2(NDays)
      Declination:=s.Declination_Degrees(NDays)
       
      '-------Time Calculations
      Meridian:=s.Meridian_Calc(Longitude)
      solartime:=s.Solar_Clock_Time(fmath.fdiv(fmath.ffloat(Hour),2.0),Longitude,Meridian,EOT,DST)
      HourAngle:=s.Hour_Angle_SolarTime(SolarTime)
      ClkHr:=s.Extract_Hour(LCT)
      ClkMin:=s.Extract_Minute(LCT)

      '-------Solar Position Calculations
      Altitude:=s.Altitude_Calc (declination,Latitude,HourAngle)
      Altitude:=fmath.fadd(Altitude,s.refraction(Altitude))
      Azimuth:=s.Azimuth_Calc(Declination,Latitude,HourAngle,Altitude)

      '-------- Calculate Heliostat Vector -------
      HelioE:=s.Helio_Altitude(@HelioAz,@HelioAlt,@Theta,@Distance,Azimuth,Altitude,North,East,height)

      '---- OutputHourly Data---

     pst.str(String("Clock="))  
     pst.str(FStr.FloatToString(fmath.fdiv(fmath.ffloat(hour),2.0)))
     pst.char(",")
     if !(hour//2 ==1)
        pst.char(" ")
        pst.char(" ")
     if hour<20
        pst.char(" ")



     pst.str(String(" Altitude="))
     pst.str(FStr.FloatToString(Altitude))  
     pst.str(String(", Solar Azimuth="))
     pst.str(FStr.FloatToString(Azimuth))
     pst.char($0D)      
     pst.str(String("  Helio Azimuth="))
     pst.str(FStr.FloatToString(HelioAz))
     pst.str(String(", Helio Alt="))
     pst.str(FStr.FloatToString(HelioAlt))

     pst.str(String(", Helio Theta="))
     pst.str(FStr.FloatToString(Theta))
     pst.char($0D)  
     pst.str(String("  Refraction="))       
     pst.str(FStr.FloatToString(s.Refraction(Altitude)))
      pst.char($0D)



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