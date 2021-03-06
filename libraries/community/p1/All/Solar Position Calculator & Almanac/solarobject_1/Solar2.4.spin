''********************************************
''*  Solar Calculator Object                 *
''*  Author: Gregg Erickson                  *
''*  December 2011                           *
''*  See MIT License for Related Copyright   *
''*  See end of file and objects for .       *
''*  related copyrights and terms of use     *
''*                                          *
''*  This uses code from FullFloat32 &       *
''*  equations and concepts from a           *
''*  version of "Solar Energy Systems        *
''*  Design" by W.B.Stine andR.W.Harrigan    *
''*  (John Wiley and Sons,Inc. 1986)         *
''*  retitled "Power From The Sun"           *
''*  http://www.powerfromthesun.net/book.html*
''********************************************

{{The solar object calculates a good approximation
of the position (altitude and azimuth) of the sun
at any time (local clock or solar) during the day
as well as events such as solar noon, sunrise,
sunset, twilight(astronomical, nautical, civil),
and daylength. Its 20+ methods also provide derived
values such as the equation of time, time meridians,
hour angle, day of the year, declination and angles
for a heliostate to reflect to a target are also provided.

Please note: The code is fully documented and is purposely less
compact than possible to allow the user to follow and/or
modify the formulas and code.

}}
{The inputs include date, local/solar time,latitude,
longitude and daylight savings time status. For Heliostat
calculations the distance (north,east,height) must also
be provided. Adjustmentsare made for value local time zones,
daylight savings time, leap year, seasonal tilt of the earth,
retrograde of earth rotation, and ecliptic earth
orbit (Perihelion,apihelion) and atmospheric refraction.

Potential Level of Error: The equations used are good
approximations adequate for small photovoltaic panels,
flat panel or direct apeture thermal collectors. A quick
check against NOAA data indicates a match within a
degree and minute.  More refinement may be needed for
concentrating collectors that focus light through a lense
or parabolic reflector. The equation of time formula
achieves an error rate of roughly 16 seconds with a max of
38 seconds. The error would need to have an average error
in the seconds of degrees and seconds of time to effectively
target the whole image on the target to a high degree of
accuracy.

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

In summary, this code is appropriate for two axis (azimuth and
altitude) or single axis (hour angle and declination) flat
panel tracking applications where accuracy within a degree
would result in negligible losses according to the
cosine effect. It would also be an effective "predictive"
complement to light sensor tracking algorims that can "hunt"
or require rapid movement during cloudy condition.  The
user should verify function, accuracy and validity of
output for any specific application.  No warranty is implied
or expressed.  Use at your own risk...

}

CON
  _clkmode = xtal1 + pll16x  '80 mhz, compensates for slow FP Math
  _XinFREQ = 5_000_000       'Can run slower to save power

Ver_Equ=  80                 'Day of Year at Vernal Equinox
Sum_Sol=  172                'Day of Year at Summer Solstice
Aut_Equ=  266                'Day of Year at Autuminal Equinox
Win_Sol=  355                'Day of Year at Winter Solstice
CivilAngle=-6.0              'Civil Twilight Occurs 0 o 6 Degrees Below the Horizon
NautAngle=-12.0              'Nautical "" "" 6 o 12 "" "" "" ""
AstroAngle=-18.0             'Astronomical"" "" 12 o 18 "" "" "" ""

VAR

'-------Angular Variables----(FP=Floating Point, I=Integer)
Long Latitude, Longitude      'FP:Latitude & Longitude of Observer,
                                  'Minutes and Seconds are expressed as fractions degrees
Long Altitude, Azimuth        'FP:Angle of Sun Above Horizon and Heading
Long SunriseAz,SunsetAz       'FP:Azimuth at Sunrise and Sunset
Long HourAngle                'FP:Angle ofSun from Noon, Due to Rotation
Long HorizonHourAngle         'FP:HourAngle at Sunset and Sunrise
Long HorizonRefraction        'FP:Angle of Atmospheric Refraction at Sunset and Sunrise
Long CivilHourAngle           'FP:Hour Angle at Civil Twilight Altitude
Long NautHourAngle            'FP:Hour Angle at Nautical Twilight Altitude
Long AstroHourAngle           'FP:Hour Angle at Astronomical Twilight Altitude
Long Declination              'FP:Tilt of Earth Relative to Solar Plain

