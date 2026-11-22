import SwiftUI
import UIKit
import Supabase

// Shared polish: motion, glow and small animated pieces used across the app.
// Everything here checks iOS's Reduce Motion setting and falls back to a calm version.

/// The brand colors from lettalkapp.com (used on the call screen).
enum Brand {
    static let yellow = Color(red: 1.0, green: 0.718, blue: 0.0)
    static let blue = Color(red: 0.29, green: 0.565, blue: 0.886)
    static let orange = Color(red: 1.0, green: 0.42, blue: 0.208)
    static let ink = Color(red: 0.05, green: 0.06, blue: 0.08)
}

// MARK: - Call screen background

/// Reads how loud the other person is from WebRTC a few times a second while a call is live.
final class RemoteAudioMeter: ObservableObject {
    @Published var level: Double = 0
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            WebRTCCallManager.shared.remoteAudioLevel { value in
                guard let self else { return }
                let speaking = min(1, max(0, (value - 0.02) * 6))
                if abs(speaking - self.level) > 0.05 { self.level = speaking }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        level = 0
    }
}

/// Soft, slowly drifting brand-color glows over a dark base. Swells slightly when the other
/// person speaks. Stays dark enough for the white call controls.
struct CallAuraBackground: View {
    var base: Color
    var isLive: Bool
    /// How strong the glows are: 1 on the call screen, lower behind content like the dial pad.
    var intensity: Double = 1
    @StateObject private var meter = RemoteAudioMeter()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            base
            Brand.ink.opacity(0.55)
            if reduceMotion {
                glows(at: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    glows(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
            LinearGradient(colors: [Color.black.opacity(0.4), Color.clear, Color.black.opacity(0.5)],
                           startPoint: .top, endPoint: .bottom)
        }
        .scaleEffect(reduceMotion ? 1 : 1 + 0.07 * meter.level)
        .brightness(reduceMotion ? 0 : 0.07 * meter.level)
        .animation(.easeOut(duration: 0.25), value: meter.level)
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear { if isLive { meter.start() } }
        .onChange(of: isLive) { _, live in
            if live { meter.start() } else { meter.stop() }
        }
        .onDisappear { meter.stop() }
    }

    private func glows(at t: TimeInterval) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                glow(Brand.blue, size: w * 1.15,
                     x: w * CGFloat(0.22 + 0.16 * sin(t * 0.21)),
                     y: h * CGFloat(0.20 + 0.08 * cos(t * 0.17)))
                glow(Brand.yellow, size: w * 0.95,
                     x: w * CGFloat(0.80 + 0.14 * cos(t * 0.19)),
                     y: h * CGFloat(0.52 + 0.10 * sin(t * 0.23)))
                glow(Brand.orange, size: w * 1.05,
                     x: w * CGFloat(0.35 + 0.18 * sin(t * 0.15 + 1.3)),
                     y: h * CGFloat(0.88 + 0.07 * cos(t * 0.2)))
            }
        }
        .blur(radius: 70)
        .opacity(0.7 * intensity)
    }

    private func glow(_ color: Color, size: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .position(x: x, y: y)
    }
}

// MARK: - Waveforms and loaders

/// Live microphone level for the translator's waveform. Kept out of the translator's main
/// view model so only the waveform redraws as the level changes.
final class AudioLevelMeter: ObservableObject {
    @Published var level: Double = 0
}

/// Bars that react to the user's voice while the translator is listening.
struct VoiceWaveform: View {
    @ObservedObject var meter: AudioLevelMeter
    var color: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<32, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: barHeight(index, t))
                }
            }
        }
        .frame(height: 44)
        .animation(.easeOut(duration: 0.12), value: meter.level)
        .accessibilityHidden(true)
    }

    private func barHeight(_ index: Int, _ t: TimeInterval) -> CGFloat {
        let x = Double(index) / 31.0
        let envelope = sin(x * Double.pi)                       // taller in the middle
        let wobble = 0.55 + 0.45 * sin(t * 9 + Double(index) * 0.9)
        let level = reduceMotion ? 0.3 : meter.level
        return CGFloat(4 + 38 * level * envelope * wobble)
    }
}

/// Four small bars that move while translated audio is playing.
struct MiniWaveform: View {
    var color: Color = .white
    @State private var moving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: 3, height: 16)
                    .scaleEffect(x: 1, y: reduceMotion ? 0.6 : (moving ? 1 : 0.3), anchor: .center)
                    .animation(reduceMotion ? nil : Animation.easeInOut(duration: 0.38)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.11), value: moving)
            }
        }
        .onAppear { moving = true }
        .accessibilityHidden(true)
    }
}

/// Three placeholder lines with a light sweep, shown while a translation is on its way.
struct ShimmerLines: View {
    @State private var phase: CGFloat = -0.6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        lines
            .overlay(
                GeometryReader { geo in
                    LinearGradient(colors: [Color.clear, Color.white.opacity(0.6), Color.clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: phase * geo.size.width)
                }
                .mask(lines)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(Animation.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.1
                }
            }
            .accessibilityLabel("Translating")
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 10) {
            line.padding(.trailing, 8)
            line.padding(.trailing, 56)
            line.padding(.trailing, 132)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var line: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.22))
            .frame(height: 12)
    }
}

