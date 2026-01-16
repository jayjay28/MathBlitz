//
//  TodaysChallengeView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 12/4/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import Lottie
import UIKit // Added for haptics

struct TodaysChallengeView: View {
    
    struct ChallengeState {
        var challenges: [Challenge] = []
        var currentStage = 0
        var showSummary = false
        var showFeedback = false
        var lastAnswerIsCorrect: Bool? = nil
        var showCelebration = false
        var userAnswer: String = ""
        var selectedChoiceIndex: Int? = nil
        var correctAnswers = 0
        var submittedAnswers: [String] = []
        var results: [Bool] = []
        var timeRemaining: Double = 0
        var questionTimer: Timer?
        var timerWorkItem: DispatchWorkItem?
    }
    
    @State private var state = ChallengeState()
    
    // Haptics
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    var onComplete: (Int, Int) -> Void
    
    var body: some View {
        ZStack {
            RadialGradient(colors: [.black, .purple], center: .center, startRadius: 80, endRadius: 500)
                .ignoresSafeArea()
            
            if state.showSummary {
                SummaryCarouselView(
                    challenges: state.challenges,
                    correctAnswers: state.correctAnswers,
                    submittedAnswers: state.submittedAnswers,
                    results: state.results,
                    onComplete: {
                        onComplete(state.correctAnswers, state.challenges.count)
                        dismiss()
                    }
                )
            } else if state.challenges.isEmpty {
                loadingView
            } else if state.currentStage < state.challenges.count {
                ChallengePlayerView(
                    challenge: state.challenges[state.currentStage],
                    state: $state,
                    onAnswer: { submitAnswer() }
                )
            }
            
            if state.showCelebration {
                LottieView(name: "Celebration", loopMode: .playOnce)
                    .frame(width: 200, height: 200)
                    .accessibilityLabel("Celebration animation")
            }
        }
        .onAppear(perform: fetchChallenges)
        .onDisappear(perform: stopTimer)
        .onChange(of: state.currentStage) { _ in
            guard !state.showSummary else { return }
            startTimerForCurrentStage()
        }
        .fullScreenCover(isPresented: $state.showFeedback) {
            if let isCorrect = state.lastAnswerIsCorrect {
                FeedbackView(isCorrect: isCorrect, explanation: state.challenges[state.currentStage].explanation) {
                    proceedToNextStage()
                }
            }
        }
    }

    private func proceedToNextStage() {
        state.showFeedback = false
        if state.currentStage < state.challenges.count - 1 {
            state.currentStage += 1
            state.userAnswer = ""
            state.selectedChoiceIndex = nil
        } else {
            state.showSummary = true
            FlowLogger.trace("Final stage. Correct answers: \(state.correctAnswers) / \(state.challenges.count)")
            if state.correctAnswers == state.challenges.count && !state.challenges.isEmpty {
                submitPerfectScore()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        VStack {
            Text("Loading Today's Challenges...").font(.headline)
            ProgressView()
        }
        .foregroundColor(.white)
    }
    
    // MARK: - Methods
    
    private func fetchChallenges() {
        let db = Firestore.firestore()
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let today_iso = formatter.string(from: Date())
        
        let collectionName = appState.profile?.preferredMode == .kids ? "daily_challenges_kids" : "daily_challenges"
        
        db.collection(collectionName)
            .whereField("date_scheduled", isEqualTo: today_iso)
            .order(by: "difficulty")
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Error fetching daily challenges from \(collectionName): \(error.localizedDescription)")
                    return
                }
                guard let documents = querySnapshot?.documents else {
                    print("No daily challenge documents found for today in \(collectionName).")
                    return
                }
                let fetchedChallenges = documents.compactMap { try? $0.data(as: Challenge.self) }
                DispatchQueue.main.async {
                    self.state.challenges = fetchedChallenges
                    if !self.state.challenges.isEmpty {
                        startTimerForCurrentStage()
                    }
                }
            }
    }

