//
//  OpenWeatherThermometer.swift
//  hap-server
//
//  Created by Guy Brooker on 03/10/2018.
//

import Foundation
import HAP
import func Evergreen.getLogger

fileprivate let logger = getLogger("openweather")

extension Accessory {

    open class OpenWeatherThermometer: Thermometer {

        let weather: OpenWeather

        public let humiditySensor = Service.HumiditySensor()

        public init(_ openWeatherLocation: OpenWeather) {
            weather = openWeatherLocation

            super.init(info: .init(name:openWeatherLocation.name,
                                   serialNumber:openWeatherLocation.name,
                                   manufacturer:"Open Weather",
                                   model:"API",
                                   firmwareRevision: "1.0"),
                       additionalServices: [humiditySensor]
            )

            delegate = self

            getLogger("openweather").logLevel = .debug

            weather.whenUpdated(closure: { weatherLocation in
                self.temperatureSensor.currentTemperature.value = weatherLocation.temperature
                self.humiditySensor.currentRelativeHumidity.value = Float(weatherLocation.humidity)
            })
            updateState()
        }

        func updateState() {
            didGetCurrentTemperature(self.weather.temperature)
        }

        func didGetCurrentTemperature(_ currentTemp: Float?) {
            weather.update()
        }
    }
}

extension Accessory.OpenWeatherThermometer: AccessoryDelegate {

    /// Characteristic's value was changed by controller. Used for notifying
    public func characteristic<T>(
        _ characteristic: GenericCharacteristic<T>,
        ofService: Service,
        didChangeValue: T?) {}

    /// Characteristic's value was observed by controller. Used for lazy updating
    public func characteristic<T>(
        _ characteristic: GenericCharacteristic<T>,
        ofService: Service,
        didGetValue value: T?) {
        switch characteristic.type {
        case .currentTemperature:
            // swiftlint:disable:next force_cast
            didGetCurrentTemperature(value as! Float?)
        default:
            break
        }
    }
}
