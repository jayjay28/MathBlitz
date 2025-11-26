//
//  ProblemView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct AnswerView: View {
    let answer: String
    
    var body: some View {
        Text(answer.isEmpty ? "?" : answer)
            .font(.bobaland(size: 72))
            .foregroundColor(.white)
            .allowsTightening(true)
            .minimumScaleFactor(0.4)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 12)
    }
}

struct ProblemView: View {
    let problem: Problem
    
    var body: some View {
        Text("\(problem.a) × \(problem.b)")
            .font(.bobaland(size: 86))
            .foregroundColor(.white)
            .allowsTightening(true)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

struct ProblemView_Previews: PreviewProvider {
    static var previews: some View {
        ProblemView(problem: Problem(a: 12, b: 34))
            .background(Color.blue)
    }
}
