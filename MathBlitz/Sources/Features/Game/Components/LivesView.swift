//
//  LivesView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct LivesView: View {
    let totalLives: Int
    let remainingLives: Int
    let heartSize: CGFloat
    
    var body: some View {
        VStack(spacing: 8) {            
            LifeMeter(totalLives: totalLives, remainingLives: remainingLives, heartSize: heartSize)
        }
    }
}

struct LifeMeter: View {
    let totalLives: Int
    let remainingLives: Int
    let heartSize: CGFloat
    
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<totalLives, id: \.self) { index in
                Image(systemName: "heart.fill")
                    .foregroundColor(index < remainingLives ? .white : .white.opacity(0.3))
                    .font(.system(size: heartSize))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.15), in: Capsule())
    }
}

struct LivesView_Previews: PreviewProvider {
    static var previews: some View {
        LivesView(totalLives: 5, remainingLives: 3, heartSize: 14)
            .background(Color.blue)
    }
}
