import SwiftUI

struct BackChevronButton: View {
    @Environment(\.dismiss) private var dismiss
    var action: (() -> Void)?
    
    var body: some View {
        Button(action: {
            if let action {
                action()
            } else {
                dismiss()
            }
        }) {
            Text("< Back")
                .font(.bobaland(size: 28))
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
    }
}