    private func startTimerForCurrentStage() {
        guard state.currentStage < state.challenges.count else { return }
        stopTimer()
        
        let challenge = state.challenges[state.currentStage]
        state.timeRemaining = Double(challenge.time_limit_seconds)
        
        state.timerWorkItem?.cancel()
        
        let workItem = DispatchWorkItem {
            guard self.state.questionTimer == nil else { return }
            
            self.state.questionTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                if self.state.timeRemaining > 0 {
                    self.state.timeRemaining -= 0.05
                } else {
                    self.state.timeRemaining = 0
                    self.submitAnswer(isTimeUp: true)
                }
            }
        }
        
        self.state.timerWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: workItem)
    }
    
    private func stopTimer() {
        state.questionTimer?.invalidate()
        state.questionTimer = nil
        state.timerWorkItem?.cancel()
    }
    
    private func submitAnswer(isTimeUp: Bool = false) {
        guard let challenge = state.challenges[safe: state.currentStage] else { return }
        stopTimer()
        
        var isCorrect = false
        var answerToStore = state.userAnswer
        
        if !isTimeUp {
            if challenge.multiple_choice.enabled {
                if let selectedIndex = state.selectedChoiceIndex {
                    answerToStore = String(format: "%.0f", challenge.multiple_choice.choices[selectedIndex])
                    if selectedIndex == challenge.multiple_choice.correct_choice_index { isCorrect = true }
                }
            } else {
                if let userAnswerDouble = Double(state.userAnswer), abs(userAnswerDouble - challenge.correct_answer) < 0.0001 { isCorrect = true }
            }
        }
        
        if isCorrect {
            state.correctAnswers += 1
            state.showCelebration = true
            hapticGenerator.impactOccurred()
            FlowLogger.trace("Answer for stage \(state.currentStage) is CORRECT. Total correct: \(state.correctAnswers)")
        } else {
            FlowLogger.trace("Answer for stage \(state.currentStage) is INCORRECT.")
        }
        
        state.submittedAnswers.append(answerToStore)
        state.results.append(isCorrect)
        
        state.lastAnswerIsCorrect = isCorrect
        
        if isCorrect {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                state.showCelebration = false
                state.showFeedback = true
            }
        } else {
            state.showFeedback = true
        }
    }

    private func submitPerfectScore() {
        guard let profile = appState.profile else {
            FlowLogger.trace("Cannot submit perfect score: No user profile found in appState.")
            return
        }
        
        FlowLogger.trace("User \(profile.displayName) achieved a perfect score! Submitting to Firestore.")
        
        let db = Firestore.firestore()
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let today_iso = formatter.string(from: Date())
        let completionData: [String: Any] = [
            "userId": profile.id, "displayName": profile.displayName,
            "emojitar": ["emoji": profile.emojitar.emoji, "colorHex": profile.emojitar.colorHex],
            "completedAt": Timestamp(date: Date())
        ]
        
        let docRef = db.collection("daily_challenge_completions").document(today_iso).collection("users").document(profile.id)
        
        docRef.setData(completionData) { error in
            if let error = error {
                FlowLogger.trace("Error writing perfect score completion: \(error.localizedDescription)")
            } else {
                FlowLogger.trace("Successfully wrote perfect score for user \(profile.id) to document \(docRef.path)")
            }
        }
    }
}

// MARK: - Challenge Player View
struct ChallengePlayerView: View {
    let challenge: Challenge
    @Binding var state: TodaysChallengeView.ChallengeState
    let onAnswer: () -> Void
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isNumpadDisabled: Bool {
        return state.userAnswer.count >= challenge.numpad.max_digits
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Challenge \(state.currentStage + 1) of \(state.challenges.count)")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
            
            GameCountdownView(timeRatio: state.timeRemaining / Double(challenge.time_limit_seconds), rawTimeRemaining: Double(Int(ceil(state.timeRemaining))))
                .padding(.horizontal, 30)

            ScrollView {
                Text(challenge.prompt)
                    .font(.title)
                    .fontWeight(.medium)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 30)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            
            Spacer(minLength: 10)
            
            if challenge.multiple_choice.enabled {
                AdaptiveMultipleChoiceView(challenge: challenge, selectedChoiceIndex: $state.selectedChoiceIndex)
            } else {
                NumpadInputView(challenge: challenge, userAnswer: $state.userAnswer, isDisabled: isNumpadDisabled)
            }
            
            SubmitButton(onAnswer: onAnswer)
                .disabled(state.selectedChoiceIndex == nil && state.userAnswer.isEmpty)
        }
        .foregroundColor(.white)
        .padding(.vertical, 20)
    }
}

