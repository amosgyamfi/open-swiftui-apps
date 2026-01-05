import SwiftUI
import FoundationModels

@Generable(description: "Get the current weather for a specified location")
struct WeatherQuery {
    @Guide(description: "The city name, e.g., 'San Francisco' or 'London'")
    var city: String
}

@Generable(description: "A structured response with organized information")
struct StructuredResponse {
    @Guide(description: "The main answer or summary")
    var summary: String
    
    @Guide(description: "Key points or bullet points related to the topic")
    var keyPoints: [String]
    
    @Guide(description: "Additional context or details if relevant")
    var details: String?
}

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
}

struct ChatView: View {
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var session: LanguageModelSession?
    @State private var isGenerating = false
    @State private var availability: SystemLanguageModel.Availability?
    @FocusState private var isInputFocused: Bool
    @State private var showAPIKeyAlert = false
    @AppStorage("openWeatherAPIKey") private var apiKey = ""
    @State private var structuredOutputMode = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let availability = availability {
                        switch availability {
                        case .available:
                            chatContent
                        case .unavailable(let reason):
                            unavailableView(reason: reason)
                        }
                    } else {
                        ProgressView()
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isInputFocused = false
            }
            .navigationTitle("AI Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { structuredOutputMode.toggle() }) {
                            Image(systemName: structuredOutputMode ? "list.bullet.rectangle.fill" : "list.bullet.rectangle")
                                .foregroundStyle(structuredOutputMode ? .blue : .primary)
                        }
                        
