//
//  CountdownView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct GameCountdownView: View {
    let timeRatio: Double
    let rawTimeRemaining: Double // Change to Double
    
    private var clampedRatio: Double {
        max(0, min(1, timeRatio))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(format: "%", max(0.0, rawTimeRemaining)))
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 60, alignment: .leading) // Fixed width for the text
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))

                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: geo.size.width * clampedRatio)
                        .animation(.easeInOut(duration: 0.25), value: clampedRatio)
                }
            }
            .frame(height: 16)
            .clipShape(Capsule())

            
        }
    }
}

struct GameCountdownView_Previews: PreviewProvider {
    static var previews: some View {
        GameCountdownView(timeRatio: 0.5, rawTimeRemaining: 30.56) // Update preview
            .background(Color.blue)
    }
}
