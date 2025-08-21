//
//  LanePaceApp.swift
//  LanePace
//
//  Created by Christian Hemker on 21.08.25.
//

import SwiftUI
import SwiftData

@main
struct LanePaceApp: App {
    @StateObject private var timerViewModel = IntervalTimerViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(timerViewModel)
        }
        .modelContainer(for: [Athlete.self, Session.self, Split.self, AppSettings.self])
    }
}
