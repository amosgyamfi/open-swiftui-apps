import Foundation
import Observation

@Observable
final class DocumentStore {
  private let storageKey = "wagent.documents.v1"
  private let selectionKey = "wagent.selected.v1"

  var documents: [Document] = []
  var selectedID: Document.ID?

  init() {
    load()
    if documents.isEmpty {
      seedSampleDocuments()
    }
    if selectedID == nil {
      selectedID = documents.first?.id
    }
  }

  var selectedDocument: Document? {
    get { documents.first { $0.id == selectedID } }
    set {
      guard let new = newValue, let index = documents.firstIndex(where: { $0.id == new.id }) else { return }
      var updated = new
      updated.updatedAt = .now
      documents[index] = updated
      save()
    }
  }

  func binding(for id: Document.ID) -> Document? {
    documents.first { $0.id == id }
  }

  func update(_ document: Document) {
    guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
    var updated = document
    updated.updatedAt = .now
    documents[index] = updated
    save()
  }

  @discardableResult
  func createDocument(title: String = "Untitled", content: String = "") -> Document {
    let doc = Document(title: title, content: content)
    documents.insert(doc, at: 0)
    selectedID = doc.id
    save()
    return doc
  }

  func delete(_ document: Document) {
    documents.removeAll { $0.id == document.id }
    if selectedID == document.id {
      selectedID = documents.first?.id
    }
    save()
  }

  func duplicate(_ document: Document) {
    var copy = document
    copy.id = UUID()
    copy.title = document.title + " Copy"
    copy.createdAt = .now
    copy.updatedAt = .now
    documents.insert(copy, at: 0)
    selectedID = copy.id
    save()
  }

  private func load() {
    let defaults = UserDefaults.standard
    if let data = defaults.data(forKey: storageKey),
       let decoded = try? JSONDecoder().decode([Document].self, from: data) {
      documents = decoded
    }
    if let idString = defaults.string(forKey: selectionKey),
       let uuid = UUID(uuidString: idString) {
      selectedID = uuid
    }
  }

  private func save() {
    let defaults = UserDefaults.standard
    if let data = try? JSONEncoder().encode(documents) {
      defaults.set(data, forKey: storageKey)
    }
    if let selectedID {
      defaults.set(selectedID.uuidString, forKey: selectionKey)
    } else {
      defaults.removeObject(forKey: selectionKey)
    }
  }

  private func seedSampleDocuments() {
    let welcome = Document(
      title: "Welcome to Wagent",
      content: """
      Welcome to Wagent — your agentic writing companion for Mac.

      Start writing here, or use the toolbar above to improve your draft with on-device Apple Intelligence. \
      Tap the microphone in the bottom bar to dictate hands-free using the new SpeechAnalyzer engine.

      Try selecting a sentence and pressing Improve, Shorten, or Rewrite — Wagent will suggest a clearer version in seconds. \
      Open Ask AI when you want a thinking partner that can outline, summarise, or brainstorm with you.
      """,
      goal: .general
    )
    let email = Document(
      title: "Follow-up Email",
      content: "Hi Sam,\n\nJust wanted to follow up on the proposal I sent last week. let me know if you have any questions or feedback. happy to jump on a quick call.\n\nthanks",
      goal: .email
    )
    documents = [welcome, email]
    selectedID = welcome.id
    save()
  }
}
