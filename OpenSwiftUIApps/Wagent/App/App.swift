import SwiftUI

@main
struct WagentApp: App {
  @State private var store = DocumentStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(store)
        .frame(minWidth: 1100, minHeight: 700)
    }
    .windowToolbarStyle(.unified)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("New Document") {
          store.createDocument()
        }
        .keyboardShortcut("n")
      }
    }
  }
}
