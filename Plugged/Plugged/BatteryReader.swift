//
//  BatteryReader.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


//
//  BatteryReader.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


import Foundation
import IOKit.ps

enum BatteryReader {
    /// Returns battery percent 0...100 if available
    static func batteryPercent() -> Int? {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for ps in list {
            guard
                let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any]
            else { continue }

            // Only internal battery
            let isBattery = (desc[kIOPSTransportTypeKey as String] as? String) == kIOPSInternalType
            if !isBattery { continue }

            if let cur = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let max = desc[kIOPSMaxCapacityKey as String] as? Int,
               max > 0 {
                return Int((Double(cur) / Double(max) * 100.0).rounded())
            }

            // expose a direct percent
            if let pct = desc["Current Capacity"] as? Int {
                return pct
            }
        }

        return nil
    }
}
