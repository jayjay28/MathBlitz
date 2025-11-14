//
//  MathBlitzApp.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

@main
struct MathBlitzApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState
    
    init() {
        FontRegistrar.registerCustomFonts()
        FirebaseManager.shared.configure()
        _appState = StateObject(wrappedValue: AppState())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
