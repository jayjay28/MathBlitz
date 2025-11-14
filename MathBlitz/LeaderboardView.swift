//
//  LeaderboardView.swift
//  MathBlitz
//
//  Created by Clyon Jackson on 11/10/25.
//

import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var viewModel: LeaderboardViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Mode", selection: $viewModel.selectedMode) {
                    ForEach(GameMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: viewModel.selectedMode) { _ in
                    Task { await viewModel.load() }
                }
                
                content
            }
            .navigationTitle("Leaderboard")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }
    
    @Environment(\.dismiss) private var dismiss
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Fetching scores…")
                .padding()
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                Text("Unable to load leaderboard")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(error)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                Button("Retry") {
                    Task { await viewModel.load() }
                }
            }
            .padding()
        } else if viewModel.entries.isEmpty {
            Text("Be the first to set a score!")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .padding(.top, 60)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.entries.enumerated().map({ $0 }), id: \.element.id) { index, entry in
                        LeaderboardRow(rank: index + 1, entry: entry)
                    }
                }
                .padding()
            }
        }
    }
}

struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(rank)")
                .font(.bobaland(size: 32))
                .foregroundColor(.purple)
                .frame(width: 50, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(entry.score)")
                .font(.bobaland(size: 32))
                .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
