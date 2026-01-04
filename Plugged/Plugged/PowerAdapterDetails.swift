//
//  PowerAdapterDetails.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


//
//  PowerAdapterReader.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//

import Foundation
import IOKit.ps

struct PowerAdapterDetails {
    let watts: Int?
    let voltage_mV: Int?
    let current_mA: Int?
    let raw: [String: Any]
}

enum PowerAdapterReader {
    private static let voltageKey = "Voltage"
    private static let currentKey = "Current"

    static func read() -> PowerAdapterDetails? {
        guard let cfDict = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() else {
            return nil
        }
        let dict = (cfDict as NSDictionary) as? [String: Any] ?? [:]

        let watts = dict[kIOPSPowerAdapterWattsKey as String] as? Int
        let voltage = dict[voltageKey] as? Int
        let current = dict[currentKey] as? Int

        return PowerAdapterDetails(watts: watts, voltage_mV: voltage, current_mA: current, raw: dict)
    }
}
