//
//  OpenWeather.swift
//  hap-server
//

import Foundation
import func Evergreen.getLogger

fileprivate let logger = getLogger("openweather")

public class OpenWeather {

    public var temperature: Float {
        update()
        return _temperature
    }

    public var humidity: Int {
        update()
        return _humidity
    }

    public enum Units: String {
        case imperial
        case metric
    }

    // swiftlint:disable identifier_name
    public struct Measurement: Decodable {
        let temp: Float
        let pressure: Int
        let humidity: Int
        let temp_min: Int?
        let temp_max: Int?
    }
    public struct OpenWeatherResponse: Decodable {
        let main: Measurement
        let name: String
    }

    let appid: String
    let name: String
    let lat: String
    let lon: String
    let units: Units

    private var _temperature: Float = 0.0
    private var _humidity: Int = 50

    private let decoder = JSONDecoder()

    private let limit: TimeInterval = 900 // 15 Minutes
    private var lastExecutedAt: Date?
    private let updateQueue = DispatchQueue(label: "openweather", attributes: [])

    private var observers = [(OpenWeather) -> Void]()

    public init(name: String, lat: Double, lon: Double, appid: String, units: Units = .metric) {
        precondition((lat >= -90.0) && (lat <= 90.0), "Latitude \(lat) is out of range")
        precondition((lon >= -180.0) && (lon <= 180.0), "Longitude \(lon) is out of range")

        self.name = name
        self.appid = appid
        self.lat = "\(lat)"
        self.lon = "\(lon)"
        self.units = units

        self.update()
    }

    public func whenUpdated(closure: @escaping (OpenWeather) -> Void) {
        observers.append(closure)
    }

    func update() {
        updateQueue.async {
            let now = Date()

            // Lookup last executed
            let timeInterval = now.timeIntervalSince(self.lastExecutedAt ?? .distantPast)

            // Only refresh the values if the last request was older than 'limit'
            if timeInterval > self.limit {
                // Record execution
                self.lastExecutedAt = now

                self.updateNow()
            }
        }
    }

    func updateNow() {

        var urlQuery = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")!
        urlQuery.queryItems = [
            URLQueryItem(name: "lat", value: lat),
            URLQueryItem(name: "lon", value: lon),
            URLQueryItem(name: "APPID", value: appid),
            URLQueryItem(name: "units", value: units.rawValue)]

        let url = urlQuery.url!
        logger.debug("URL: \(url)")

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                logger.debug("OpenWeather connection error \(error)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode) else {
                    logger.debug("OpenWeather Server error \(response)")
                    return
            }

            if let mimeType = httpResponse.mimeType, mimeType == "application/json",
                let data = data,
                let weatherReport = try? self.decoder.decode(OpenWeatherResponse.self, from: data) {

                DispatchQueue.main.sync {
                    self._temperature = weatherReport.main.temp
                    self._humidity = weatherReport.main.humidity
                    for observer in self.observers {
                        observer(self)
                    }
                }

            }
        }
        task.resume()

    }

}
