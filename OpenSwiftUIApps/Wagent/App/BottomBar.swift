import AppKit
import SwiftUI

struct BottomBar: View {
  let document: Document
  @Binding var showInspector: Bool
  @Binding var showAskAI: Bool
  let onDictate: () -> Void
  let onAsk: () -> Void

  @Environment(DictationService.self) private var dictation

  var body: some View {
    HStack(spacing: 14) {
      stats
      Spacer()
      dictationStatus
      Spacer()
      actions
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(.bar)
    .overlay(alignment: .top) {
      Divider()
    }
  }

  private var stats: some View {
    HStack(spacing: 18) {
      stat(value: "\(document.wordCount)", label: "Words", symbol: "textformat")
      stat(value: "\(document.characterCount)", label: "Chars", symbol: "character")
      stat(value: "\(document.readingTimeMinutes)m", label: "Read", symbol: "clock")
    }
  }

  private func stat(value: String, label: String, symbol: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: symbol)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.tint)
      Text(value)
        .font(.callout.weight(.semibold).monospacedDigit())
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var dictationStatus: some View {
    switch dictation.state {
    case .listening:
      HStack(spacing: 8) {
        PulsingDot()
        Text(dictation.partialText.isEmpty ? "Listening…" : dictation.partialText)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.head)
      }
      .frame(maxWidth: 320)
    case .preparing:
      Label("Preparing…", systemImage: "ellipsis")
        .font(.caption)
        .foregroundStyle(.secondary)
    case .downloading(let progress):
      Label("Downloading model \(Int(progress * 100))%", systemImage: "arrow.down.circle")
        .font(.caption)
        .foregroundStyle(.secondary)
    case .error(let message):
      Label(message, systemImage: "exclamationmark.triangle")
        .font(.caption)
        .foregroundStyle(.red)
        .lineLimit(1)
    case .permissionRequired(let permission):
      HStack(spacing: 8) {
        Label(permission.title, systemImage: "lock.shield")
          .font(.caption.weight(.medium))
          .foregroundStyle(.orange)
        Button("Open Settings") {
          NSWorkspace.shared.open(permission.settingsURL)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    case .idle:
      Text("English (US)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var actions: some View {
    HStack(spacing: 6) {
      Button(action: onAsk) {
        Label("Ask AI", systemImage: "sparkles")
      }
      .buttonStyle(.borderless)
      .help("Ask AI")

      Button(action: onDictate) {
        Label(
          dictation.isListening ? "Stop Dictation" : "Start Dictation",
          systemImage: dictation.isListening ? "stop.circle.fill" : "mic.fill"
        )
        .labelStyle(.iconOnly)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(dictation.isListening ? AnyShapeStyle(.red) : AnyShapeStyle(.tint))
        .padding(8)
        .background(
          Circle()
            .fill(dictation.isListening ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.15))
        )
      }
      .buttonStyle(.plain)
      .help(dictation.isListening ? "Stop dictation" : "Start dictation")

      Button {
        showInspector.toggle()
      } label: {
        Label(
          showInspector ? "Hide Suggestions" : "Show Suggestions",
          systemImage: showInspector ? "sidebar.right" : "sidebar.right"
        )
        .labelStyle(.iconOnly)
      }
      .buttonStyle(.borderless)
      .help(showInspector ? "Hide Suggestions" : "Show Suggestions")
    }
  }
}

struct PulsingDot: View {
  @State private var pulse = false

  var body: some View {
    Circle()
      .fill(Color.red)
      .frame(width: 9, height: 9)
      .scaleEffect(pulse ? 1.25 : 0.85)
      .opacity(pulse ? 1.0 : 0.6)
      .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
      .onAppear { pulse = true }
  }
}
