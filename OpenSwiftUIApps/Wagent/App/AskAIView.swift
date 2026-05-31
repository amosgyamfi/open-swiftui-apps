import SwiftUI

struct AskAIView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AIService.self) private var ai
  @Environment(DocumentStore.self) private var store

  @State private var question: String = ""
  @State private var conversation: [Turn] = []

  struct Turn: Identifiable {
    let id = UUID()
    let question: String
    var answer: String
  }

  private let prompts: [String] = [
    "Summarise this document in 3 bullets",
    "Outline a follow-up paragraph",
    "List counter-arguments to consider",
    "Translate this to French"
  ]

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollViewReader { proxy in
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            if conversation.isEmpty {
              welcome
            }
            ForEach(conversation) { turn in
              TurnView(turn: turn)
                .id(turn.id)
            }
            if case .asking = ai.phase {
              HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Thinking…")
                  .font(.callout)
                  .foregroundStyle(.secondary)
              }
              .padding(.leading, 8)
            }
          }
          .padding(20)
        }
        .onChange(of: conversation.count) {
          if let last = conversation.last {
            withAnimation(.smooth) { proxy.scrollTo(last.id, anchor: .bottom) }
          }
        }
      }
      Divider()
      composer
    }
    .frame(width: 640, height: 540)
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "sparkles")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 0) {
        Text("Ask AI")
          .font(.headline)
        Text("Apple Intelligence · on-device")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Done") { dismiss() }
        .keyboardShortcut(.cancelAction)
    }
    .padding(14)
  }

  private var welcome: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("How can I help with this document?")
        .font(.title3.weight(.semibold))
      Text("Ask anything. I have the current document as context.")
        .font(.callout)
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 6) {
        ForEach(prompts, id: \.self) { prompt in
          Button {
            send(prompt)
          } label: {
            HStack {
              Image(systemName: "wand.and.stars")
                .foregroundStyle(.tint)
              Text(prompt)
                .foregroundStyle(.primary)
              Spacer()
              Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.top, 6)
    }
  }

  private var composer: some View {
    HStack(spacing: 8) {
      TextField("Ask anything…", text: $question, axis: .vertical)
        .textFieldStyle(.plain)
        .lineLimit(1...4)
        .padding(10)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .onSubmit { send() }

      Button {
        send()
      } label: {
        Image(systemName: "arrow.up.circle.fill")
          .font(.system(size: 26))
          .foregroundStyle(.tint)
      }
      .buttonStyle(.plain)
      .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !ai.isAvailable)
      .keyboardShortcut(.return, modifiers: .command)
    }
    .padding(12)
  }

  private func send() {
    let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    send(trimmed)
    question = ""
  }

  private func send(_ prompt: String) {
    let context = store.selectedDocument?.content ?? ""
    var turn = Turn(question: prompt, answer: "")
    conversation.append(turn)
    Task {
      await ai.ask(prompt, context: context)
      turn.answer = ai.lastAskAnswer
      if let index = conversation.firstIndex(where: { $0.id == turn.id }) {
        conversation[index] = turn
      }
    }
  }
}

struct TurnView: View {
  let turn: AskAIView.Turn

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .top, spacing: 8) {
        Image(systemName: "person.fill")
          .foregroundStyle(.secondary)
          .frame(width: 22)
        Text(turn.question)
          .font(.callout.weight(.medium))
        Spacer()
      }
      if !turn.answer.isEmpty {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "sparkles")
            .foregroundStyle(.tint)
            .frame(width: 22)
          Text(turn.answer)
            .font(.callout)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
          Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
      }
    }
  }
}
