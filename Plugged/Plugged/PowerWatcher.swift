//
//  PowerWatcher.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


//
//  PowerWatcher.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


import Foundation
import IOKit.ps

final class PowerWatcher {
    private var runLoopSource: CFRunLoopSource?
    private var lastWatts: Int? = nil
    private let onWattsChanged: (_ old: Int?, _ new: Int?) -> Void

    init(onWattsChanged: @escaping (_ old: Int?, _ new: Int?) -> Void) {
        self.onWattsChanged = onWattsChanged
    }

    func start() {
        let callback: IOPowerSourceCallbackType = { context in
            let watcher = Unmanaged<PowerWatcher>.fromOpaque(context!).takeUnretainedValue()
            watcher.handlePowerChange()
        }

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        if let src = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() {
            runLoopSource = src
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        }

        // Initial read
        handlePowerChange()
    }

    func stop() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
        }
        runLoopSource = nil
    }

    private func handlePowerChange() {
        let newWatts = PowerAdapterReader.read()?.watts
        if newWatts != lastWatts {
            let old = lastWatts
            lastWatts = newWatts
            onWattsChanged(old, newWatts)
        }
    }
}
