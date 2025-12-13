//
//  AriseView.swift
//  byollm-assistantOS
//
//  Placeholder for future Arise screens.
//

import SwiftUI

struct AriseView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                NatureTechBackground().ignoresSafeArea()
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Arise")
                            .font(DesignSystem.Typography.header())
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        DSChip(text: "Coming soon", isActive: false)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    .background(DesignSystem.Colors.chrome.opacity(0.98))
                    .overlay(
                        Rectangle()
                            .frame(height: 0.5)
                            .foregroundStyle(DesignSystem.Colors.separator),
                        alignment: .bottom
                    )
                    
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Arise will live here.")
                            .font(DesignSystem.Typography.body().weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.textPrimary)
                        
                        Text("We’ll add the Arise screens next.")
                            .font(DesignSystem.Typography.body())
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    AriseView()
}


