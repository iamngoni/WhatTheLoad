//
//  WhatTheLoadApp.swift
//  WhatTheLoad
//
//  Created by Ngonidzashe  Mangudya on 2026/02/13.
//

import SwiftUI

@main
struct WhatTheLoadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
