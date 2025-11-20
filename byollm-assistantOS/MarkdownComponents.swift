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
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

struct TableHeaderCell: View {
    let text: String
    
    var body: some View {
        Text(parseMarkdown(text))
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.15))
            .border(Color.white.opacity(0.1), width: 0.5)
    }
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        do {
            var attributed = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            attributed.foregroundColor = .white
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
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.9))
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isAlternateRow ? Color.white.opacity(0.05) : Color.clear)
            .border(Color.white.opacity(0.1), width: 0.5)
    }
    
    private func parseMarkdown(_ text: String) -> AttributedString {
        do {
            var attributed = try AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            attributed.foregroundColor = .white.opacity(0.9)
            return attributed
        } catch {
            return AttributedString(text)
        }
    }
}
