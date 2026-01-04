//
//  StatusBarController.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


//
//  StatusBarController.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//

import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private var usbWatcher: USBWatcher?
    private var powerWatcher: PowerWatcher?
    private var lastDevices: [USBDeviceInfo] = []
    private var lastPower: PowerAdapterDetails?
    private var refreshWorkItem: DispatchWorkItem?
    private var usbBurstWorkItem: DispatchWorkItem?
    private var usbBurstChanged = false

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        refreshNow()
        startWatchers()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "cable.connector", accessibilityDescription: "Plugged")
            ?? NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Plugged")
        image?.isTemplate = true

        button.image = image
        button.imagePosition = .imageLeft
        button.title = "0"
        button.font = NSFont.systemFont(ofSize: 13, weight: .regular)

        statusItem.menu = buildMenu()
    }

    private func startWatchers() {
        // USB connect/disconnect watcher (event-driven)
        usbWatcher = USBWatcher { [weak self] event in
            guard let self else { return }
            DispatchQueue.main.async { self.handleUSBEvent(event) }
        }
        usbWatcher?.start()

        // Power source watcher (charger wattage changes)
        powerWatcher = PowerWatcher { [weak self] oldW, newW in
            guard let self else { return }
            DispatchQueue.main.async { self.handlePowerWattsChanged(old: oldW, new: newW) }
        }
        powerWatcher?.start()
    }

    // MARK: - USB events

    private func handleUSBEvent(_ event: USBWatcher.Event) {
        switch event {
        case .connected(let dev):
            notifyUSBConnected(dev)
        case .disconnected(let dev):
            notifyUSBDisconnected(dev)
        }

        usbBurstChanged = true
        scheduleUSBSummaryNotification()

        scheduleRefresh()
    }

    private func notifyUSBConnected(_ dev: USBDeviceInfo) {
        NotificationManager.post(
            title: "USB Connected",
            subtitle: dev.name,
            body: usbDetailBody(dev),
            sound: true
        )
    }

    private func notifyUSBDisconnected(_ dev: USBDeviceInfo) {
        NotificationManager.post(
            title: "USB Disconnected",
            subtitle: dev.name,
            body: usbDetailBody(dev),
            sound: false
        )
    }

    private func usbDetailBody(_ d: USBDeviceInfo) -> String {
        var parts: [String] = []

        if let v = d.vendorID, let p = d.productID {
            parts.append(String(format: "VID:%04X PID:%04X", v, p))
        } else {
            parts.append("VID:???? PID:????")
        }

        if let s = d.speed {
            parts.append("Speed:\(s)")
        }

        return parts.joined(separator: " • ")
    }

    // MARK: - USB summary notification

    private func scheduleUSBSummaryNotification() {
        // Reset the timer every time another USB event comes in.
        usbBurstWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            self?.postUSBSummaryIfNeeded()
        }
        usbBurstWorkItem = item

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    private func postUSBSummaryIfNeeded() {
        guard usbBurstChanged else { return }
        usbBurstChanged = false

        let devices = USBEnumerator.listUSBHostDevices()
        let count = devices.count

        // The first screenshot you sent is basically:
        // “7 USB Devices connected” + a short list + “...”
        let top = devices.prefix(4).map { $0.name }
        let remaining = max(0, count - top.count)

        var body = top.joined(separator: "\n")
        if remaining > 0 { body += "\n…" }

        NotificationManager.post(
            title: "\(count) USB Devices connected",
            subtitle: nil,
            body: body,
            sound: true
        )
    }

    // MARK: - Charger notification

    private func handlePowerWattsChanged(old: Int?, new: Int?) {
        if let new {
            // Charger is present
            NotificationManager.post(
                title: "Charger Connected",
                subtitle: "\(new)W",
                body: "Negotiated \(new)W",
                sound: true
            )
        } else {
            // Charger removed. Show battery % remaining if available.
            if let pct = BatteryReader.batteryPercent() {
                let pctText = "Your device has \(pct)% left"
                
                NotificationManager.post(
                    title: "Charger Unplugged",
                    body: "\(pctText)",
                    sound: true
                )
            } else {
                NotificationManager.post(
                    title: "Charger Disconnected",
                    body: "Battery level unknown",
                    sound: true
                )
            }
        }

        scheduleRefresh()
    }

    // MARK: - Refresh / menu building

    private func scheduleRefresh() {
        refreshWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            self?.refreshNow()
        }
        refreshWorkItem = item

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }

    @objc private func refreshClicked() { refreshNow() }
    @objc private func quitClicked() { NSApp.terminate(nil) }

    private func refreshNow() {
        lastDevices = USBEnumerator.listUSBHostDevices()
        lastPower = PowerAdapterReader.read()

        statusItem.button?.title = "\(lastDevices.count)"

        // Update the dropdown menu contents
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        if let w = lastPower?.watts {
            menu.addItem(NSMenuItem(title: "Power: \(w) W", action: nil, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Power: (no adapter / unknown)", action: nil, keyEquivalent: ""))
        }

        menu.addItem(.separator())

        if lastDevices.isEmpty {
            menu.addItem(NSMenuItem(title: "No USB devices", action: nil, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "USB Devices (\(lastDevices.count)):", action: nil, keyEquivalent: ""))

            for d in lastDevices.prefix(25) {
                menu.addItem(NSMenuItem(title: niceDeviceLine(d), action: nil, keyEquivalent: ""))
            }

            if lastDevices.count > 25 {
                menu.addItem(NSMenuItem(title: "…and \(lastDevices.count - 25) more", action: nil, keyEquivalent: ""))
            }
        }

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh", action: #selector(refreshClicked), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let quit = NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func niceDeviceLine(_ d: USBDeviceInfo) -> String {
        var parts: [String] = [d.name]
        if let v = d.vendorID, let p = d.productID {
            parts.append(String(format: "VID:%04X PID:%04X", v, p))
        }
        if let s = d.speed { parts.append("Speed:\(s)") }
        return parts.joined(separator: " • ")
    }
}
