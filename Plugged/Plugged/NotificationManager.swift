//
//  NotificationManager.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


//
//  NotificationManager.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


import Foundation
import UserNotifications

enum NotificationManager {

    static func configure() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error { print("Notification auth error:", error) }
            print("Notification granted:", granted)
        }
    }

    static func post(title: String, subtitle: String? = nil, body: String, sound: Bool = true) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle { content.subtitle = subtitle }
        content.body = body
        if sound { content.sound = .default }

        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { err in
            if let err { print("Notification post error:", err) }
        }
    }
}
