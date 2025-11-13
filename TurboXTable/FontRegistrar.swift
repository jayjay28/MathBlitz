//
//  FontRegistrar.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI
import CoreText

enum FontRegistrar {
    private static var hasRegistered = false
    private static let fontResources: [(name: String, ext: String)] = [
        ("Bobaland", "ttf")
    ]

    static func registerCustomFonts() {
        guard !hasRegistered else { return }
        defer { hasRegistered = true }

        for resource in fontResources {
            registerFont(named: resource.name, extension: resource.ext)
        }
    }

    private static func registerFont(named name: String, extension ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            #if DEBUG
            print("⚠️ Missing font resource: \\(name).\\(ext)")
            #endif
            return
        }

        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !success {
            #if DEBUG
            if let error = error?.takeRetainedValue() {
                print("⚠️ Font registration failed for \\(name): \\(error)")
            }
            #endif
        }
    }
}
