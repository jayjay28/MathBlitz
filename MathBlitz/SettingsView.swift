//
//  SettingsView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State var profile: PlayerProfile
    let onSave: (PlayerProfile) -> Void
    let onSignOut: () -> Void
    
    @State private var showingEmojitarEditor = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Player").font(.system(size: 20, weight: .bold, design: .rounded))) {
                    TextField("Display Name", text: $profile.displayName)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                }
                
                Section(header: Text("Emojitar").font(.system(size: 20, weight: .bold, design: .rounded))) {
                    HStack(spacing: 16) {
                        EmojitarBadge(
                            emoji: profile.emojitar.emoji,
                            color: profile.emojitar.color,
                            size: .lg,
                            ring: true
                        )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.emojitar.emoji)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text(profile.emojitar.colorHex)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Customize") {
                            showingEmojitarEditor = true
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Difficulty").font(.system(size: 20, weight: .bold, design: .rounded))) {
                    Picker("Mode", selection: $profile.preferredMode) {
                        ForEach(GameMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section {
                    Button(role: .destructive) {
                        onSignOut()
                        dismiss()
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(profile)
                        dismiss()
                    }
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: { dismiss() })
                }
            }
            .sheet(isPresented: $showingEmojitarEditor) {
                OnboardingEmojitarView(emojitar: $profile.emojitar) { updated in
                    profile.emojitar = updated
                    showingEmojitarEditor = false
                }
                .padding(.top, 24)
                .background(
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea()
                )
            }
        }
    }
}
