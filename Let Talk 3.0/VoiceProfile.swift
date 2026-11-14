import SwiftUI
import AVFoundation

/// Which kind of voice other people hear when this user's speech is translated.
/// Chosen at sign-up; it sets the default voice, which can be changed in Voice Settings.
enum VoiceGender: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }

    /// Voice IDs are "<gender>-<1...8>", so the same choice works in every language: the
    /// listener's phone plays voice N of that gender in the listener's language.
    var defaultVoiceId: String { "\(rawValue)-1" }
}

extension User {
    /// The voice others should hear for this user, or nil if they never chose one
    /// (older accounts); listeners then fall back to the iPhone's built-in voice.
    var effectiveVoiceId: String? { voiceId ?? gender?.defaultVoiceId }
}

// MARK: - Playback

/// Plays translated speech from the `speak` function, one clip after another.
@MainActor
final class TranslatedVoicePlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = TranslatedVoicePlayer()

    private var player: AVAudioPlayer?
    private var queue: [Data] = []

    /// Fetches and queues `text` in `voiceId`, spoken in `language` (the listener's language).
    /// Returns how long the clip lasts, so the caller can ignore its own microphone meanwhile.
    @discardableResult
    func speak(_ text: String, voiceId: String, language: String) async throws -> TimeInterval {
        let audio = try await Backend.speak(text: text, voiceId: voiceId, language: language)
        let duration = (try? AVAudioPlayer(data: audio).duration) ?? 0
        enqueue(audio)
        return duration
    }

    /// Plays one clip now, replacing anything playing (used by the Voice Settings preview).
    func playNow(_ audio: Data) throws {
        stop()
        try start(audio)
    }

    func stop() {
        queue.removeAll()
        player?.stop()
        player = nil
    }

    var isPlaying: Bool { player?.isPlaying ?? false }

    private func enqueue(_ audio: Data) {
        if player?.isPlaying == true {
            queue.append(audio)
        } else {
            try? start(audio)
        }
    }

    private func start(_ audio: Data) throws {
        // Outside a call there may be no active audio session; inside one, keep the call's session.
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            try? session.setCategory(.playback, mode: .spokenAudio)
            try? session.setActive(true)
        }
        let next = try AVAudioPlayer(data: audio)
        next.delegate = self
        next.prepareToPlay()
        next.play()
        player = next
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard player === self.player else { return }
            self.player = nil
            if !self.queue.isEmpty {
                try? self.start(self.queue.removeFirst())
            }
        }
    }
}

// MARK: - Voice Settings

