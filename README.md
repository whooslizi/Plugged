# Plugged

![Plugged icon](https://github.com/user-attachments/assets/93673a3e-a6b3-4ac3-b778-a11a4333043d)

**Ports Gone Wild**

## What is this

Plugged is a tiny macOS menu-bar app that watches what you plug into your Mac and tells you when something changes.

- Plug in a charger? It shows the wattage.
- Unplug it? It tells you how much battery you’ve got left.
- Connect a dock or USB device? You get a quick heads-up about what just appeared.
<img width="349" height="87" alt="image" src="https://github.com/user-attachments/assets/aa025f8a-b5c2-4070-94a9-53d253e97b88" />

## How it works

Plugged is fully event-driven. It does not poll or continuously scan the system.
Instead, it listens for low-level macOS system events and reacts immediately
when something changes.

### USB events (connect / disconnect)

USB device changes are handled using IOKit and the I/O Registry.

Plugged registers for USB notifications by matching IOUSBHostDevice services:

- IOServiceMatching("IOUSBHostDevice")
  Creates a matcher for USB devices in the I/O Registry.

- IOServiceAddMatchingNotification(...)
  Registers callbacks for when matching USB services appear or disappear.

- IOIteratorNext(...)
  Iterates over devices that triggered the notification.

- IORegistryEntryCreateCFProperty(...)
  Reads device properties such as:
  - product name
  - vendor ID (VID)
  - product ID (PID)
  - connection speed

When a device is plugged in or unplugged, macOS immediately triggers the callback.
Plugged extracts the device information and updates:
- the menu-bar device list
- user notifications

No polling is used. All USB updates are event-based.

### Power events (charger / wattage / battery)

Power changes are monitored using the Power Sources API from IOKit.

- IOPSCopyPowerSourcesInfo()
  Takes a snapshot of the current power source state.

- IOPSCopyPowerSourcesList(...)
  Lists available power sources (battery, external power).

- IOPSGetPowerSourceDescription(...)
  Reads details such as:
  - charging state
  - current capacity
  - maximum capacity
  - power source type

Charger wattage is read from adapter-related system properties through a small
wrapper around IOKit power information.

When the power state changes:
- Charger connected → negotiated wattage is shown
- Charger disconnected → remaining battery percentage is shown

### Notifications

User notifications are delivered using UserNotifications.

- UNUserNotificationCenter.requestAuthorization(...)
  Requests notification permission once.

- UNUserNotificationCenter.add(...)
  Posts notifications for:
  - USB device changes
  - dock / hub connection bursts
  - charger connect / disconnect events

To ensure notifications appear even while the app is active:
- userNotificationCenter(_:willPresent:) returns .banner

### Menu bar UI

The menu bar interface is built using standard AppKit APIs:

- NSStatusBar.system.statusItem(...)
- NSMenu for the dropdown menu
- statusItem.button for icon and title updates

The app runs as a menu-bar agent only:
- LSUIElement = true

This prevents Dock icons, windows, and app-switcher entries.

