//
//  LoadingView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(.white)
            
            Text("Loading…")
                .font(.bobaland(size: 36))
                .foregroundColor(.white)
            
            Text("Getting things ready.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        )
    }
}