'-------Time Variable--------(FP=Floating Point, I=Integer,B=Byte)
Long Sunrise,Sunset            'FP:Solar Time at Sunrise and Sunset
Long CivilTwilightRise         'FP Solar Time of Civil Twilight
Long CivilTwilightSet          '   with adequate light for outdoor activities
Long NauticalTwilightRise      'FP Solar Time of Nautical Twilight
Long NauticalTwilightSet       '   with light to see silhouettes & bright stars
Long AstronomicTwilightRise    'FP Solar Time of Astronomic Twilight
Long AstronomicTwilightSet     '   with dark enough sky to see all stars
Long LCT,SCT                   'FP:Local Clock Time, Solar Clock Time
Long Meridian                  'FP:Longitude of Time Zone Meridian
Long Month,Day,Year            'I :Year,Month & Day of the Year
Long NDays                     'FP:Day of Year starting with Jan 1st=1
Long Hour,Minute,Second,AMPM   'I :Local Time Hour, Min & Sec,  AM / PM designation 0=AM, 1=PM
Long SolarTime,ClockTime       'FP:Local Time in Hours Adj to Solar Noon
Long DST                       'FP:Day Light Saving Time, DST=1.0 if true
Long Daylight                  'FP:Hours of Daylight in a Day
Long EOT,EOT2,EOT3             'FP:Equation of Time, Apparent Shift in
                                  'Solar Noon Due to Earth's Orbital
                                  'Elipse from Apogee(far) to Perigee(near) 
Long ClkHr,ClkMin,ClkSec        'I :local clock in hours, minutes, seconds
Long LocalRise,LocalSet         'FP:Local Clock Time for Sunrise and Sunset
Byte DateStamp[11],TimeStamp[11]'B : Clock Date and Time



OBJ

  Fmath:"Float32Full"        'The Float32Full Version of FP Math is needed for ATAN,ACOS,ASIN
  

PUB Start    ''Initiate Solar Object

      'This can be modified to launch a cog and run calculations
      'in parallel to a main program
 
    Fmath.start   'Start Floating Point Math Object

Pub Stop     ''Stops Object

      'This can be modified in conjunction with the Start Method
      'to stop a cog that run calculations in parallel to a main program



Pub Rotation_Connecting_Rod(Radius,Shift)| a               ''Returns the Angle of a Solar Receiver Operated by a Linear Actuator Via a Connecting Rod
     'Returns a floating point angle of rotation
     'resulting when a fixed length connecting rod
     'connects a radial arm on the back of the
     'receiver to a linear actuator that is aligned
     'parallel to the face with movement toward the
     'center of receiver's axis (Like a crankshaft)
     'Radius=radius of a radial arm on the back of the face
     'Shift=linear movement along axis towards center of axis
     '      same as linear actuator change in length

     {{     Linear Actuator with Connecting Rod

                                @:Pivot Point
                               --:Plain of Axis Point(Movement Relative to This)
                               ^^:Face
                                •:Connecting Rod (Fixed Length)
                                *:Radial Arm (Output Angle Perpendicular to This)
                     @•         #:Linear Actuator (Variable Length)
                     *  •       R:Axis Point, Center of Rotation
                     *     •
                     R     --@=########=---
                     *
                     *
                 ^^^^^^^^^
     }}



     a:=fmath.fadd(fmath.degrees(fmath.asin(fmath.fdiv(Shift,Radius))),90.0)

     return a

Pub Rotation_Fixed_Linear(Radius,Length,Distance)| a,b     ''Returns the Angle of a Solar Receiver Directly Operated by a Linear Actuator
     'Returns a floating point angle of rotation
     'resulting when a variable length connecting rod
     'connects a radial arm on the back of the
     'receiver and a fixed point
     'Radius=radius of a radial arm on the back of the face
     'Length=length of linear actuator
     'Distance=linear movement along axis towards center of axis


     {{ Linear Actuator Connected to Fixed Point

                              @:Pivot Point
                             --:Plain of Axis Point(No Movement Along This)
                             ^^:Face
                              *:Radial Arm (Output Angle Perpendicular to This)
                  @=#         #:Linear Actuator (Variable Length)
                  *   #       R:Axis Point, Center of Rotation
                  *     #
                  R    ---#=@---
                  *
                  *
              ^^^^^^^^^
     }}

     a:=fmath.fadd(fmath.fmul(Radius,Radius),fmath.fmul(Distance,Distance))
     a:=fmath.fsub(a,fmath.fmul(Length,Length))

     b:=fmath.fmul(2.0,fmath.fmul(Radius,Distance))
     b:=fmath.degrees(fmath.acos(fmath.fdiv(a,b)))

     return b

Pub Get_Elevation_Loss(D)| Drop                             ''Returns Loss in Elevation Due to Earth's Curvature
       ''Returns a Floating Point Variable of the
       ''Apparent Drop in Elevation Due to  Earth Curvature
        'Where D is Distance and Drop is in Feet. This formula
        'is valid for horizontal shots at sea level, 65F and normal pressure. More
        'details can be found at http://tchester.org/sgm/analysis/peaks/refraction.html
        'by Tom Chester as a reference to the book Elementary Surveying
  
       Drop:=fmath.fmul(0.574,fmath.fmul(D,D))
          
       Return Drop
 

