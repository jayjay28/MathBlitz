//
//  FirebaseManager.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import FirebaseCore

final class FirebaseManager {
    static let shared = FirebaseManager()
    private var isConfigured = false
    
    private init() {}
    
    func configure() {
        guard !isConfigured else { return }
        FirebaseApp.configure()
        isConfigured = true
    }
}
