import SwiftUI

struct ContentView: View {
  @Environment(DocumentStore.self) private var store
  @State private var ai = AIService()
  @State private var dictation = DictationService()
  @State private var showInspector: Bool = true
  @State private var showAskAI: Bool = false

  var body: some View {
    @Bindable var store = store
    NavigationSplitView {
      SidebarView()
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    } detail: {
      if let selected = store.selectedDocument {
        EditorView(
          document: binding(for: selected.id),
          showInspector: $showInspector,
          showAskAI: $showAskAI
        )
        .environment(ai)
        .environment(dictation)
        .id(selected.id)
      } else {
        EmptyDocumentView()
      }
    }
    .navigationTitle("")
    .sheet(isPresented: $showAskAI) {
      AskAIView()
        .environment(ai)
        .environment(store)
    }
  }

  private func binding(for id: Document.ID) -> Binding<Document> {
    Binding(
      get: {
        store.documents.first(where: { $0.id == id }) ?? Document()
      },
      set: { newValue in
        store.update(newValue)
      }
    )
  }
}

struct EmptyDocumentView: View {
  @Environment(DocumentStore.self) private var store

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.system(size: 56, weight: .light))
        .foregroundStyle(.tint)
      Text("No Document Selected")
        .font(.title2.weight(.semibold))
      Text("Select a document from the sidebar, or create a new one to start writing.")
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button("New Document", systemImage: "square.and.pencil") {
        store.createDocument()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .padding(.top, 8)
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.background)
  }
}
