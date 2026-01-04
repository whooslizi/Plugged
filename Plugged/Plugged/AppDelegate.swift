//
//  AppDelegate.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


//
//  AppDelegate.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//

import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Request permission
        NotificationManager.configure()

        statusBarController = StatusBarController()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
