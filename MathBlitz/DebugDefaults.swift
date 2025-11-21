//
//  DebugDefaults.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import Foundation

enum DebugDefaults {
    static let forceOnboardingOnLaunchKey = "Debug.forceOnboardingOnLaunch"
    static let enableTestGameStartNotifierKey = "Debug.enableTestGameStartNotifier"
    
    static var isTestGameStartNotifierEnabled: Bool {
#if DEBUG
        if UserDefaults.standard.object(forKey: enableTestGameStartNotifierKey) == nil {
            UserDefaults.standard.set(true, forKey: enableTestGameStartNotifierKey)
        }
        return UserDefaults.standard.bool(forKey: enableTestGameStartNotifierKey)
#else
        return false
#endif
    }
}
