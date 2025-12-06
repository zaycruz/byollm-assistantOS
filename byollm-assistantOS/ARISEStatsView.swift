//
//  ARISEStatsView.swift
//  byollm-assistantOS
//
//  Created by master on 12/6/25.
//

import SwiftUI

struct ARISEStatsView: View {
    let stats: UserStats
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        levelCard
                        streakCard
                        statsGrid
                        achievementsCard
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Character Stats")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var levelCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: stats.xpProgress / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 4) {
                    Text("LVL")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("\(stats.level)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            
            VStack(spacing: 8) {
                Text("\(stats.totalXP) Total XP")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                HStack {
                    Text("\(Int(stats.xpProgress))%")
                    Text("to Level \(stats.level + 1)")
                        .foregroundColor(.gray)
                }
                .font(.subheadline)
                
                ProgressView(value: stats.xpProgress, total: 100)
                    .tint(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.horizontal, 40)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.purple.opacity(0.5), .pink.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private var streakCard: some View {
        HStack(spacing: 24) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(stats.currentStreak)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                }
                Text("Current Streak")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 40)
            
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(.yellow)
                    Text("\(stats.longestStreak)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                }
                Text("Best Streak")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 40)
            
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(stats.nodesCompleted)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                }
                Text("Quests Done")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attributes")
                .font(.headline)
                .foregroundColor(.white)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCard("STR", value: stats.str, color: .red, icon: "bolt.fill", description: "Strength")
                statCard("INT", value: stats.int, color: .blue, icon: "brain", description: "Intelligence")
                statCard("WIS", value: stats.wis, color: .purple, icon: "lightbulb.fill", description: "Wisdom")
                statCard("DEX", value: stats.dex, color: .green, icon: "hare.fill", description: "Dexterity")
                statCard("CHA", value: stats.cha, color: .pink, icon: "star.fill", description: "Charisma")
                statCard("VIT", value: stats.vit, color: .orange, icon: "heart.fill", description: "Vitality")
            }
        }
    }
    
    private func statCard(_ abbrev: String, value: Int, color: Color, icon: String, description: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack(spacing: 4) {
                    Text(abbrev)
                        .font(.caption.bold())
                        .foregroundColor(color)
                    Text("\(value)")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private var achievementsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                progressRow("Quests Completed", value: stats.nodesCompleted, icon: "checkmark.circle.fill", color: .green)
                progressRow("Trees Completed", value: stats.treesCompleted, icon: "leaf.fill", color: .mint)
                progressRow("Total XP Earned", value: stats.totalXP, icon: "sparkles", color: .yellow)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func progressRow(_ label: String, value: Int, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text("\(value)")
                .font(.subheadline.bold())
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ARISEStatsView(stats: UserStats(
        level: 5,
        totalXP: 4500,
        currentStreak: 7,
        longestStreak: 14,
        nodesCompleted: 23,
        treesCompleted: 2,
        str: 15,
        int: 22,
        wis: 18,
        dex: 12,
        cha: 14,
        vit: 16
    ))
}
