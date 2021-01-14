//
//  Solar.swift
//  SolarExample
//
//  Created by Chris Howell on 16/01/2016.
//  Copyright © 2016 Chris Howell. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the “Software”), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
import Foundation
import CoreLocation

public struct Solar {
  public static let lengthOfDay: TimeInterval = 60 * 60 * 24

  /// The coordinate that is used for the calculation
  public let coordinate: CLLocationCoordinate2D
  /// The date to generate sunrise / sunset times for
  private var date: Date
  private var zenith: Zenith

  public var sunrise: Date?
  public var sunset: Date?

  /// Used for generating several of the possible sunrise / sunset times
  public enum Zenith: Double {
    case official = 90.83
    case civil = 96
    case nautical = 102
    case astronimical = 108
  }

  // MARK: Init

  public init?(for date: Date = Date(), coordinate: CLLocationCoordinate2D, and zenith: Zenith = .civil) {
    self.date = date
    self.zenith = zenith

    guard CLLocationCoordinate2DIsValid(coordinate) else {
      return nil
    }

    self.coordinate = coordinate

    // Fill this Solar object with relevant data
    calculate()
  }

  // MARK: - Public functions

  /// Sets all of the Solar object's sunrise / sunset variables, if possible.
  /// - Note: Can return `nil` objects if sunrise / sunset does not occur on that day.
  public mutating func calculate() {
    sunrise = calculate(.sunrise, for: date, and: zenith)
    sunset = calculate(.sunset, for: date, and: zenith)
  }

  // MARK: - Private functions

  fileprivate enum SunriseSunset {
    case sunrise
    case sunset
  }

  fileprivate func calculate(_ sunriseSunset: SunriseSunset, for date: Date, and zenith: Zenith) -> Date? {
    // Get the day of the year
    guard let dayInt = cal.ordinality(of: .day, in: .year, for: date) else { return nil }
    let day = Double(dayInt)

    // Convert longitude to hour value and calculate an approx. time
    let lngHour = coordinate.longitude / 15

    let hourTime: Double = sunriseSunset == .sunrise ? 6 : 18
    let t = day + ((hourTime - lngHour) / 24)

    // Calculate the suns mean anomaly
    let M = (0.9856 * t) - 3.289

    // Calculate the sun's true longitude
    let subexpression1 = 1.916 * sin(M.degreesToRadians)
    let subexpression2 = 0.020 * sin(2 * M.degreesToRadians)
    var L = M + subexpression1 + subexpression2 + 282.634

    // Normalise L into [0, 360] range
    L = normalise(L, withMaximum: 360)

    // Calculate the Sun's right ascension
    var RA = atan(0.91764 * tan(L.degreesToRadians)).radiansToDegrees

    // Normalise RA into [0, 360] range
    RA = normalise(RA, withMaximum: 360)

    // Right ascension value needs to be in the same quadrant as L...
    let Lquadrant = floor(L / 90) * 90
    let RAquadrant = floor(RA / 90) * 90
    RA = RA + (Lquadrant - RAquadrant)

    // Convert RA into hours
    RA = RA / 15

    // Calculate Sun's declination
    let sinDec = 0.39782 * sin(L.degreesToRadians)
    let cosDec = cos(asin(sinDec))

    // Calculate the Sun's local hour angle
    let cosH = (cos(zenith.rawValue.degreesToRadians) - (sinDec * sin(coordinate.latitude.degreesToRadians))) / (cosDec * cos(coordinate.latitude.degreesToRadians))

    // No sunrise
    guard cosH < 1 else {
      return nil
    }

    // No sunset
    guard cosH > -1 else {
      return nil
    }

    // Finish calculating H and convert into hours
    let tempH = sunriseSunset == .sunrise ? 360 - acos(cosH).radiansToDegrees : acos(cosH).radiansToDegrees
    let H = tempH / 15.0

    // Calculate local mean time of rising
    let T = H + RA - (0.06571 * t) - 6.622

    // Adjust time back to UTC
    var UT = T - lngHour

    // Normalise UT into [0, 24] range
    UT = normalise(UT, withMaximum: 24)

    // Calculate all of the sunrise's / sunset's date components
    let hour = floor(UT)
    let minute = floor((UT - hour) * 60.0)
    let second = (((UT - hour) * 60) - minute) * 60.0

    let shouldBeYesterday = lngHour > 0 && UT > 12 && sunriseSunset == .sunrise
    let shouldBeTomorrow = lngHour < 0 && UT < 12 && sunriseSunset == .sunset

    let setDate: Date
    if shouldBeYesterday {
      setDate = date.addingTimeInterval(-Solar.lengthOfDay)
    } else if shouldBeTomorrow {
      setDate = date.addingTimeInterval(Solar.lengthOfDay)
    } else {
      setDate = date
    }

    var components = cal.dateComponents([.day, .month, .year], from: setDate)
    components.hour = Int(hour)
    components.minute = Int(minute)
    components.second = Int(second)

    return cal.date(from: components)
  }

  /// Normalises a value between 0 and `maximum`, by adding or subtracting `maximum`
  fileprivate func normalise(_ value: Double, withMaximum maximum: Double) -> Double {
    var value = value

    if value < 0 {
      value += maximum
    } else if value > maximum {
      value -= maximum
    }

    return value
  }

}

// MARK: - Helper extensions
private extension Double {
  var degreesToRadians: Double {
    return Double(self) * (Double.pi / 180)
  }

  var radiansToDegrees: Double {
    return (Double(self) * 180) / Double.pi
  }
}
