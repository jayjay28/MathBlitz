//
//  LeaderboardViewModel.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import Foundation

@MainActor
final class LeaderboardViewModel: ObservableObject {
    @Published var selectedMode: GameMode
    @Published var entries: [LeaderboardEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init(initialMode: GameMode = .kids) {
        self.selectedMode = initialMode
    }
    
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await LeaderboardService.shared.fetchTopEntries(mode: selectedMode)
            entries = fetched
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
