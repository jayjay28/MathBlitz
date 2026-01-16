import SwiftUI

struct RedesignedGameView: View {
    @State private var problem = "123 + 456"
    @State private var answer = ""
    @State private var score = 0
    @State private var lives = 3
    @State private var timeRemaining = 60.0
    @State private var isAnswerCorrect: Bool? = nil
    @State private var isShaking = false
    @State private var gameOver = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // Background

            if gameOver {
                VStack {
                    Text("Game Over")
                        .font(.bobaland(size: 64))
                        .foregroundColor(.white)
                    Text("Final Score: \(score)")
                        .font(.bobaland(size: 48))
                        .foregroundColor(.white)
                    Button(action: {
                        resetGame()
                    }) {
                        Text("Play Again")
                            .font(.bobaland(size: 32))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(16)
                    }
                }
            } else {
                VStack {
                    HStack {
                        Text("Score: \(score)")
                            .font(.bobaland(size: 24))
                            .foregroundColor(.white)
                        Spacer()
                        HStack {
                            ForEach(0..<lives, id: \.self) { _ in
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal)

                    ZStack {
                        Circle()
                            .stroke(lineWidth: 10)
                            .opacity(0.3)
                            .foregroundColor(.gray)

                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(self.timeRemaining / 60.0, 1.0)))
                            .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                            .foregroundColor(.green)
                            .rotationEffect(Angle(degrees: 270.0))
                            .animation(.linear, value: timeRemaining)

                        ScrollView {
                            VStack {
                                Text(problem)
                                    .font(.bobaland(size: 48))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding()

                                Text(answer)
                                    .font(.bobaland(size: 64))
                                    .foregroundColor(isAnswerCorrect == nil ? .white : (isAnswerCorrect == true ? .green : .red))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding()
//                                    .modifier(Shake(animatableData: CGFloat(isShaking ? 1 : 0)))
                            }
                        }
                        .frame(height: 200)
                    }
                    .frame(width: 300, height: 300)

                    // Numpad
                    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(7...9, id: \.self) { number in
                            Button(action: { answer += "\(number)" }) {
                                Text("\(number)")
                                    .font(.bobaland(size: 32))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(CalculatorButtonStyle())
                            .frame(height: (UIScreen.main.bounds.width * 0.18))
                        }
                        
                        ForEach(4...6, id: \.self) { number in
                            Button(action: { answer += "\(number)" }) {
                                Text("\(number)")
                                    .font(.bobaland(size: 32))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(CalculatorButtonStyle())
                            .frame(height: (UIScreen.main.bounds.width * 0.18))
                        }
                        
                        ForEach(1...3, id: \.self) { number in
                            Button(action: { answer += "\(number)" }) {
                                Text("\(number)")
                                    .font(.bobaland(size: 32))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .buttonStyle(CalculatorButtonStyle())
                            .frame(height: (UIScreen.main.bounds.width * 0.18))
                        }
                        
                        Button(action: { answer += "0" }) {
                            Text("0")
                                .font(.bobaland(size: 32))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(CalculatorButtonStyle())
                        .frame(height: (UIScreen.main.bounds.width * 0.18))
                        .gridCellColumns(2)

                        Button(action: {
                            if !answer.isEmpty {
                                answer.removeLast()
                            }
                        }) {
                            Image(systemName: "delete.left")
                                .font(.system(size: 24, weight: .bold))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(CalculatorButtonStyle())
                        .frame(height: (UIScreen.main.bounds.width * 0.18))
                        
                        Button(action: {
                            checkAnswer()
                        }) {
                            Text("=")
                                .font(.bobaland(size: 32))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(CalculatorButtonStyle())
                        .frame(height: (UIScreen.main.bounds.width * 0.18))
                    }
                    .padding()
                }
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .padding()
            }
        }
        .onReceive(timer) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                gameOver = true
            }
        }
    }

    func checkAnswer() {
        // This is a dummy check. Replace with real logic.
        if answer == "579" {
            isAnswerCorrect = true
            score += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                newProblem()
            }
        } else {
            isAnswerCorrect = false
            lives -= 1
            withAnimation {
                isShaking.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isAnswerCorrect = nil
                isShaking = false
                if lives == 0 {
                    gameOver = true
                }
            }
        }
    }

    func newProblem() {
        // Dummy problem generation
        let a = Int.random(in: 100...999)
        let b = Int.random(in: 100...999)
        problem = "\(a) + \(b)"
        answer = ""
        isAnswerCorrect = nil
    }

    func resetGame() {
        score = 0
        lives = 3
        timeRemaining = 60.0
        gameOver = false
        newProblem()
    }
}

//struct Shake: GeometryEffect {
//    var amount: CGFloat = 10
//    var shakesPerUnit = 3
//    var animatableData: CGFloat
//
//    func effectValue(size: CGSize) -> ProjectionTransform {
//        ProjectionTransform(CGAffineTransform(translationX:
//            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
//            y: 0))
//    }
//}


struct CalculatorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(Color.white.opacity(0.15))
            .cornerRadius(16)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct RedesignedGameView_Previews: PreviewProvider {
    static var previews: some View {
        RedesignedGameView()
    }
}
