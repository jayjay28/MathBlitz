import SwiftUI

struct CardView: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
//            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
//            .overlay(
//                RoundedRectangle(cornerRadius: 10)
//                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
//            )
    }
}
