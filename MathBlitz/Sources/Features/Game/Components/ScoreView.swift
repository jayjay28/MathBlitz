//
//  ScoreView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct ScoreView: View {
    let currentScore: Int
    let highScore: Int
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(currentScore)")
                .font(.bobaland(size: 28))
                .foregroundColor(.white)
                .scaleEffect(isAnimating ? 1.3 : 1.0)
                .onChange(of: currentScore) { _ in
                    isAnimating = false
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                        isAnimating = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            isAnimating = false
                        }
                    }
                }
            Text("|")
            if highScore > 0 {
                Text("\(highScore)")
                    .font(.bobaland(size: 28))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 18)
//        .padding(.vertical, 10)
    }
}

struct ScoreView_Previews: PreviewProvider {
    static var previews: some View {
        ScoreView(currentScore: 100, highScore: 200)
            .background(Color.blue)
    }
}