Pub Get_Spreading_Loss(N,P,SizePtr)| Size,Loss,a,b          ''Returns the Size of a Reflected Image Based Upon Distance and Parallax
       ''Returns Spreading Loss based upon Distance
       ' Where the mirror size N and Distance P are
       ' in the same units. The sun's angle is about 0.55 degrees
       ' This is based upon Formula 8.40 and assumes a round mirror
       ' Square and rectangle mirror losses will be slightly higher

      {{   Relative Image Size

                  |: Resulting Image in B Units (Result)
                 --: Distance of Reflection in X Units (P)
                  [: Size of Image in Angular Degrees E (0.55 for sun)
                  
                  |
                  |    P    [
              Size|---------[N (r=a)
             (r=b)|         [
                  |
       }}

        size:=fmath.tan(fmath.radians(fmath.fdiv(0.55,2.0)))
        size:=fmath.fmul(2.0,fmath.fmul(size,P))
        size:=fmath.fadd(size,n)

        a:=fmath.fdiv(N,2.0)
        a:=fmath.fmul(PI,fmath.fmul(a,a))
        b:=fmath.fdiv(size,2.0)
        b:=fmath.fmul(PI,fmath.fmul(b,b))

        Loss:=fmath.fsub(100.0,fmath.fmul(100.0,fmath.fdiv(a,b)))
        Long[SizePtr]:=size

        Return Loss


Pub Get_Cosine_Loss(Theta)|Loss                             ''Returns the loss of a Helistat due to Cosine Effect
         ''Return a Floating Point of Heliostat
         ''Lost Due to Cosine Effect as a Percent
          'Based Upon Reflected Angle in Degrees
          'See Equation 10.1
 
          Loss:=fmath.fmul(100.0,fmath.fsub(1.0,fmath.cos(fmath.radians(fmath.fdiv(Theta,2.0)))))
         '
          Return Loss

Pub Helio_Altitude(AzPtr,AltPtr,ThetaPtr,FlightPtr,Az,Alt,N,E,Z)|Rn,Re,Rz,Path,flight,AzT,AltT,altH,AzH,AzHc,AzCheck,theta,a,b,c,AzError  ''Returns Heading and Angle for a Mirror to Reflect the Sun to a Target

      ''Calculates Azimuth and Altitude (angle) above the horizon
      ''for a heliostat reflector to point to a collector point A
      'Defined by Northering (N), Easterning(E) and Height(Z),
      'The azimuth, altitude and distance of the target and
      'reflectance angle Theta are also calculated.


      'Calculate Ground Path and Air/Flight Distance to Target
      Path:=fmath.fsqr(fmath.fadd(fmath.fmul(N,N),fmath.fmul(E,E)))
      Flight:=fmath.fsqr(fmath.fadd(fmath.pow(Z,2.0),fmath.pow(path,2.0)))

      'Calculate Altitude and Azimuth of Target
      AltT:=fmath.degrees(fmath.asin(fmath.fdiv(Z,flight)))
      AzT:=fmath.fadd(180.0,fmath.degrees(fmath.asin(fmath.fdiv(E,path))))

      'Calculate Vector R Factors
      Rn:=fmath.degrees(fmath.asin(fmath.fdiv(N,flight)))
      Rn:=fmath.fadd(90.0,Rn)
      Rn:=fmath.cos(fmath.radians(Rn))
      Re:=fmath.degrees(fmath.asin(fmath.fdiv(E,flight)))
      Re:=fmath.fadd(90.0,Re)
      Re:=fmath.cos(fmath.radians(Re))
      Rz:=fmath.degrees(fmath.asin(fmath.fdiv(Z,flight)))
      Rz:=fmath.fsub(90.0,Rz)
      Rz:=fmath.cos(fmath.radians(Rz))

      'Calculate Theta
      a:=fmath.fmul(Rz,fmath.sin(fmath.radians(alt)))
      b:=fmath.fmul(Re,fmath.cos(fmath.radians(alt)))
      b:=fmath.fmul(b,fmath.sin(fmath.radians(az)))
      c:=fmath.fmul(Rn,fmath.cos(fmath.radians(alt)))
      c:=fmath.fmul(c,fmath.cos(fmath.radians(az)))
      Theta:=fmath.fadd(fmath.fadd(a,b),c)
      Theta:=fmath.fdiv(fmath.acos(Theta),2.0)
      Theta:=fmath.degrees(theta)

      'Calculate Altitude of Heliostat
      a:=fmath.fadd(fmath.sin(fmath.radians(alt)),Rz)
      b:=fmath.fmul(fmath.cos(fmath.radians(theta)),2.0)
      AltH:=fmath.degrees(fmath.asin(fmath.fdiv(a,b)))

      'Calculation Azimuth of Heliostat -- Equation 8.52
      a:=fmath.fmul(fmath.cos(fmath.radians(Alt)),fmath.sin(fmath.radians(Az)))
      a:=fmath.fadd(a,Re)
      c:=fmath.fmul(fmath.cos(fmath.radians(Theta)),fmath.cos(fmath.radians(AltH)))
      c:=fmath.fmul(c,2.0)
      AzHc:=fmath.degrees(fmath.asin(fmath.fdiv(a,c)))
      AzH:=fmath.fsub(180.0,AzHc)

      'Second Calculation Azimuth of Heliostat as Check -- Equation 8.52
      a:=fmath.fmul(fmath.cos(fmath.radians(Alt)),fmath.cos(fmath.radians(Az)))
      a:=fmath.fadd(a,Rn)
      Azcheck:=fmath.fsub(fmath.degrees(fmath.acos(fmath.fdiv(a,c))),180.0)
 
      'Compare Differences in Azimuth to Check to Trig Deviations
       AzError:=fmath.fsub(fmath.fabs(AzHc),fmath.fabs(Azcheck))


       Long[AzPtr]:=AzH        'Copy Appropriate Azimuth of Refector to Variable in Main RAM
       Long[AltPtr]:=AltH      'Copy Appropriate Altitude of Reflector to Variable in Main RAM      
       Long[ThetaPtr]:=Theta   'Copy Angle of Sun Reflection of Mirror/Target to Variable in Main RAM     
       Long[FlightPtr]:=Flight  'Copy Flight/Air Distance to Target

       return AzError           'Return Difference of Azimuth Calculated by Sine and Cose Formula
                               'as a Test or Errorcode to indicate out of range conditions

PUB Sun_Position(AzPtr,AltPtr,mo,dd,yy,hh,mm,ss,ds,lat,lng) ''Return Heading to Sun & Angle Above Horizon to a Memory Location Based Upon Time and Location  
      ''Copies a Floating Point Altitude(angle) and Azimuth to variable
      ''Designated by Pointers Using Date, Time and Location.
       'Calls other methods for interim factors such as EOT, Meridian, HourAngle,Solar
      'time, day of year and declination
      'See called methods for equations
  
       Long[AzPtr]:=Get_Azimuth(mo,dd,yy,hh,mm,ss,ds,lat,lng)    'Copy Azimuth to Variable in Main RAM
       Long[AltPtr]:=Get_Altitude(mo,dd,yy,hh,mm,ss,ds,lat,lng)  'Copy Altitude to Variable in Main RAM      

     return

PUB Get_Altitude(mo,dd,yy,hh,mm,ss,ds,lat,lng)              ''Returns Angle of the Sun Above the Horizon Based Upon Time and Location  
      ''Return Floating Point Altitude(angle) above the horizon
      'Using Date, Time and Location. Calls other methods
      'for interim factors such as EOT, Meridian, HourAngle,Solar
      'time, day of year and declination
      'See called methods for equations

      '-------Calculate Day of Year, Equation of Time, Declination
      NDays:=fmath.ffloat(Day_Number(yy,mo,dd))
      EOT:=Equation_of_Time2(NDays)
      Declination:=Declination_Degrees(NDays)

      '-------Time Calculations
      Meridian:=Meridian_Calc(Lng)
      solartime:=Solar_Clock_Time(hh,Lng,Meridian,EOT,DS)
      HourAngle:=Hour_Angle_SolarTime(SolarTime)

      '-------Solar Position Calculations
      Altitude:=Altitude_Calc (declination,Lat,HourAngle)
      Altitude:=fmath.fadd(Altitude,refraction(Altitude))
      Altitude:=fmath.fdiv(fmath.ffloat(fmath.fround(fmath.fmul(Altitude,100.0))),100.0)

      Azimuth:=Azimuth_Calc(Declination,Latitude,HourAngle,Altitude)
      Azimuth:=fmath.fdiv(fmath.ffloat(fmath.fround(fmath.fmul(Azimuth,100.0))),100.0)

      Return Altitude

PUB Get_Azimuth(mo,dd,yy,hh,mm,ss,ds,lat,lng)               ''Returns Heading To The Sun Based Upon Time and Location
      ''Return Floating Point Azimuth(heading angle)
      'Using Date, Time and Location. Calls other methods
      'for interim factors such as EOT, Meridian, HourAngle,Solar
      'time, day of year, Altitude and declination
      'See called methods for equations

      NDays:=fmath.ffloat(Day_Number(yy,mo,dd))
      EOT:=Equation_of_Time2(NDays)
      Declination:=Declination_Degrees(NDays)

      '-------Time Calculations
      Meridian:=Meridian_Calc(Lng)
      solartime:=Solar_Clock_Time(hh,Lng,Meridian,EOT,DS)
      HourAngle:=Hour_Angle_SolarTime(SolarTime)

      '-------Solar Position Calculations
      Altitude:=Altitude_Calc (declination,Lat,HourAngle)
      Altitude:=fmath.fadd(Altitude,refraction(Altitude))
      Altitude:=fmath.fdiv(fmath.ffloat(fmath.fround(fmath.fmul(Altitude,100.0))),100.0)

      Azimuth:=Azimuth_Calc(Declination,Lat,HourAngle,Altitude)
      Azimuth:=fmath.fdiv(fmath.ffloat(fmath.fround(fmath.fmul(Azimuth,100.0))),100.0)

      Return Azimuth

Pub Refraction(h)| a,b,c                               ''Returns Atmospheric Refraction/Bending (Selection of Equation)
    'This Returns the Correct Atmospheric Refraction by Calling
    'Several Methods with Formulas that Match the Range of Sun Angles
    'and the Amount of Atmosphere the Light Must Pass Through
    'Based Upon NOAA forumulas at http://www.esrl.noaa.gov/gmd/grad/solcalc/calcdetails.html

    '---Select Method Based Upon Angle---
    b:=1
    a:=fmath.fcmp(-0.575,h)
    if a==-1
       b:=2
    a:=fmath.fcmp(5.0,h)
    if a==-1
       b:=3
    a:=fmath.fcmp(85.0,h)
    if a==-1
       b:=4

    '---Call Method with Correct Formula---
    case b
      1:c:=Refraction_Neg(h)
      2:c:=Refraction_Min(h)
      3:c:=Refraction_Main(h)
      4:c:=0

    c:=fmath.fmin(0.510,c)
  
    return c    'Return Refraction from Sub-Method

Pub Refraction_Main(h)| a,b,c,d,e,f                    ''Calculate Atmospheric Refraction (Altitude 0-85 Degrees)

    a:=fmath.fdiv(1.0,3600.0)
    b:=fmath.tan(fmath.radians(h))
    c:=fmath.fdiv(58.1,b)
    d:=fmath.pow(b,3)
    d:=fmath.fdiv(0.07,d)
    e:=fmath.pow(b,5)
    e:=fmath.fdiv(0.000086,e)
    f:=fmath.fsub(c,d)
    f:=fmath.fadd(f,e)
    f:=fmath.fmul(a,f)

    return f


Pub Refraction_Min(h)| a,b,c,d,e,f                     ''Calculate Atmospheric Refraction (Altitude 0.575-5.0 Degrees)

    a:=fmath.fdiv(1.0,3600.0)
    b:=fmath.fmul(h,518.2)
    c:=fmath.pow(h,2)
    c:=fmath.fmul(c,103.4)
    d:=fmath.pow(h,3)
    d:=fmath.fmul(12.79,d)
    e:=fmath.pow(h,4)
    e:=fmath.fmul(0.711,h)
    f:=fmath.fsub(1735.0,b)
    f:=fmath.fadd(f,c)
    f:=fmath.fsub(f,d)
    f:=fmath.fadd(f,e)
    f:=fmath.fmul(a,f)

    return f


Pub Refraction_Neg(h)| a,b                             ''Calculate Atmospheric Refraction (Altitude <-0.575 Degrees)

    a:=fmath.fdiv(1.0,3600.0)
    b:=fmath.tan(fmath.radians(h))
    b:=fmath.fdiv(-20.774,b)
    b:=fmath.fmul(a,b)

    return b

Pub Scout_Time(STime,Srise,Sset)|dt,span, ScoutTime    ''Returns Date Specific Time Converted to a Scale Relative to Noon, Sunrise and Sunset
    ''This is a unique clock conversion for outdoor activities.
    ''Return a floating point hour specific to day length and relative to sunrise and sunset.
    'where 6:00 AM is always sunrise, 6:00 PM is always sunset and the length of an hour
    'changes accordingly.  All days are 12 hours long regardless of latitude with this formula.
 
    ScoutTime:=fmath.fdiv(6.0,srise)
    ScoutTime:=fmath.fmul(ScoutTime,STime)
    dt:=fmath.fcmp(srise,stime)
    if dt==-1
       ScoutTime:=fmath.fdiv(fmath.fsub(stime,12.0),fmath.fsub(12.0,Srise))
       ScoutTime:=fmath.fmul(6.0,ScoutTime)
       ScoutTime:=fmath.fadd(12.0,scoutTime)
    dt:=fmath.fcmp(sset,stime)
    if dt==-1
       ScoutTime:=fmath.fdiv(6.0,srise)
       ScoutTime:=fmath.fmul(fmath.fsub(STime,Sset),ScoutTime)
       ScoutTime:=fmath.fadd(scoutTime,18.0)
 
    return ScoutTime
 
Pub Extract_Hour(tm)|a,b                               ''Returns an Integer Hour from a Floating Point Hour
    'Return an Integer Hour from a floating
    'point hour with fractions

    a:=fmath.frac(tm)
    a:=fmath.fmul(a,60.0)
    a:=fmath.fround(a)
    b:=fmath.ftrunc(tm)

    if a==60
       a:=59

    return b

Pub Extract_Minute(tm)|a,b                             ''Returns an Integer Minute from a Floating Point Minute
    'Return an Integer Minute from a floating
    'point hour with fractions
 
    a:=fmath.frac(tm)
    a:=fmath.fmul(a,60.0)
    a:=fmath.fround(a)
    b:=fmath.ftrunc(tm)

    if a==60
       a:=59
 
    return a

Pub Solar_Time_From_AngleHour(Dy)| Time                ''Returns Solar Time from Hour Angle
    ' Equation 3.22
    ' Converts Angle Hour at Sunrise to Solar Time
    ' Returns a floating point from a floating point input

    Time:=fmath.fdiv(Dy,15.0)
    Time:=fmath.fsub(12.0,Time)

    Return Time

Pub Hour_Angle_SolarTime(Ts):Omega                     ''Returns Hour Angle for Time Solar
  'Equation 3.1
  'Calculate Angle of Earth Rotation Relative to the Number
  'of Hours Before or After Solar Noon Based upon the Spin
  'Rate of 360 Degrees over 24 hours, 15 Degrees Per Hour
 ' Returns a floating point from a floating point input

    Omega:=fmath.Fsub(Ts,12.0)
    Omega:=fmath.fmul(15.0,Omega)

  Return Omega

Pub Hour_Angle_Altitude(Delta, Lat,Alt)| a,b,c,d,e,f,g ''Returns Hour Angle Based Upon Altitude
      'Returns Hour Angle based upon Declination,
      'Latitude and Altitude

      a:=fmath.sin(fmath.radians(alt))
      b:=fmath.sin(fmath.radians(delta))
      c:=fmath.sin(fmath.radians(Lat))
      d:=fmath.cos(fmath.radians(delta))
      e:=fmath.cos(fmath.radians(Lat))
      f:=fmath.fmul(b,c)
      f:=fmath.fsub(a,f)
      g:=fmath.fmul(d,e)
      g:=fmath.fdiv(f,g)
      g:=fmath.degrees(fmath.acos(g))

      return g

Pub Azimuth_Calc(Delta,Lat,Omega,Alpha)| azi, a,b,c    ''Returns Azimuth (Compass Direction) to Sun
    'Equation 3.18  (Also could use 3.19
    'Calculates Azimuth (compass direction) to sun
    'base upon delination (Delta), latitude (Lat)
    'hour angle (Omega) and altitude (alpha)
    'Returns a floating point from a floating point input

    'Calc Azimuth Angle
    azi:=fmath.fmul(fmath.cos(fmath.radians(delta)),fmath.sin(fmath.radians(omega)))
    azi:=fmath.fmul(azi,-1.0)
    azi:=fmath.fdiv(azi,fmath.cos(fmath.radians(Alpha)))
    azi:=fmath.degrees(fmath.asin(azi))

    'Adjust Azimuth to Quadrant
    b:=fmath.fdiv(fmath.tan(fmath.radians(delta)),fmath.tan(fmath.radians(Lat)))
    a:=fmath.cos(fmath.radians(omega))
    c:=fmath.fcmp(a,b)
    Case C
      -1:Azi:=fmath.fadd(360.0,Azi)
      0,1: Azi:=fmath.fsub(180.0,Azi)

    'Subtract 360 Degrees if Needed
    c:=fmath.fcmp(360.0,Azi)
    if c==-1
       Azi:=fmath.fsub(Azi,360.0)

    Return Azi

PUB Altitude_Calc (delta,Lat,Omega)|a,b, Alpha         ''Returns Azimuth (Compass Direction) to Sun
      ' Equation 3.17
      ' Calculates angle (Altitude) above horizon based upon
      ' declination, latitude and hour angle.
      ' The Zenith (angle from straight up) is 90-Altitude
      ' Returns a floating point from a floating point input

      a:=fmath.fmul(fmath.sin(fmath.radians(delta)),fmath.sin(fmath.radians(lat)))
      b:=fmath.fmul(fmath.cos(fmath.radians(delta)),fmath.cos(fmath.radians(lat)))
      b:=fmath.fmul(b,fmath.cos(fmath.radians(omega)))
      b:=fmath.fadd(b,a)
      Alpha:=fmath.degrees(fmath.asin(b))
      return alpha

Pub DayLight_Hours(WS)|DHours                          ''Returns Daylight Hours Based Upon Angle Hours in a Day
      'Equation 3.23
      'Calculate Hours in a Day based upon Hour Angle
      'that passes at 15 degrees per hour.
      'Returns a floating point from a floating point input
      'Annual Total Aywhere on Earth=4380 Hrs
      'if you add all days together for a sigle site

      Dhours:=fmath.fdiv(fmath.fmul(Ws,2.0),15.0)

      Return DHours

Pub Solar_Clock_Time(Hr,Lng,Mrdn,ET,D)| a,b,LC,SClock  ''Returns Solar Time from Local Clock Time
'    Derived from Equation 3.5 & 3.6
'    Converts from Local Clock Time to Solar Time
   ' Returns a floating point from a floating point&Integer input
'    SClock:=hr+(EOT/60)-(lng-mrdn)/15-D
'    Adjusts for Equation of Time, Longitude, Meridian of
'    the local time zone and Daylight Savings Time.

     a:=fmath.fdiv(ET,60.0)
     b:=fmath.fsub(lng,mrdn)
     LC:=fmath.fdiv(b,15.0)

     SClock:=fmath.fadd(Hr,a)
     SClock:=fmath.fsub(SClock,LC)
     SClock:=fmath.fsub(SClock,D)

     Return SClock

Pub Local_Clock_Time(Hr,Lng,Mrdn,ET,D)| a,b,c,LC,LClock''Returns Local Clock Time from Solar Time
'    Equation 3.5 & 3.6
'    Converts from Solar Time to Local Clock Time
   ' Returns a floating point from a floating point&Integer input
'    LClock:=hr-(EOT/60)+(lng-mrdn)/15+D
'    Adjusts for Equation of Time, Longitude, Meridian of
'    the local time zone and Daylight Savings Time.

     a:=fmath.fdiv(ET,60.0)
     b:=fmath.fsub(lng,mrdn)
     LC:=fmath.fdiv(b,15.0)

     LClock:=fmath.fsub(Hr,a)
     LClock:=fmath.fadd(LClock,LC)
     LClock:=fmath.fadd(LClock,D)

     Return LClock


Pub Declination_Degrees(N)| Delta                      ''Returns Declination based upon Date
    'Equation 3.7
    'Returns a floating point from an Integer input
    'Calculates the Declination or Tilt of the Earth Relative
    'to the Plain of the Sun based upon the day of the year
'    Delta:=asin(0.39795*cos(0.98563*(N-173)))

     n:=fmath.fsub(n,173.0)
     n:=fmath.fmul(n,0.98563)
     n:=fmath.degrees(fmath.cos(fmath.radians(n)))
     n:=fmath.fmul(n,0.39795)
     Delta:=fmath.degrees(fmath.asin(fmath.radians(n)))

     return Delta


Pub Meridian_Calc(lng)|a,b                             ''Returns Time Zone Meridian
     ' Calculate the nearest meridian used for time zone
     ' Used in Equation 3.6,  Round up to 15's of degrees
     ' Returns a floating point from a floating point input

     a:=fmath.fdiv(lng,15.0)
     b:=fmath.floor(a)
     b:=fmath.fmul(b,15.0)

     return b

Pub Day_Number(Y,M,D)|N                                ''Returns Day of Year from Date
  ' Day of year including adjustment for leap year
  ' Jan 1st is N=1
  ' Table 3.1
  ' Returns an integer from an Integer input

   case m
    1:n:=D+0
    2:n:=D+31
    3:n:=D+59
    4:n:=D+90
    5:n:=D+120
    6:n:=D+151
    7:n:=D+181
    8:n:=D+212
    9:n:=D+243
    10:n:=D+273
    11:n:=D+304
    12:n:=D+334

  if ((Y//4)==0 and (m>2)) 'Add 1 day in leap years past Feb
     n:=N+1
  else
     n:=n

  return N




Pub Equation_Of_Time3(N)| a,b,c,d,e,f,g,x,z            ''Returns Urschel Equation of Time
     'Calculates Equation of Time (EOT)
     'Urschel

     a:=fmath.fsub(n,2.0)
     a:=fmath.fmul(a,0.985653)
     b:=fmath.sin(fmath.radians(a))
     b:=fmath.fmul(b,1.915169)
     b:=fmath.fadd(a,b)
     c:=fmath.fsub(a,b)
     c:=fmath.fmul(c,3.98892)   'result of c is elliptical effect
     d:=fmath.fsub(n,80.0)
     d:=fmath.fmul(d,0.985653)
     x:=d
     z:=fmath.fcmp(90.0,d)
     if z==-1
         d:=fmath.fsub(d,180.0)
     z:=fmath.fcmp(270.0,x)
     if z==-1
         d:=fmath.fsub(x,360.0)
     e:=fmath.tan(fmath.radians(d))
     e:=fmath.fmul(e,0.917408)
     e:=fmath.degrees(fmath.atan(e))              
     f:=fmath.fsub(d,e)
     f:=fmath.fmul( f,3.98892)   'result of f is tilt effect
     g:=fmath.fadd(c,f)          'result is combined elliptical and tilt effect

     return g

Pub Equation_Of_Time2(N)| a,b,c,d                      ''Returns Whitman Equation of Time
   'Calculates Equation of Time (EOT)
   'Whitman

    a:=fmath.fmul(pi,2.0)
    a:=fmath.fdiv(a,365.24)
    b:=fmath.fsub(n,172)
    a:=fmath.fmul(a,b)
    c:=fmath.fmul(a,2.0)
    c:=fmath.fadd(c,3.5884)
    a:=fmath.sin(a)
    a:=fmath.fmul(a,-0.0334)
    c:=fmath.sin(c)
    c:=fmath.fmul(c,0.04184)
    d:=fmath.fadd(a,c)
    d:=fmath.fmul(d,229.18)

    return d


Pub Equation_Of_Time(N)| a,b,c,d,e,x                   ''Returns Stein and Geyer Equation of Time
   'Calculates Equation of Time (EOT)
   'Stein and Geyer
   'Equation 3.2 and 3.3
   'Returns a floating point from an integer input

   'Calculate minutes that Solar Noon is advanced
   'or delayed due to the eliptical orbit with
   'faster speed when the earth is closest to the
   'sun (perihelion) and slower when it is furtherest
   'from the sun (aphelion). Third and fourth order
   'variations from the earth spinning at an irregular
   'rate around its axis of rotation or `wobbles´ on
   'its axis are not covered. The slower than 24 rotation
   'of the earth is address in estimating angle x

   'Adjust angle for retrograde rotation--> x:=360*(N-1)/365.242

    x:=fmath.fsub(n,1.0)
    x:=fmath.fmul(x,360.0) 
    x:=fmath.fdiv(x,365.242)

   'Calculate EOT
    a:=fmath.fmul(fmath.cos(fmath.radians(x)),0.258)
    b:=fmath.fmul(fmath.sin(fmath.radians(x)),7.416)
    c:=fmath.fmul(fmath.cos(fmath.radians(fmath.fmul(x,2.0))),3.648)
    d:=fmath.fmul(fmath.sin(fmath.radians(fmath.fmul(x,2.0))),9.228)
    e:=fmath.fsub(a,b)
    e:=fmath.fsub(e,c)
    e:=fmath.fsub(e,d)

   return e

Pub Intensity(airmassptr,directbeamptr,indirectbeamptr,alt,elevation)|airmass,insolation,indirect,ah,ah2
        {This function returns (floating point) theoretical direct beam and in direct
        irraduance in kW/M2 as well air mass. based upon the thickness of the
        atmosphere and elevation. Input is solar angle above the horizon in degrees
        (floating point) and elevation in feet (floating point) above sealevel
        This uses the formulas from Meinel AB, Meinel MP. Applied Solar Energy.; 1976 p.
        More information can be found at http://pveducation.org/pvcdrom/properties-of-sunlight/air-mass
        }



        'Airmass is the thickness of the atmosphere based upon cosine
        'of the solar angle from vertical

        airmass:=fmath.fsub(90.0,alt) ' convert altitude to theta
        airmass:=fmath.radians(airmass)    ' convert to radians for cosine calc
        airmass:=fmath.cos(airmass)       ' calc cosine of altitude
        airmass:=fmath.fdiv(1.0,airmass)   ' calc inverse of calc


        'Insolation is a measure of energy from the sun taking into account
        'the airmass and elevation

        ah:=fmath.fmul(elevation,0.0003048)     'convert elevation from feet to kilometers
        ah:=fmath.fmul(ah,0.14)                 'calculate the 'ah' factor
        ah2:=fmath.fsub(1.0,ah)

        insolation:=fmath.pow(airmass,0.678)
        insolation:=fmath.pow(0.7,insolation)
        insolation:=fmath.fmul(ah2,insolation)
        insolation:=fmath.fadd(ah,insolation)
        insolation:=fmath.fmul(1.353,insolation)

        indirect:=fmath.fmul(0.1,insolation)



        long[airmassptr]:=airmass
        long[directbeamptr]:=insolation
        long[indirectbeamptr]:=indirect

        return


Dat

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
