//
//  USBWatcher.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


//
//  Plugged.swift
//  USBDetector
//
//  Created by Hodaka on 4/1/26.
//


import Foundation
import IOKit

final class USBWatcher {
    enum Event {
        case connected(USBDeviceInfo)
        case disconnected(USBDeviceInfo)
    }

    private var notifyPort: IONotificationPortRef?
    private var runLoopSource: CFRunLoopSource?
    private var addedIter: io_iterator_t = 0
    private var removedIter: io_iterator_t = 0

    private var lastDevicesByLocation: [Int: USBDeviceInfo] = [:]
    private let onEvent: (Event) -> Void

    init(onEvent: @escaping (Event) -> Void) {
        self.onEvent = onEvent
    }

    func start() {
        refreshSnapshot()

        notifyPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notifyPort else { return }

        runLoopSource = IONotificationPortGetRunLoopSource(notifyPort).takeUnretainedValue()
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        }

        // CONNECTED
        let addedCallback: IOServiceMatchingCallback = { refcon, iterator in
            let watcher = Unmanaged<USBWatcher>.fromOpaque(refcon!).takeUnretainedValue()
            watcher.handleAdded(iterator: iterator)
        }

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let matchingDict1 = IOServiceMatching("IOUSBHostDevice")

        IOServiceAddMatchingNotification(
            notifyPort,
            kIOFirstMatchNotification,
            matchingDict1,
            addedCallback,
            selfPtr,
            &addedIter
        )
        handleAdded(iterator: addedIter) // drain existing

        // DISCONNECTED
        let removedCallback: IOServiceMatchingCallback = { refcon, iterator in
            let watcher = Unmanaged<USBWatcher>.fromOpaque(refcon!).takeUnretainedValue()
            watcher.handleRemoved(iterator: iterator)
        }

        let matchingDict2 = IOServiceMatching("IOUSBHostDevice")
        IOServiceAddMatchingNotification(
            notifyPort,
            kIOTerminatedNotification,
            matchingDict2,
            removedCallback,
            selfPtr,
            &removedIter
        )
        handleRemoved(iterator: removedIter) // drain existing
    }

    func stop() {
        if addedIter != 0 { IOObjectRelease(addedIter); addedIter = 0 }
        if removedIter != 0 { IOObjectRelease(removedIter); removedIter = 0 }

        if let rl = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), rl, .defaultMode)
        }
        runLoopSource = nil

        if let np = notifyPort {
            IONotificationPortDestroy(np)
        }
        notifyPort = nil
    }

    private func refreshSnapshot() {
        let list = USBEnumerator.listUSBHostDevices()
        var map: [Int: USBDeviceInfo] = [:]
        for d in list {
            if let loc = d.locationID {
                map[loc] = d
            }
        }
        lastDevicesByLocation = map
    }

    private func handleAdded(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            let props = USBEnumerator.readAllPropertiesDirect(service: service)
            let device = USBEnumerator.deviceInfoFromProperties(props)

            if let loc = device.locationID {
                lastDevicesByLocation[loc] = device
            }

            onEvent(.connected(device))
        }
    }

    private func handleRemoved(iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }

            let props = USBEnumerator.readAllPropertiesDirect(service: service)
            let loc = props["locationID"] as? Int

            if let loc, let known = lastDevicesByLocation[loc] {
                lastDevicesByLocation.removeValue(forKey: loc)
                onEvent(.disconnected(known))
            } else {
                // If mapping fails, refresh snapshot and skip detailed disconnect info
                refreshSnapshot()
            }
        }
    }
}
