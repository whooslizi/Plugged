//
//  PluggedApp.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//


//
//  PluggedApp.swift
//  Plugged
//
//  Created by Hodaka on 4/1/26.
//

import SwiftUI

@main
struct PluggedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu-bar only app (no window)
        Settings { EmptyView() }
    }
}
