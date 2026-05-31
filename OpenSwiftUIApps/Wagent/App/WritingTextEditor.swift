import AppKit
import SwiftUI

struct WritingTextEditor: NSViewRepresentable {
  @Binding var text: String
  @Binding var selectedRange: NSRange
  @Binding var selectedText: String

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    scrollView.hasVerticalScroller = true
    scrollView.drawsBackground = false

    let textView = scrollView.documentView as! NSTextView
    textView.delegate = context.coordinator
    textView.isRichText = false
    textView.allowsUndo = true
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.font = NSFont.systemFont(ofSize: 16)
    textView.textContainerInset = NSSize(width: 0, height: 8)
    textView.drawsBackground = false
    textView.backgroundColor = .clear
    textView.textColor = .labelColor
    textView.usesFindBar = true
    textView.string = text
    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = nsView.documentView as? NSTextView else { return }
    if textView.string != text {
      let previous = textView.string
      let prevSelection = textView.selectedRange()
      textView.string = text
      let length = (textView.string as NSString).length
      if text.hasPrefix(previous), prevSelection.location >= (previous as NSString).length {
        textView.setSelectedRange(NSRange(location: length, length: 0))
        textView.scrollRangeToVisible(NSRange(location: length, length: 0))
      } else {
        textView.setSelectedRange(NSRange(location: min(prevSelection.location, length), length: 0))
      }
    }
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: WritingTextEditor
    init(_ parent: WritingTextEditor) { self.parent = parent }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      parent.text = textView.string
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      let range = textView.selectedRange()
      parent.selectedRange = range
      let ns = textView.string as NSString
      if range.length > 0, NSMaxRange(range) <= ns.length {
        parent.selectedText = ns.substring(with: range)
      } else {
        parent.selectedText = ""
      }
    }
  }
}
