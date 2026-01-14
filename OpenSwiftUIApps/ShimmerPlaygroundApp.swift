import SwiftUI

@main
struct ShimmerPlaygroundApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var progress: Double = 0.0
    @State private var duration: Double = 2.0
    @State private var fontSize: CGFloat = 60
    @State private var shimmerColor = Color.white
    @State private var tintColor = Color.blue
    @State private var invert = false
    @State private var isAnimating = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    VStack(spacing: 20) {
                        ZStack {
                            Text("Cooking…")
                                .font(.system(size: fontSize, weight: .bold))
                                .foregroundStyle(tintColor)
                            
                            Text("Cooking…")
                                .font(.system(size: fontSize, weight: .bold))
                                .foregroundStyle(invert ? shimmerColor.inverted() : shimmerColor)
                                .mask(
                                    GeometryReader { geometry in
                                        let width = geometry.size.width
                                        let gradientWidth = width * 0.3
                                        
                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(stops: [
                                                        .init(color: .clear, location: 0),
                                                        .init(color: invert ? .clear : .white, location: 0.3),
                                                        .init(color: invert ? .clear : .white, location: 0.7),
                                                        .init(color: .clear, location: 1)
                                                    ]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(width: gradientWidth)
                                            .offset(x: invert ? (width - (progress * (width + gradientWidth))) : ((progress * (width + gradientWidth)) - gradientWidth))
                                    }
                                )
                                .opacity(invert ? 0 : 1)
                            
                            if invert {
                                Text("Cooking…")
                                    .font(.system(size: fontSize, weight: .bold))
                                    .foregroundStyle(tintColor)
                                    .mask(
                                        GeometryReader { geometry in
                                            let width = geometry.size.width
                                            let gradientWidth = width * 0.3
                                            
                                            Rectangle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(stops: [
                                                            .init(color: .clear, location: 0),
                                                            .init(color: .white, location: 0.3),
                                                            .init(color: .white, location: 0.7),
                                                            .init(color: .clear, location: 1)
                                                        ]),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: gradientWidth)
                                                .offset(x: (width - (progress * (width + gradientWidth))))
                                        }
                                    )
                                    .blendMode(.destinationOut)
                            }
                        }
                        .compositingGroup()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        HStack(spacing: 12) {
                            if #available(iOS 26.0, *) {
                                Button {
                                    isAnimating = true
                                    progress = 0.0
                                    withAnimation(.linear(duration: duration)) {
                                        progress = 1.0
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                        isAnimating = false
                                    }
                                } label: {
                                    Label("Play Once", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glass)
                                .disabled(isAnimating)
                                .opacity(isAnimating ? 0.5 : 1)
                                
                                
                                Button {
                                    if isAnimating {
                                        isAnimating = false
                                    } else {
                                        isAnimating = true
                                        progress = 0.0
                                        animateLoop()
                                    }
                                } label: {
                                    Label(isAnimating ? "Stop" : "Loop", systemImage: isAnimating ? "stop.fill" : "repeat")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.glassProminent)
                            } else {
                                Button {
                                    isAnimating = true
                                    progress = 0.0
                                    withAnimation(.linear(duration: duration)) {
                                        progress = 1.0
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                        isAnimating = false
                                    }
                                } label: {
                                    Label("Play Once", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(isAnimating)
                                .opacity(isAnimating ? 0.5 : 1)
            
                                
                                Button {
                                    if isAnimating {
                                        isAnimating = false
                                    } else {
                                        isAnimating = true
                                        progress = 0.0
                                        animateLoop()
                                    }
                                } label: {
                                    Label(isAnimating ? "Stop" : "Loop", systemImage: isAnimating ? "stop.fill" : "repeat")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(isAnimating ? Color.red : Color.green)
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            let code = generateSwiftCode()
                            UIPasteboard.general.string = code
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .padding(8)
                          
                                .clipShape(Circle())
                                
                        }
                 
                        .sensoryFeedback(.success, trigger: UIPasteboard.general.string)
                        .glassEffect()
                    }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Settings")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Duration")
                                Spacer()
                                Text(String(format: "%.1fs", duration))
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $duration, in: 0.5...5) {
                                Text("Duration")
                            } minimumValueLabel: {
                                Image(systemName: "hare")
                            } maximumValueLabel: {
                                Image(systemName: "tortoise")
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Size")
                                Spacer()
                                Text("\(Int(fontSize))")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $fontSize, in: 30...100) {
                                Text("Size")
                            } minimumValueLabel: {
                                Image(systemName: "textformat.size.smaller")
                            } maximumValueLabel: {
                                Image(systemName: "textformat.size.larger")
                            }
                        }
                        
                        Divider()
                        
                        ColorPicker("Shimmer Color", selection: $shimmerColor)
                        
                        ColorPicker("Tint Color", selection: $tintColor)
                        
                        Toggle("Invert", isOn: $invert)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Shimmer Playground")
        }
    }
    
    func animateLoop() {
        guard isAnimating else { return }
        progress = 0.0
        withAnimation(.linear(duration: duration)) {
            progress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if isAnimating {
                animateLoop()
            }
        }
    }
    
    func generateSwiftCode() -> String {
        let shimmerHex = shimmerColor.toHex()
        let tintHex = tintColor.toHex()
        
        return """
        @State private var progress: Double = 0.0
        
        ZStack {
            Text("Cooking…")
                .font(.system(size: \(Int(fontSize)), weight: .bold))
                .foregroundStyle(Color(hex: "\(tintHex)"))
            
            Text("Cooking…")
                .font(.system(size: \(Int(fontSize)), weight: .bold))
                .foregroundStyle(Color(hex: "\(shimmerHex)"))
                .mask(
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let gradientWidth = width * 0.3
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: \(invert ? ".clear" : ".white"), location: 0.3),
                                        .init(color: \(invert ? ".clear" : ".white"), location: 0.7),
                                        .init(color: .clear, location: 1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: gradientWidth)
                            .offset(x: (progress * (width + gradientWidth)) - gradientWidth)
                    }
                )
                .opacity(\(invert ? "0" : "1"))\(invert ? """
            
            Text("Cooking…")
                .font(.system(size: \(Int(fontSize)), weight: .bold))
                .foregroundStyle(Color(hex: "\(tintHex)"))
                .mask(
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let gradientWidth = width * 0.3
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white, location: 0.3),
                                        .init(color: .white, location: 0.7),
                                        .init(color: .clear, location: 1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: gradientWidth)
                            .offset(x: (progress * (width + gradientWidth)) - gradientWidth)
                    }
                )
                .blendMode(.destinationOut)
        """ : "")
        }
        .compositingGroup()
        
        // Animate
        withAnimation(.linear(duration: \(String(format: "%.1f", duration)))) {
            progress = 1.0
        }
        """
    }
}

extension Color {
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else { return "FFFFFF" }
        let r = components[0]
        let g = components.count > 1 ? components[1] : components[0]
        let b = components.count > 2 ? components[2] : components[0]
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    
    func inverted() -> Color {
        guard let components = UIColor(self).cgColor.components else { return self }
        let r = components[0]
        let g = components.count > 1 ? components[1] : components[0]
        let b = components.count > 2 ? components[2] : components[0]
        return Color(red: 1.0 - r, green: 1.0 - g, blue: 1.0 - b)
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
