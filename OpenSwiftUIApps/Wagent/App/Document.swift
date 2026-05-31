import Foundation

struct Document: Identifiable, Codable, Hashable {
  var id: UUID = UUID()
  var title: String = "Untitled"
  var content: String = ""
  var createdAt: Date = .now
  var updatedAt: Date = .now
  var goal: WritingGoal = .general

  var wordCount: Int {
    content.split { !$0.isLetter && !$0.isNumber && $0 != "'" }.count
  }

  var characterCount: Int {
    content.count
  }

  var readingTimeMinutes: Int {
    max(1, Int((Double(wordCount) / 230.0).rounded(.up)))
  }

  var snippet: String {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "Empty document" }
    return String(trimmed.prefix(80))
  }
}

enum WritingGoal: String, Codable, CaseIterable, Identifiable {
  case general
  case professional
  case academic
  case casual
  case creative
  case email

  var id: String { rawValue }

  var label: String {
    switch self {
    case .general: "General"
    case .professional: "Professional"
    case .academic: "Academic"
    case .casual: "Casual"
    case .creative: "Creative"
    case .email: "Email"
    }
  }

  var symbol: String {
    switch self {
    case .general: "doc.text"
    case .professional: "briefcase"
    case .academic: "graduationcap"
    case .casual: "bubble.left.and.bubble.right"
    case .creative: "paintpalette"
    case .email: "envelope"
    }
  }
}
