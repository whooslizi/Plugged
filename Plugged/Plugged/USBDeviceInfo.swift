//
//  USBDeviceInfo.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


//
//  USBEnumerator.swift
//  USBDetector
//
//  Created by Hodaka on 4/1/26.
//

import Foundation
import IOKit

struct USBDeviceInfo: Identifiable {
    let id = UUID()
    let name: String
    let vendorID: Int?
    let productID: Int?
    let locationID: Int?
    let speed: String?
    let bcdUSB: Int?
    let raw: [String: Any]
}

enum USBEnumerator {

    static func listUSBHostDevices() -> [USBDeviceInfo] {
        var results: [USBDeviceInfo] = []

        guard let matchingDict = IOServiceMatching("IOUSBHostDevice") else {
            return results
        }

        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard kr == KERN_SUCCESS else { return results }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            let props = readAllPropertiesDirect(service: service)
            results.append(deviceInfoFromProperties(props))
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // Used by USBWatcher
    static func readAllPropertiesDirect(service: io_registry_entry_t) -> [String: Any] {
        var props: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let dict = props?.takeRetainedValue() else {
            return [:]
        }
        return (dict as NSDictionary) as? [String: Any] ?? [:]
    }

    // Used by USBWatcher
    static func deviceInfoFromProperties(_ props: [String: Any]) -> USBDeviceInfo {
        let productName =
            (props["USB Product Name"] as? String) ??
            (props["Product"] as? String) ??
            (props["kUSBProductString"] as? String) ??
            "Unknown USB Device"

        let vid = props["idVendor"] as? Int
        let pid = props["idProduct"] as? Int
        let loc = props["locationID"] as? Int
        let bcdUSB = props["bcdUSB"] as? Int

        let speedStr: String? = {
            if let s = props["Device Speed"] as? String { return s }
            if let n = props["Device Speed"] as? Int { return mapSpeed(n) }
            if let n = props["Speed"] as? Int { return mapSpeed(n) }
            if let s = props["Speed"] as? String { return s }
            return nil
        }()

        return USBDeviceInfo(
            name: productName,
            vendorID: vid,
            productID: pid,
            locationID: loc,
            speed: speedStr,
            bcdUSB: bcdUSB,
            raw: props
        )
    }

    private static func mapSpeed(_ n: Int) -> String {
        switch n {
        case 0: return "Unknown"
        case 1: return "Low"
        case 2: return "Full"
        case 3: return "High"
        case 4: return "Super"
        case 5: return "Super+"
        default: return "(\(n))"
        }
    }
}
