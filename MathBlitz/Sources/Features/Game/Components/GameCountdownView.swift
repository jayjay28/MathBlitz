//
//  CountdownView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct GameCountdownView: View {
    let timeRatio: Double
    let seconds: Int
    
    private var clampedRatio: Double {
        max(0, min(1, timeRatio))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let width = geo.size.width
                let progressWidth = width * clampedRatio
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                    
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(0, progressWidth))
                        .mask(
                            Capsule()
                                .frame(maxWidth: .infinity)
                        )
                        .animation(.easeInOut(duration: 0.25), value: clampedRatio)
                }
                .overlay {
                    GeometryReader { overlayGeo in
                        let travel = overlayGeo.size.width * (1 - clampedRatio)
                        
//                        Text("\(seconds)")
//                            .font(.bobaland(size: 18))
//                            .foregroundColor(.black.opacity(0.75))
//                            .padding(.horizontal, 10)
//                            .padding(.vertical, 4)
//                            .background(Color.white.opacity(0.9))
//                            .clipShape(Capsule())
//                            .padding(.trailing, 6)
//                            .frame(maxWidth: .infinity, alignment: .trailing)
//                            .offset(x: -travel)
//                            .animation(.easeInOut(duration: 0.25), value: clampedRatio)
                    }
                }
            }
            .frame(height: 16)
        }
    }
}

struct GameCountdownView_Previews: PreviewProvider {
    static var previews: some View {
        GameCountdownView(timeRatio: 0.5, seconds: 30)
            .background(Color.blue)
    }
}
