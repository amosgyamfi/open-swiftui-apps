import SwiftUI

struct SidebarView: View {
  @Environment(DocumentStore.self) private var store
  @State private var query: String = ""

  var body: some View {
    @Bindable var store = store
    VStack(spacing: 0) {
      header
      Divider()
      List(selection: $store.selectedID) {
        Section("Documents") {
          ForEach(filteredDocuments) { document in
            DocumentRow(document: document)
              .tag(Optional(document.id))
              .contextMenu {
                Button("Duplicate", systemImage: "doc.on.doc") {
                  store.duplicate(document)
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                  store.delete(document)
                }
              }
          }
        }
      }
      .listStyle(.sidebar)
      .searchable(text: $query, placement: .sidebar, prompt: "Search documents")
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("New Document", systemImage: "square.and.pencil") {
          store.createDocument()
        }
        .help("New Document")
      }
    }
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "text.badge.checkmark")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 0) {
        Text("Wagent")
          .font(.headline)
        Text("Agentic Writing")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private var filteredDocuments: [Document] {
    let docs = store.documents.sorted { $0.updatedAt > $1.updatedAt }
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return docs }
    return docs.filter {
      $0.title.localizedCaseInsensitiveContains(trimmed) ||
      $0.content.localizedCaseInsensitiveContains(trimmed)
    }
  }
}

struct DocumentRow: View {
  let document: Document

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: document.goal.symbol)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.tint)
        .frame(width: 18)
        .padding(.top, 2)
      VStack(alignment: .leading, spacing: 3) {
        Text(document.title.isEmpty ? "Untitled" : document.title)
          .font(.body.weight(.medium))
          .lineLimit(1)
        Text(document.snippet)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        Text(document.updatedAt.formatted(.relative(presentation: .named)))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 4)
  }
}
