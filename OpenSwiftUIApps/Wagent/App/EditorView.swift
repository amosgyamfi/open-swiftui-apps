import AppKit
import SwiftUI

struct EditorView: View {
  @Binding var document: Document
  @Binding var showInspector: Bool
  @Binding var showAskAI: Bool

  @Environment(AIService.self) private var ai
  @Environment(DictationService.self) private var dictation

  @State private var selectedRange: NSRange = NSRange(location: 0, length: 0)
  @State private var selectedText: String = ""
  @State private var improveBanner: ImproveBanner?

  var body: some View {
    HSplitView {
      editorPane
        .frame(minWidth: 520)
      if showInspector {
        SuggestionsPanel(document: $document)
          .environment(ai)
          .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
      }
    }
    .toolbar { toolbarItems }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      BottomBar(
        document: document,
        showInspector: $showInspector,
        showAskAI: $showAskAI,
        onDictate: toggleDictation,
        onAsk: { showAskAI = true }
      )
      .environment(dictation)
    }
    .background(Color(nsColor: .textBackgroundColor))
  }

  private var editorPane: some View {
    VStack(spacing: 0) {
      titleHeader
      Divider()
      ZStack(alignment: .topLeading) {
        WritingTextEditor(
          text: $document.content,
          selectedRange: $selectedRange,
          selectedText: $selectedText
        )
        .padding(.horizontal, 48)
        .padding(.top, 24)
        .padding(.bottom, 16)

        if document.content.isEmpty {
          Text("Start writing, or tap the microphone to dictate…")
            .foregroundStyle(.tertiary)
            .font(.title3)
            .padding(.horizontal, 53)
            .padding(.top, 32)
            .allowsHitTesting(false)
        }

        if let banner = improveBanner {
          ImproveBannerView(banner: banner) { action in
            handleBanner(action: action, banner: banner)
          }
          .padding(20)
          .frame(maxWidth: .infinity, alignment: .topTrailing)
          .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private var titleHeader: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("Document title", text: $document.title, prompt: Text("Untitled"))
        .textFieldStyle(.plain)
        .font(.system(size: 26, weight: .bold))
      HStack(spacing: 10) {
        Label(document.goal.label, systemImage: document.goal.symbol)
          .font(.caption.weight(.medium))
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(.tint.opacity(0.15), in: Capsule())
          .foregroundStyle(.tint)
        Text("Edited \(document.updatedAt.formatted(date: .abbreviated, time: .shortened))")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
      }
    }
    .padding(.horizontal, 48)
    .padding(.top, 24)
    .padding(.bottom, 16)
  }

  @ToolbarContentBuilder
  private var toolbarItems: some ToolbarContent {
    ToolbarItemGroup(placement: .principal) {
      Picker("Goal", selection: $document.goal) {
        ForEach(WritingGoal.allCases) { goal in
          Label(goal.label, systemImage: goal.symbol).tag(goal)
        }
      }
      .pickerStyle(.menu)
      .help("Writing goal")
    }

    ToolbarItemGroup(placement: .primaryAction) {
      Menu {
        ForEach(ImproveStyle.allCases) { style in
          Button(style.label, systemImage: style.symbol) {
            Task { await runImprove(style: style) }
          }
        }
      } label: {
        Label("Improve", systemImage: "wand.and.stars")
      }
      .help("Improve with Apple Intelligence")
      .disabled(!ai.isAvailable)

      Button("Review", systemImage: "checkmark.seal") {
        Task { await ai.reviewDocument(document) }
      }
      .help("Review entire document")
      .disabled(!ai.isAvailable || document.content.isEmpty)

      Button("Ask AI", systemImage: "sparkles") {
        showAskAI = true
      }
      .help("Ask AI about this document")
      .disabled(!ai.isAvailable)
    }
  }

  private func toggleDictation() {
    if dictation.isListening {
      Task { await dictation.stop() }
    } else {
      let starting = document.content
      Task {
        await dictation.start(initialText: starting) { newContent in
          document.content = newContent
        }
      }
    }
  }

  @MainActor
  private func runImprove(style: ImproveStyle) async {
    let workingText: String
    let replaceRange: NSRange
    if !selectedText.isEmpty {
      workingText = selectedText
      replaceRange = selectedRange
    } else {
      workingText = document.content
      replaceRange = NSRange(location: 0, length: (document.content as NSString).length)
    }
    guard !workingText.isEmpty, let improved = await ai.improve(workingText, style: style) else { return }
    withAnimation(.smooth) {
      improveBanner = ImproveBanner(style: style, original: workingText, improved: improved, range: replaceRange)
    }
  }

  private func handleBanner(action: ImproveBanner.Action, banner: ImproveBanner) {
    switch action {
    case .apply:
      let nsString = document.content as NSString
      let safeRange = NSIntersectionRange(banner.range, NSRange(location: 0, length: nsString.length))
      let newContent = nsString.replacingCharacters(in: safeRange, with: banner.improved)
      document.content = newContent
    case .dismiss:
      break
    }
    withAnimation(.smooth) {
      improveBanner = nil
    }
  }
}

struct ImproveBanner: Identifiable {
  let id = UUID()
  let style: ImproveStyle
  let original: String
  let improved: String
  let range: NSRange

  enum Action { case apply, dismiss }
}

struct ImproveBannerView: View {
  let banner: ImproveBanner
  let action: (ImproveBanner.Action) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: banner.style.symbol)
          .foregroundStyle(.tint)
        Text(banner.style.label)
          .font(.headline)
        Spacer()
        Button {
          action(.dismiss)
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(.borderless)
        .help("Dismiss")
      }
      Text(banner.improved)
        .font(.callout)
        .foregroundStyle(.primary)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      HStack {
        Spacer()
        Button("Discard") { action(.dismiss) }
          .buttonStyle(.bordered)
        Button("Replace", systemImage: "arrow.triangle.2.circlepath") {
          action(.apply)
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(14)
    .frame(width: 360)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
  }
}