// MARK: - Chat typing indicator

/// The "…" bubble shown while the other person is typing.
struct TypingBubble: View {
    @State private var moving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .offset(y: moving && !reduceMotion ? -4 : 0)
                        .opacity(moving ? 1 : 0.4)
                        .animation(Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.16), value: moving)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Spacer(minLength: 48)
        }
        .onAppear { moving = true }
        .accessibilityLabel("Typing")
    }
}

/// Sends and receives "is typing" signals for one chat over Supabase Realtime broadcast.
/// Nothing is stored: a signal only reaches someone who has the same chat open right now.
/// If Realtime is unreachable the chat works exactly as before, just without the indicator.
final class TypingChannel: ObservableObject {
    @Published private(set) var isOtherTyping = false

    private let chatId: String
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var lastSent = Date.distantPast

    init(chatId: String) {
        self.chatId = chatId
    }

    func start() {
        guard channel == nil else { return }
        let channel = SupabaseManager.client.channel("typing-\(chatId)")
        self.channel = channel
        let stream = channel.broadcastStream(event: "typing")
        listenTask = Task { [weak self] in
            await channel.subscribe()
            for await message in stream {
                let sender = message["payload"]?.objectValue?["user"]?.stringValue
                await MainActor.run { self?.received(from: sender) }
            }
        }
    }

    func stop() {
        listenTask?.cancel()
        listenTask = nil
        hideTask?.cancel()
        hideTask = nil
        isOtherTyping = false
        if let channel {
            Task { await SupabaseManager.client.removeChannel(channel) }
        }
        channel = nil
    }

    /// Call as the user types. Sends at most one signal every 2 seconds.
    func userTyped(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let channel,
              let me = AuthManager.shared.currentUserId,
              Date().timeIntervalSince(lastSent) > 2 else { return }
        lastSent = Date()
        let payload: JSONObject = ["user": .string(me)]
        Task { try? await channel.broadcast(event: "typing", message: payload) }
    }

    /// A new message arrived, so they have stopped typing.
    func messageArrived() {
        hideTask?.cancel()
        isOtherTyping = false
    }

    private func received(from sender: String?) {
        let me = AuthManager.shared.currentUserId?.lowercased()
        guard let sender, sender.lowercased() != me else { return }
        isOtherTyping = true
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.isOtherTyping = false }
        }
    }
}

// MARK: - List rows and pull to refresh

/// Tap handler for list rows that also flashes a soft glow behind the row.
struct TapGlow: ViewModifier {
    let action: () -> Void
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(glowing ? 0.16 : 0))
                    .shadow(color: Color.accentColor.opacity(glowing ? 0.55 : 0), radius: 12)
                    .padding(.horizontal, -10)
                    .padding(.vertical, -6)
                    .allowsHitTesting(false)
            )
            .onTapGesture {
                glowing = true
                action()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.easeOut(duration: 0.55)) { glowing = false }
                }
            }
    }
}

/// Pull to refresh with the Let Talk logo spinning in place of the system spinner.
struct LogoRefresh: ViewModifier {
    let topInset: CGFloat
    let action: () async -> Void
    @State private var refreshing = false
    @State private var spinning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(topInset: CGFloat, action: @escaping () async -> Void) {
        self.topInset = topInset
        self.action = action
        UIRefreshControl.appearance().tintColor = .clear      // hide the system spinner
    }

    func body(content: Content) -> some View {
        content
            .refreshable {
                let started = Date()
                refreshing = true
                await action()
                let elapsed = Date().timeIntervalSince(started)
                if elapsed < 0.8 {
                    try? await Task.sleep(nanoseconds: UInt64((0.8 - elapsed) * 1_000_000_000))
                }
                refreshing = false
            }
            .overlay(alignment: .top) {
                if refreshing {
                    Text("🍌")
                        .font(.system(size: 24))
                        .rotationEffect(.degrees(spinning ? 360 : 0))
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 3)
                        .padding(.top, topInset)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .onAppear {
                            spinning = false
                            guard !reduceMotion else { return }
                            withAnimation(Animation.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                                spinning = true
                            }
                        }
                        .accessibilityLabel("Refreshing")
                }
            }
            .animation(.spring(duration: 0.3), value: refreshing)
    }
}

extension View {
    /// Row tap with a soft glow. Use in place of `.onTapGesture` on list rows.
    func tapGlow(action: @escaping () -> Void) -> some View {
        modifier(TapGlow(action: action))
    }

    /// `.refreshable` with the spinning Let Talk logo.
    func logoRefreshable(topInset: CGFloat = 104, action: @escaping () async -> Void) -> some View {
        modifier(LogoRefresh(topInset: topInset, action: action))
    }
}

// MARK: - Sign-up progress

/// Thin progress bar for the top of the sign-up steps.
struct SetupProgressBar: View {
    let step: Int
    let total: Int
    let progress: Double
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(6, geo.size.width * CGFloat(min(1, max(0, progress)))))
                        .shadow(color: .white.opacity(0.6), radius: 4)
                }
            }
            .frame(height: 6)

            Text("Step \(step) of \(total) · \(label)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.9))
        }
        .animation(.spring(duration: 0.45), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step) of \(total), \(label)")
    }
}
