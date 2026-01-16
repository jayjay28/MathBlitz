import SwiftUI

// MARK: - Result View for Carousel
struct ChallengeResultView: View {
    let challenge: Challenge
    let userAnswer: String
    let isCorrect: Bool
    
    @State private var isPromptExpanded = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Your Answer:")
                            .font(.headline)
                        Text(userAnswer)
                            .font(.headline)
                            .foregroundColor(isCorrect ? .green : .red)
                    }
                    HStack {
                        Text("Correct Answer:")
                            .font(.headline)
                        Text(String(format: "%.0f", challenge.correct_answer))
                            .font(.headline)
                    }
                    
                    Divider()
                    Spacer()
                    
                    Text("Question")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding([.bottom, .top], 10)
                    
                    
                    Text(challenge.prompt)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .lineLimit(isPromptExpanded ? nil : 3)
                    
                    Button(action: {
                        withAnimation {
                            isPromptExpanded.toggle()
                        }
                    }) {
                        Text(isPromptExpanded ? "Show Less" : "Show More")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.top, 1)
                    }
                    
                    Spacer()
                    Divider()
                    
                    VStack(alignment: .leading) {
                        Text("Explanation")
                            .foregroundColor(.black)
                            .fontWeight(.bold)
                            .padding(.bottom, 10)
                        
                        Text(challenge.explanation)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.top)
                }
             
                
                
            }
            .padding()
            .modifier(CardView())
        }
    }
}

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct ChallengeResultView_Previews: PreviewProvider {
    static var previews: some View {
        let mockChallenge = Challenge(
            title: "Math Problem",
            difficulty: "Easy",
            tags: ["Addition"],
            date_scheduled: "2025-12-19",
            prompt: "You are a senior ui/ux designer who is great at making sure views are readable and clean. Investigate the daily challenge views because some of these views display a lot of text. We want this to be aligned and spaced in a way that makes it easy for users to read the questions. You also want to make sure the views are cohesive in design and feel.",
            answer_type: "Number",
            correct_answer: 25,
            time_limit_seconds: 30,
            numpad: Challenge.NumpadConfig(max_digits: 3, allow_negative: false, allow_decimal: false),
            multiple_choice: Challenge.MultipleChoiceConfig(enabled: false, choices: [], correct_choice_index: 0),
            scoring: Challenge.ScoringConfig(base_points: 100),
            explanation: "To find the sum, you add the numbers together."
        )

        Group {
            ChallengeResultView(challenge: mockChallenge, userAnswer: "25", isCorrect: true)
                .previewDisplayName("Correct Answer - iPhone")
                .previewDevice("iPhone 15 Pro")

            ChallengeResultView(challenge: mockChallenge, userAnswer: "20", isCorrect: false)
                .previewDisplayName("Incorrect Answer - iPhone")
                .previewDevice("iPhone 15 Pro")
            
            ChallengeResultView(challenge: mockChallenge, userAnswer: "25", isCorrect: true)
                .previewDisplayName("Correct Answer - iPad")
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")

            ChallengeResultView(challenge: mockChallenge, userAnswer: "20", isCorrect: false)
                .previewDisplayName("Incorrect Answer - iPad")
                .previewDevice("iPad Pro (12.9-inch) (6th generation)")
        }
    }
}
