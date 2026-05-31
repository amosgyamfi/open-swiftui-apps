import Foundation
import FoundationModels
import Observation

@Generable
struct WritingSuggestion: Identifiable {
  @Guide(description: "A unique short identifier for this suggestion.")
  var id: String

  @Guide(description: "The category of the suggestion. One of: correctness, clarity, engagement, delivery.")
  var category: String

  @Guide(description: "A short title that names the issue, three words or fewer.")
  var title: String

  @Guide(description: "The original phrase from the text that has the issue. Exact substring.")
  var original: String

  @Guide(description: "The improved replacement text.")
  var replacement: String

  @Guide(description: "A one-sentence explanation of why the change improves the writing.")
  var explanation: String
}

@Generable
struct WritingReview {
  @Guide(description: "An overall writing quality score from 0 to 100.")
  var overallScore: Int

  @Guide(description: "A short, friendly one-sentence summary of the document's quality.")
  var summary: String

  @Guide(description: "A list of concrete suggestions to improve the writing. Provide up to 6.")
  var suggestions: [WritingSuggestion]
}

enum SuggestionCategory: String, CaseIterable {
  case correctness, clarity, engagement, delivery

  var label: String {
    switch self {
    case .correctness: "Correctness"
    case .clarity: "Clarity"
    case .engagement: "Engagement"
    case .delivery: "Delivery"
    }
  }

  var symbol: String {
    switch self {
    case .correctness: "checkmark.seal.fill"
    case .clarity: "sparkles"
    case .engagement: "flame.fill"
    case .delivery: "paperplane.fill"
    }
  }

  var tint: String {
    switch self {
    case .correctness: "red"
    case .clarity: "blue"
    case .engagement: "green"
    case .delivery: "purple"
    }
  }

  static func from(_ raw: String) -> SuggestionCategory {
    SuggestionCategory(rawValue: raw.lowercased()) ?? .clarity
  }
}

@Observable
final class AIService {
  enum Phase: Equatable {
    case idle
    case reviewing
    case improving
    case asking
    case unavailable(String)
  }

  var phase: Phase = .idle
  var review: WritingReview?
  var lastAskAnswer: String = ""
  var lastImprovement: String = ""

  private var reviewSession: LanguageModelSession?
  private var askSession: LanguageModelSession?
  private var improveSession: LanguageModelSession?

  init() {
    refreshAvailability()
  }

  var isAvailable: Bool {
    if case .unavailable = phase { return false }
    return true
  }

  private func refreshAvailability() {
    switch SystemLanguageModel.default.availability {
    case .available:
      phase = .idle
    case .unavailable(let reason):
      phase = .unavailable(reasonDescription(reason))
    }
  }

  private func reasonDescription(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
    switch reason {
    case .deviceNotEligible:
      "This Mac does not support Apple Intelligence."
    case .appleIntelligenceNotEnabled:
      "Enable Apple Intelligence in System Settings to use AI features."
    case .modelNotReady:
      "Apple Intelligence is preparing. Please try again in a moment."
    @unknown default:
      "Apple Intelligence is currently unavailable."
    }
  }

  func reviewDocument(_ document: Document) async {
    guard isAvailable else { return }
    phase = .reviewing
    review = nil
    let prompt = """
    Review the following \(document.goal.label.lowercased()) writing for grammar, clarity, engagement, and delivery. \
    Provide an overall score and up to six concrete suggestions. \
    For each suggestion, quote the exact phrase from the text in the original field.

    Text:
    \(document.content)
    """
    do {
      if reviewSession == nil {
        reviewSession = LanguageModelSession(instructions: "You are a precise, friendly writing coach who returns structured JSON feedback.")
      }
      let response = try await reviewSession!.respond(to: prompt, generating: WritingReview.self, options: GenerationOptions(temperature: 0.4))
      review = response.content
      phase = .idle
    } catch {
      phase = .idle
    }
  }

  func improve(_ text: String, style: ImproveStyle) async -> String? {
    guard isAvailable, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    phase = .improving
    defer { phase = .idle }
    let prompt = """
    Rewrite the following text \(style.instruction). \
    Preserve the original meaning. Return only the rewritten text with no preamble or explanation.

    Text:
    \(text)
    """
    do {
      if improveSession == nil {
        improveSession = LanguageModelSession(instructions: "You are an expert editor who returns only the rewritten passage with no extra commentary.")
      }
      let response = try await improveSession!.respond(to: prompt, options: GenerationOptions(temperature: 0.5))
      let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
      lastImprovement = trimmed
      return trimmed
    } catch {
      return nil
    }
  }

  func ask(_ question: String, context: String) async {
    guard isAvailable else { return }
    phase = .asking
    defer { phase = .idle }
    let prompt = """
    The user is working on the following document:
    \"\"\"
    \(context)
    \"\"\"

    Their question: \(question)

    Answer concisely and helpfully.
    """
    do {
      if askSession == nil {
        askSession = LanguageModelSession(instructions: "You are an agentic writing partner. Give grounded, helpful, concise answers.")
      }
      let response = try await askSession!.respond(to: prompt, options: GenerationOptions(temperature: 0.6))
      lastAskAnswer = response.content
    } catch {
      lastAskAnswer = "Apple Intelligence couldn't generate an answer right now."
    }
  }
}

enum ImproveStyle: String, CaseIterable, Identifiable {
  case improve, shorten, expand, professional, casual, persuasive, fixGrammar

  var id: String { rawValue }

  var label: String {
    switch self {
    case .improve: "Improve Writing"
    case .shorten: "Make Shorter"
    case .expand: "Make Longer"
    case .professional: "Professional Tone"
    case .casual: "Casual Tone"
    case .persuasive: "Persuasive Tone"
    case .fixGrammar: "Fix Grammar"
    }
  }

  var symbol: String {
    switch self {
    case .improve: "wand.and.stars"
    case .shorten: "arrow.down.right.and.arrow.up.left"
    case .expand: "arrow.up.left.and.arrow.down.right"
    case .professional: "briefcase"
    case .casual: "bubble.left.and.bubble.right"
    case .persuasive: "megaphone"
    case .fixGrammar: "checkmark.seal"
    }
  }

  var instruction: String {
    switch self {
    case .improve: "to be clearer, more polished, and more engaging"
    case .shorten: "to be more concise without losing meaning"
    case .expand: "with more detail, examples, and depth"
    case .professional: "in a professional, formal tone"
    case .casual: "in a casual, friendly tone"
    case .persuasive: "in a persuasive tone that motivates the reader"
    case .fixGrammar: "by fixing grammar, spelling, and punctuation only, keeping wording otherwise unchanged"
    }
  }
}
