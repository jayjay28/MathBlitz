//
//  MultiplayerSessionSetupView.swift
//  MathBlitz
//
//  Created by Codex on 11/10/25.
//

import SwiftUI

struct MultiplayerSessionSetupView: View {
    @State private var sessionCode: String
    @State private var joinCode: String = ""
    @State private var activeTab: SessionTab = .host
    var onHost: (String) -> Void
    var onJoin: (String) -> Void
    var onCancel: () -> Void
    
    enum SessionTab: String, CaseIterable, Identifiable {
        case host
        case join
        
        var id: String { rawValue }
        var title: String {
            switch self {
            case .host: return "Host"
            case .join: return "Join"
            }
        }
    }
    
    init(initialCode: String = SessionCodeGenerator.newCode(),
         onHost: @escaping (String) -> Void,
         onJoin: @escaping (String) -> Void,
         onCancel: @escaping () -> Void) {
        _sessionCode = State(initialValue: initialCode)
        self.onHost = onHost
        self.onJoin = onJoin
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Multiplayer Session")
                    .font(.bobaland(size: 40))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Picker("Session Mode", selection: $activeTab) {
                    ForEach(SessionTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                
                tabContent
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onCancel)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var normalizedCode: String {
        sessionCode.uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }
    
    private var joinCodeNormalized: String {
        joinCode.uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch activeTab {
        case .host:
            hostForm
        case .join:
            joinForm
        }
    }
    
    private var hostForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite Code")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            HStack(spacing: 12) {
                TextField("ABCDE", text: $sessionCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .keyboardType(.asciiCapable)
                    .textCase(.uppercase)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                Button {
                    sessionCode = SessionCodeGenerator.newCode()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.purple)
                        .frame(width: 52, height: 52)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
            
            Button(action: { onHost(normalizedCode) }) {
                Text("Host Session")
                    .font(.bobaland(size: 24))
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }
    
    private var joinForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter Invite Code")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
            
            TextField("Enter Code", text: $joinCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .keyboardType(.asciiCapable)
                .textCase(.uppercase)
                .padding()
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            Button(action: { onJoin(joinCodeNormalized) }) {
                Text("Join Session")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(joinCodeNormalized.isEmpty ? Color.white.opacity(0.1) : Color.white.opacity(0.2))
                    .clipShape(Capsule())
            }
            .disabled(joinCodeNormalized.isEmpty)
        }
    }
}
