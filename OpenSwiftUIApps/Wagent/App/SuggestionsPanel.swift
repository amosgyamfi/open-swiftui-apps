import SwiftUI

struct SuggestionsPanel: View {
  @Binding var document: Document
  @Environment(AIService.self) private var ai

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          scoreCard
          categoryRow
          suggestionsList
        }
        .padding(16)
      }
    }
    .background(Color(nsColor: .windowBackgroundColor))
  }

  private var header: some View {
    HStack {
      Label("Assistant", systemImage: "sparkles")
        .font(.headline)
      Spacer()
      Button {
        Task { await ai.reviewDocument(document) }
      } label: {
        if case .reviewing = ai.phase {
          ProgressView().controlSize(.small)
        } else {
          Image(systemName: "arrow.clockwise")
        }
      }
      .buttonStyle(.borderless)
      .disabled(!ai.isAvailable || document.content.isEmpty)
      .help("Re-review document")
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  @ViewBuilder
  private var scoreCard: some View {
    if case .unavailable(let reason) = ai.phase {
      unavailableCard(reason)
    } else if let review = ai.review {
      ScoreCard(score: review.overallScore, summary: review.summary)
    } else if case .reviewing = ai.phase {
      loadingCard
    } else {
      idleCard
    }
  }

  private func unavailableCard(_ reason: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Apple Intelligence", systemImage: "sparkles")
        .font(.headline)
      Text(reason)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
  }

  private var loadingCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        ProgressView().controlSize(.small)
        Text("Reviewing your writing…")
          .font(.callout.weight(.medium))
      }
      Text("Apple Intelligence is analysing grammar, clarity, engagement, and delivery.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
  }

  private var idleCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label("Ready to review", systemImage: "wand.and.stars")
        .font(.headline)
      Text("Tap Review in the toolbar to get an on-device writing score and suggestions.")
        .font(.callout)
        .foregroundStyle(.secondary)
      Button("Review Now", systemImage: "checkmark.seal") {
        Task { await ai.reviewDocument(document) }
      }
      .buttonStyle(.borderedProminent)
      .disabled(!ai.isAvailable || document.content.isEmpty)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
  }

  private var categoryRow: some View {
    let counts = Dictionary(grouping: ai.review?.suggestions ?? []) { SuggestionCategory.from($0.category) }
      .mapValues { $0.count }
    return HStack(spacing: 8) {
      ForEach(SuggestionCategory.allCases, id: \.self) { cat in
        CategoryChip(category: cat, count: counts[cat] ?? 0)
      }
    }
  }

  @ViewBuilder
  private var suggestionsList: some View {
    if let review = ai.review, !review.suggestions.isEmpty {
      VStack(alignment: .leading, spacing: 10) {
        Text("Suggestions")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.secondary)
        ForEach(review.suggestions) { suggestion in
          SuggestionCard(suggestion: suggestion) {
            apply(suggestion: suggestion)
          }
        }
      }
    } else if ai.review != nil {
      VStack(spacing: 6) {
        Image(systemName: "checkmark.seal.fill")
          .font(.title)
          .foregroundStyle(.green)
        Text("No issues found")
          .font(.headline)
        Text("Your writing looks great.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 14)
    }
  }

  private func apply(suggestion: WritingSuggestion) {
    guard !suggestion.original.isEmpty else { return }
    if let range = document.content.range(of: suggestion.original) {
      document.content.replaceSubrange(range, with: suggestion.replacement)
    }
  }
}

struct ScoreCard: View {
  let score: Int
  let summary: String

  private var color: Color {
    switch score {
    case 80...: .green
    case 60..<80: .yellow
    default: .orange
    }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      ZStack {
        Circle()
          .stroke(color.opacity(0.2), lineWidth: 8)
        Circle()
          .trim(from: 0, to: CGFloat(score) / 100)
          .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(-90))
        VStack(spacing: -2) {
          Text("\(score)")
            .font(.title2.weight(.bold))
          Text("Score")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 72, height: 72)
      VStack(alignment: .leading, spacing: 4) {
        Text("Overall")
          .font(.subheadline.weight(.semibold))
        Text(summary)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
  }
}

struct CategoryChip: View {
  let category: SuggestionCategory
  let count: Int

  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: category.symbol)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.tint)
      Text("\(count)")
        .font(.callout.weight(.bold).monospacedDigit())
      Text(category.label)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
  }
}

struct SuggestionCard: View {
  let suggestion: WritingSuggestion
  let onApply: () -> Void

  private var category: SuggestionCategory { SuggestionCategory.from(suggestion.category) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: category.symbol)
          .foregroundStyle(.tint)
        Text(category.label)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tint)
        Spacer()
        Text(suggestion.title)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      if !suggestion.original.isEmpty {
        Text(suggestion.original)
          .font(.callout)
          .strikethrough()
          .foregroundStyle(.secondary)
      }
      Text(suggestion.replacement)
        .font(.callout.weight(.medium))
        .foregroundStyle(.primary)
      Text(suggestion.explanation)
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack {
        Spacer()
        Button("Apply", systemImage: "checkmark") {
          onApply()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
  }
}