/// Settings → Voice Settings: pick the voice other people hear when your speech is translated.
/// Shows 8 male and 8 female voices, previewed in your own language.
struct VoiceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var translation = LiveTranslationSession.shared

    @State private var gender: VoiceGender = .female
    @State private var slots: [Backend.VoiceSlot] = []
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var previewing: String?
    @State private var saving: String?
    @State private var errorMessage: String?
    @State private var previewCache: [String: Data] = [:]

    private var selectedId: String? { authManager.currentUser?.effectiveVoiceId }
    private var language: LiveLanguage { translation.myLanguage }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Voice type", selection: $gender) {
                        ForEach(VoiceGender.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } footer: {
                    Text("People you call hear your translated speech in this voice, in their own language. Previews play in \(language.name).")
                }

                if authManager.currentUser?.effectiveVoiceId == nil {
                    Section {
                        Label("Choose a voice so people hear you in a voice you picked.", systemImage: "info.circle")
                            .font(.subheadline)
                    }
                }

                Section {
                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if let loadError {
                        VStack(alignment: .leading, spacing: DS.spacingS) {
                            Text(loadError).font(.subheadline).foregroundStyle(.secondary)
                            Button("Try Again") { Task { await load() } }
                        }
                    } else {
                        ForEach(slots.filter { $0.gender == gender.rawValue }) { slot in
                            row(for: slot)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }
            }
            .navigationTitle("Voice Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                if let id = selectedId, id.hasPrefix(VoiceGender.male.rawValue) {
                    gender = .male
                } else if selectedId == nil, let saved = authManager.currentUser?.gender {
                    gender = saved
                }
                await load()
            }
            .onDisappear { TranslatedVoicePlayer.shared.stop() }
        }
    }

    private func row(for slot: Backend.VoiceSlot) -> some View {
        let isSelected = slot.id == selectedId
        let number = slot.id.split(separator: "-").last.map(String.init) ?? ""
        return HStack(spacing: DS.spacingM) {
            Button {
                Task { await select(slot) }
            } label: {
                HStack(spacing: DS.spacingM) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(gender.title) Voice \(number)")
                            .font(.body.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(.primary)
                        Text(describe(slot))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if saving == slot.id { ProgressView() }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(gender.title) voice \(number)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            Button {
                Task { await preview(slot) }
            } label: {
                Group {
                    if previewing == slot.id {
                        ProgressView()
                    } else {
                        Image(systemName: "play.circle.fill").font(.title2)
                    }
                }
                .frame(width: DS.minTapTarget, height: DS.minTapTarget)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Preview \(gender.title.lowercased()) voice \(number)")
        }
    }

    private func describe(_ slot: Backend.VoiceSlot) -> String {
        if slot.pitch < -0.5 { return "Deeper" }
        if slot.pitch > 0.5 { return "Higher" }
        if slot.rate < 0.98 { return "Slower" }
        if slot.rate > 1.02 { return "Faster" }
        return "Natural"
    }

    private func load() async {
        isLoading = true
        loadError = nil
        do {
            slots = try await Backend.voices(language: language.code).voices
            if slots.isEmpty { loadError = "No voices are available for \(language.name) yet." }
        } catch {
            loadError = "Couldn't load voices. Check your connection and try again."
        }
        isLoading = false
    }

    private func preview(_ slot: Backend.VoiceSlot) async {
        guard previewing == nil else { return }
        errorMessage = nil
        let key = "\(language.code)|\(slot.id)"
        do {
            if let cached = previewCache[key] {
                try TranslatedVoicePlayer.shared.playNow(cached)
                return
            }
            previewing = slot.id
            defer { previewing = nil }
            let audio = try await Backend.speak(text: Self.sample(for: language.code), voiceId: slot.id, language: language.code)
            previewCache[key] = audio
            try TranslatedVoicePlayer.shared.playNow(audio)
        } catch {
            errorMessage = "Couldn't play the preview. Please try again."
            Haptics.failure()
        }
    }

    private func select(_ slot: Backend.VoiceSlot) async {
        guard slot.id != selectedId, saving == nil else { return }
        errorMessage = nil
        saving = slot.id
        defer { saving = nil }
        do {
            try await authManager.updateVoice(slot.id)
            Haptics.success()
        } catch {
            errorMessage = "Couldn't save your voice. Please try again."
            Haptics.failure()
        }
    }

    /// Preview sentence in the user's own language.
    static func sample(for code: String) -> String {
        switch code {
        case "es": return "¡Hola! Así sonaré cuando Let Talk traduzca lo que digo."
        case "fr": return "Bonjour ! Voici ma voix quand Let Talk traduit ce que je dis."
        case "de": return "Hallo! So klinge ich, wenn Let Talk übersetzt, was ich sage."
        case "it": return "Ciao! Ecco come suonerò quando Let Talk traduce quello che dico."
        case "pt": return "Olá! É assim que vou soar quando o Let Talk traduzir o que eu digo."
        case "ru": return "Привет! Так будет звучать мой голос, когда Let Talk переводит мои слова."
        case "ja": return "こんにちは！Let Talk が私の言葉を翻訳すると、こんな声になります。"
        case "ko": return "안녕하세요! Let Talk가 제 말을 번역하면 이런 목소리로 들려요."
        case "zh": return "你好！Let Talk 翻译我说的话时，我的声音听起来是这样的。"
        case "ar": return "مرحبًا! هكذا سيبدو صوتي عندما يترجم Let Talk ما أقوله."
        case "hi": return "नमस्ते! जब Let Talk मेरी बात का अनुवाद करेगा, तो मेरी आवाज़ ऐसी सुनाई देगी।"
        default: return "Hi! This is how I'll sound when Let Talk translates what I say."
        }
    }
}