// MARK: - Adaptive Multiple Choice View
struct AdaptiveMultipleChoiceView: View {
    let challenge: Challenge
    @Binding var selectedChoiceIndex: Int?
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 4 : 2
        return Array(repeating: .init(.flexible()), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 15) {
            ForEach(Array(challenge.multiple_choice.choices.enumerated()), id: \.offset) { index, choice in
                Button(action: { selectedChoiceIndex = index }) {
                    Text(String(format: "%.0f", choice))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(selectedChoiceIndex == index ? .blue : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(selectedChoiceIndex == index ? Color.white : Color.white.opacity(0.2))
                        .cornerRadius(10)
                }
                .accessibilityLabel("Choice \(index + 1), \(choice)")
                .accessibilityAddTraits(selectedChoiceIndex == index ? .isSelected : [])
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Numpad Input View
struct NumpadInputView: View {
    let challenge: Challenge
    @Binding var userAnswer: String
    let isDisabled: Bool
    
    var body: some View {
        VStack {
            Text(userAnswer)
                .font(.bobaland(size: 40))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal, 40)
            
            NumpadView(userAnswer: $userAnswer, onPress: handleNumpadPress)
                .frame(maxHeight: 400)
                .padding(.horizontal, 20)
                .disabled(isDisabled)
        }
    }
    
    private func handleNumpadPress(value: String) {
        if value == "⌫" {
            if !userAnswer.isEmpty { userAnswer.removeLast() }
        } else if value == "C" {
            userAnswer = ""
        } else if !isDisabled {
            let numpadConfig = challenge.numpad
            if value == "." {
                if numpadConfig.allow_decimal && !userAnswer.contains(".") { userAnswer += value }
            } else {
                userAnswer += value
            }
        }
    }
}

// MARK: - Submit Button
struct SubmitButton: View {
    let onAnswer: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    
    var body: some View {
        Button(action: onAnswer) {
            HStack {
                Text("Submit")
                    .fontWeight(.bold)
                Image(systemName: "arrow.right.circle.fill")
            }
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isEnabled ? Color.blue : Color.gray)
            .cornerRadius(10)
        }
        .opacity(isEnabled ? 1.0 : 0.6)
        .animation(.easeInOut, value: isEnabled)
        .padding(.horizontal, 40)
        .padding(.bottom, 10)
        .accessibilityLabel("Submit answer")
    }
}


// MARK: - Summary Carousel View
struct SummaryCarouselView: View {
    let challenges: [Challenge]
    let correctAnswers: Int
    let submittedAnswers: [String]
    let results: [Bool]
    let onComplete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Challenge Results")
                .font(.largeTitle).bold()
            
            Text("You got \(correctAnswers) out of \(challenges.count) correct.")
                .font(.headline)
            
            TabView {
                ForEach(challenges.indices, id: \.self) { index in
                    ChallengeResultView(
                        challenge: challenges[index],
                        userAnswer: submittedAnswers[safe: index] ?? "No Answer",
                        isCorrect: results[safe: index] ?? false
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            
            Button("Done", action: onComplete)
                .font(.headline)
        }
        .padding(.vertical)
        .foregroundColor(.white)
    }
}

struct TodaysChallengeView_Previews: PreviewProvider {
    static var previews: some View {
        TodaysChallengeView(onComplete: { _, _ in })
            .environmentObject(AppState(previewProfile: PlayerProfile.fresh(id: "preview-user", displayName: "Preview", emojitar: .init(emoji: "😎", colorHex: "#FFFFFF"), mode: .kids)))
    }
}