                        Button(action: { showAPIKeyAlert = true }) {
                            Image(systemName: apiKey.isEmpty ? "key" : "key.fill")
                                .foregroundStyle(apiKey.isEmpty ? .red : .green)
                        }
                    }
                }
            }
            .alert("Weather API Key", isPresented: $showAPIKeyAlert) {
                TextField("Enter OpenWeatherMap API Key", text: $apiKey)
                Button("Done", action: {})
                Button("Cancel", role: .cancel, action: {})
            } message: {
                Text("Enter your OpenWeatherMap API key to enable weather queries. Get one free at openweathermap.org")
            }
            .safeAreaInset(edge: .bottom) {
                if availability == .available {
                    inputBar
                }
            }
            .task {
                availability = await SystemLanguageModel.default.availability
                if availability == .available {
                    session = LanguageModelSession()
                }
            }
        }
    }
    
    var chatContent: some View {
        VStack(spacing: 16) {
            if messages.isEmpty {
                emptyState
            } else {
                ForEach(messages) { message in
                    MessageBubble(
                        message: message,
                        onCopy: { copyMessage(message) },
                        onShare: { shareMessage(message) },
                        onClear: { clearConversation(for: message) }
                    )
                }
            }
            
            if isGenerating {
                HStack {
                    ProgressView()
                        .padding(.leading, 16)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 16)
    }
    
    var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
                .padding(.top, 80)
            
            Text("Start a Conversation")
                .font(.title2.bold())
            
            Text("Ask me anything and I'll help you out using on-device AI")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    func unavailableView(reason: SystemLanguageModel.UnavailabilityReason) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
                .padding(.top, 80)
            
            Text("AI Unavailable")
                .font(.title2.bold())
            
            Text(reasonText(for: reason))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
    
    func reasonText(for reason: SystemLanguageModel.UnavailabilityReason) -> String {
        switch reason {
        case .notSupported:
            return "This device doesn't support on-device AI models"
        case .notEnabled:
            return "AI features are not enabled on this device"
        case .notDownloaded:
            return "AI model needs to be downloaded in Settings"
        case .notReady:
            return "AI model is not ready yet. Please try again later"
        @unknown default:
            return "AI is currently unavailable"
        }
    }
    
    var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Message", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                .lineLimit(1...5)
                .focused($isInputFocused)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
    
    func sendMessage() {
        let trimmedText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !isGenerating, let session = session else { return }
        
        let userMessage = Message(content: trimmedText, isUser: true, timestamp: Date())
        messages.append(userMessage)
        inputText = ""
        isGenerating = true
        
        Task {
            do {
                if structuredOutputMode {
                    let structuredResponse = try await session.respond(to: trimmedText, generating: StructuredResponse.self)
                    
                    var formattedContent = "**Summary:**\n\(structuredResponse.content.summary)\n\n"
                    
                    if !structuredResponse.content.keyPoints.isEmpty {
                        formattedContent += "**Key Points:**\n"
                        for (index, point) in structuredResponse.content.keyPoints.enumerated() {
                            formattedContent += "\(index + 1). \(point)\n"
                        }
                    }
                    
                    if let details = structuredResponse.content.details, !details.isEmpty {
                        formattedContent += "\n**Additional Details:**\n\(details)"
                    }
                    
                    let aiMessage = Message(content: formattedContent, isUser: false, timestamp: Date())
                    messages.append(aiMessage)
                } else {
                    let weatherTool = Tool(
                        name: "get_weather",
                        description: "Get the current weather for a specified location",
                        generate: WeatherQuery.self
                    )
                    
                    let response = try await session.respond(to: trimmedText, tools: [weatherTool])
                    
                    if let toolRequest = response.toolInvocationRequests?.first {
                        if let weatherQuery = toolRequest.generate(WeatherQuery.self) {
                            let weatherData = await fetchWeather(for: weatherQuery.city)
                            let toolResult = ToolInvocationResult(
                                invocationID: toolRequest.invocationID,
                                content: weatherData
                            )
                            
                            let finalResponse = try await session.respond(to: toolResult)
                            let aiMessage = Message(content: finalResponse.content, isUser: false, timestamp: Date())
                            messages.append(aiMessage)
                        }
                    } else {
                        let aiMessage = Message(content: response.content, isUser: false, timestamp: Date())
                        messages.append(aiMessage)
                    }
                }
            } catch {
                let errorMessage = Message(content: "Sorry, I encountered an error: \(error.localizedDescription)", isUser: false, timestamp: Date())
                messages.append(errorMessage)
            }
            isGenerating = false
        }
    }
    
    func fetchWeather(for city: String) async -> String {
        guard !apiKey.isEmpty else {
            return "Weather API key not configured. Please add your OpenWeatherMap API key in settings (key icon)."
        }
        
        let cityEncoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(cityEncoded)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            return "Invalid city name: \(city)"
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let weather = try JSONDecoder().decode(WeatherResponse.self, from: data)
            
            return """
            Weather in \(weather.name):
            - Temperature: \(weather.main.temp)°C (feels like \(weather.main.feelsLike)°C)
            - Conditions: \(weather.weather.first?.description.capitalized ?? "Unknown")
            - Humidity: \(weather.main.humidity)%
            - Wind Speed: \(weather.wind.speed) m/s
            """
        } catch {
            return "Unable to fetch weather for \(city). Error: \(error.localizedDescription)"
        }
    }
    
    func copyMessage(_ message: Message) {
        UIPasteboard.general.string = message.content
    }
    
    func shareMessage(_ message: Message) {
        let activityVC = UIActivityViewController(activityItems: [message.content], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func clearConversation(for message: Message) {
        if let index = messages.firstIndex(where: { $0.id == message.id }), index > 0 {
            messages.removeSubrange((index - 1)...index)
        }
    }
}

struct WeatherResponse: Codable {
    let name: String
    let main: MainWeather
    let weather: [WeatherCondition]
    let wind: Wind
    
    struct MainWeather: Codable {
        let temp: Double
        let feelsLike: Double
        let humidity: Int
        
        enum CodingKeys: String, CodingKey {
            case temp
            case feelsLike = "feels_like"
            case humidity
        }
    }
    
    struct WeatherCondition: Codable {
        let description: String
    }
    
    struct Wind: Codable {
        let speed: Double
    }
}

struct MessageBubble: View {
    let message: Message
    let onCopy: () -> Void
    let onShare: () -> Void
    let onClear: () -> Void
    
    @State private var reaction: Reaction?
    @State private var showHappyAnimation = false
    @State private var showSadAnimation = false
    
    enum Reaction {
        case thumbsUp, thumbsDown
    }
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                    if !message.isUser {
                        HStack(spacing: 12) {
                            Button(action: onCopy) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .sensoryFeedback(.impact(weight: .light), trigger: UUID())
                            
                            Button(action: onShare) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            .sensoryFeedback(.impact(weight: .light), trigger: UUID())
                            
                            Button(action: onClear) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red)
                            }
                            .sensoryFeedback(.impact(weight: .medium), trigger: UUID())
                        }
                        .padding(.horizontal, 4)
                    }
                    
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(message.isUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(message.isUser ? .white : .primary)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 20,
                                bottomLeadingRadius: message.isUser ? 0 : 20,
                                bottomTrailingRadius: message.isUser ? 20 : 0,
                                topTrailingRadius: 20
                            )
                        )
                    
                    if !message.isUser {
                        HStack(spacing: 16) {
                            Button(action: { toggleReaction(.thumbsUp) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: (reaction == .thumbsUp) ? "hand.thumbsup.fill" : "hand.thumbsup")
                                        .font(.system(size: 14))
                                    if showHappyAnimation {
                                        Text("😊")
                                            .font(.system(size: 20))
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .foregroundStyle((reaction == .thumbsUp) ? .blue : .secondary)
                            }
                            .sensoryFeedback(.success, trigger: showHappyAnimation)
                            
                            Button(action: { toggleReaction(.thumbsDown) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: (reaction == .thumbsDown) ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                        .font(.system(size: 14))
                                    if showSadAnimation {
                                        Text("😔")
                                            .font(.system(size: 20))
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .foregroundStyle((reaction == .thumbsDown) ? .orange : .secondary)
                            }
                            .sensoryFeedback(.warning, trigger: showSadAnimation)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showHappyAnimation)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showSadAnimation)
    }
    
    func toggleReaction(_ newReaction: Reaction) {
        if reaction == newReaction {
            reaction = nil
            if newReaction == .thumbsUp {
                showHappyAnimation = false
            } else {
                showSadAnimation = false
            }
        } else {
            reaction = newReaction
            if newReaction == .thumbsUp {
                showHappyAnimation = true
                showSadAnimation = false
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    showHappyAnimation = false
                }
            } else {
                showSadAnimation = true
                showHappyAnimation = false
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    showSadAnimation = false
                }
            }
        }
    }
}
