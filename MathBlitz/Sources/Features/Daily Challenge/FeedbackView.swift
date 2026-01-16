import SwiftUI

struct FeedbackView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    let isCorrect: Bool
    let explanation: String?
    let onContinue: () -> Void

    private static let wittyResponses = [
        "BOOM! I knew you had it in you! (pause)",
        "That's what I'm talkin' about!",
        "CORRECT! You out here makin' moves! Let's go!",
        "You see that? That's what happens when you focus! Nailed it!",
        "Ayyyye! That's the one! You a mini-me, a real genius!",
        "Heh?! You got it! I wasn't worried. Nah, not for a second!",
        "Incredible! You smarter than you look! I'm playin', I'm playin'!",
        "That's right! You better let 'em know! You got the brains!",
        "Look at you! You a star! A real math star! Woo!",
        "That's it! You didn't even break a sweat! Or did you? Little bit?",
        "Okay, okay! I see you! That's a correct answer right there!",
        "You a beast! That's what you are! A math beast!",
        "Yessir! That's how you do it! Keep that energy up!",
        "You got it! I'm tellin' you, we a team! We got this!",
        "Flawless! You ain't messin' around today! I like it!"
    ]

    private var feedbackText: String {
        if isCorrect {
            return FeedbackView.wittyResponses.randomElement() ?? "Correct!"
        } else {
            return "Not Quite"
        }
    }
    
    private var isRegularSizeClass: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        ZStack {
            RadialGradient(colors: [.purple, .purple], center: .center, startRadius: 80, endRadius: 500)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                if isCorrect {
                    Spacer()
                }
                
                Text(feedbackText)
                    .font(.bobaland(size:28))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .modifier(CardView())
                    .accessibilityLabel(isCorrect ? "Correct" : "Not Quite")

                if let explanation = explanation, !isCorrect {
                    ExplanationView(explanation: explanation, isRegular: isRegularSizeClass)
                }

                Spacer()

                ContinueButton(onContinue: onContinue)
            }
            .padding(.horizontal)
            .padding(.vertical, isRegularSizeClass ? 60 : 40)
        }
    }
}

private struct ExplanationView: View {
    let explanation: String
    let isRegular: Bool

    var body: some View {
        ScrollView {
            Text(explanation)
                .font(isRegular ? .title2 : .body)
                .multilineTextAlignment(isRegular ? .center : .leading)
                .foregroundColor(.white)
                .padding(isRegular ? 30 : 15)
                .frame(maxWidth: .infinity)
        }
        .modifier(CardView())
        .frame(maxHeight: isRegular ? 400 : 300)
    }
}


private struct ContinueButton: View {
    let onContinue: () -> Void

    var body: some View {
        Button(action: onContinue) {
            HStack {
                Text("Continue")
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right.circle.fill")
            }
            .font(.title2)
            .padding()
            .frame(maxWidth: .infinity)
            .foregroundColor(.purple)
            .background(Color.white)
            .cornerRadius(15)
        }
        .accessibilityLabel("Continue")
        .accessibilityHint("Proceed to the next screen.")
    }
}

struct FeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FeedbackView(isCorrect: true, explanation: nil) {
                print("Continue action for correct answer")
            }
            .previewDisplayName("Correct Answer Feedback - iPhone")

            FeedbackView(isCorrect: false, explanation: "The correct answer was 42. You need to multiply the numbers, not add them.") {
                print("Continue action for incorrect answer")
            }
            .previewDisplayName("Incorrect Answer Feedback - iPhone")
            
            FeedbackView(isCorrect: false, explanation: "The correct answer was 42. You need to multiply the numbers, not add them.") {
                print("Continue action for incorrect answer")
            }
            .previewDevice("iPad Pro (12.9-inch) (6th generation)")
            .previewDisplayName("Incorrect Answer Feedback - iPad")
        }
    }
}
