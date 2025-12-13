//
//  MarkdownComponents.swift
//  byollm-assistantOS
//
//  Created by master on 11/16/25.
//

import SwiftUI

struct TableData: Equatable {
    let headers: [String]
    let rows: [[String]]
}

struct MarkdownTableView: View {
    let data: TableData
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                // Header
                GridRow {
                    ForEach(Array(data.headers.enumerated()), id: \.offset) { _, header in
                        TableHeaderCell(text: header)
                    }
                }
                
                // Rows
                ForEach(Array(data.rows.enumerated()), id: \.offset) { i, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            TableRowCell(text: cell, isAlternateRow: i % 2 == 0)
                        }
                    }
                }
            }
            .background(DesignSystem.Colors.surfaceElevated.opacity(0.9))
            .clipShape(.rect(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius, style: .continuous)
                    .stroke(DesignSystem.Colors.border.opacity(0.8), lineWidth: DesignSystem.Layout.borderWidth)
            )
        }
    }
}

struct TableHeaderCell: View {
    let text: String
    
    var body: some View {
        Text(parseMarkdown(text))
            .font(DesignSystem.Typography.body())
            .fontWeight(.semibold)
            .foregroundStyle(DesignSystem.Colors.textPrimary)
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.surfaceHighlight.opacity(0.85))
            .border(DesignSystem.Colors.separator, width: DesignSystem.Layout.borderWidth)
    }
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        do {
            var attributed = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            attributed.foregroundColor = DesignSystem.Colors.textPrimary
            return attributed
        } catch {
            return AttributedString(text)
        }
    }
}

struct TableRowCell: View {
    let text: String
    let isAlternateRow: Bool
    
    var body: some View {
        Text(parseMarkdown(text))
            .font(DesignSystem.Typography.caption())
            .foregroundStyle(DesignSystem.Colors.textSecondary)
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isAlternateRow ? DesignSystem.Colors.surface.opacity(0.75) : DesignSystem.Colors.surfaceElevated.opacity(0.6))
            .border(DesignSystem.Colors.separator, width: DesignSystem.Layout.borderWidth)
    }
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        do {
            var attributed = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            attributed.foregroundColor = DesignSystem.Colors.textSecondary
            return attributed
        } catch {
            return AttributedString(text)
        }
    }
}
