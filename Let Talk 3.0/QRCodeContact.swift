import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins
import PhotosUI
import VisionKit

// MARK: - Payload

/// In-app QR codes for adding a contact. The code holds `lettalk:add:<user id>`; it isn't a web
/// link, so it only does something when scanned inside Let Talk (not from the iPhone Camera app).
enum LetTalkQR {
    static let prefix = "lettalk:add:"

    static func payload(for userId: String) -> String {
        prefix + userId.lowercased()
    }

    /// The Let Talk user ID inside a scanned code, or nil if it isn't a Let Talk code.
    static func userId(from payload: String) -> String? {
        let text = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.lowercased().hasPrefix(prefix) else { return nil }
        let id = String(text.dropFirst(prefix.count))
        return UUID(uuidString: id) != nil ? id.lowercased() : nil
    }

    /// A crisp QR image (each module scaled up, no smoothing).
    static func image(for text: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// Reads a QR code from a photo (used by "Scan from Photo", and on devices without a camera).
    static func decode(from image: UIImage) -> String? {
        guard let ciImage = CIImage(image: image),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]) else { return nil }
        return detector.features(in: ciImage)
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            .first
    }
}

enum QRAddError: LocalizedError {
    case notLetTalkCode
    case ownCode
    case accountNotFound
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notLetTalkCode: return "That isn't a Let Talk QR code."
        case .ownCode: return "That's your own QR code."
        case .accountNotFound: return "That QR code belongs to an account that no longer exists."
        case .notSignedIn: return "Please sign in again."
        }
    }
}

// MARK: - My QR Code

/// Shows the signed-in user's QR code. Opened from Settings → Profile → My QR Code.
struct MyQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.spacingL) {
                Spacer(minLength: DS.spacingM)

                if let userId = authManager.currentUserId,
                   let image = LetTalkQR.image(for: LetTalkQR.payload(for: userId)) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .padding(DS.spacingM)
                        // Always black-on-white, even in dark mode, so it scans reliably.
                        .background(RoundedRectangle(cornerRadius: DS.cornerRadiusL).fill(Color.white))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                        .accessibilityLabel("Your Let Talk QR code")
                } else {
                    ContentUnavailableView(
                        "QR Code Unavailable",
                        systemImage: "qrcode",
                        description: Text("Sign out and back in to show your code.")
                    )
                }

                VStack(spacing: DS.spacingXS) {
                    Text(authManager.currentUser?.name ?? "")
                        .font(.title2.bold())
                    if let phone = authManager.currentUser?.phone, !phone.isEmpty {
                        Text(phone)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Friends can add you by opening Let Talk → Contacts → Add Contact → Scan QR Code.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.spacingL)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Scanner

/// Scans a Let Talk QR code and adds that person as a contact. Uses the live camera where
/// available; "Scan from Photo" works everywhere, including the Simulator (no camera).
struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    /// Called with the added contact (after the scanner has started to close).
    let onAdded: (Contact) -> Void

    private enum Phase: Equatable {
        case scanning
        case adding
        case failed(String)
    }

    @State private var phase: Phase = .scanning
    @State private var cameraState: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var photoItem: PhotosPickerItem?

    private var canScanLive: Bool {
        cameraState == .authorized
            && DataScannerViewController.isSupported
            && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if canScanLive {
                    LiveQRScanner { handle($0) }
                        .ignoresSafeArea()
                } else {
                    unavailableMessage
                }

                VStack {
                    Spacer()
                    bottomPanel
                }
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // Ask for the camera here, in context, rather than letting the scanner fail silently.
                if cameraState == .notDetermined {
                    let granted = await AVCaptureDevice.requestAccess(for: .video)
                    cameraState = granted ? .authorized : .denied
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await scanPhoto(item) }
            }
        }
    }

    private var unavailableMessage: some View {
        let denied = cameraState == .denied || cameraState == .restricted
        return ContentUnavailableView {
            Label(denied ? "Camera Access Off" : "Camera Scanning Unavailable",
                  systemImage: denied ? "camera.badge.ellipsis" : "qrcode.viewfinder")
        } description: {
            Text(denied
                 ? "Turn on camera access for Let Talk in Settings, or choose a photo of a Let Talk QR code."
                 : "Choose a photo of a Let Talk QR code instead.")
        } actions: {
            if denied, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { UIApplication.shared.open(url) }
            }
        }
        .foregroundStyle(.white)
    }

    private var bottomPanel: some View {
        VStack(spacing: DS.spacingM) {
            Group {
                switch phase {
                case .scanning:
                    Text(canScanLive ? "Point the camera at a Let Talk QR code." : " ")
                case .adding:
                    HStack(spacing: DS.spacingS) {
                        ProgressView()
                        Text("Adding contact…")
                    }
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.circle.fill")
                }
            }
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Scan from Photo", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: DS.primaryButtonHeight)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(phase == .adding)
        }
        .padding(DS.spacingL)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.cornerRadiusL))
        .padding(DS.spacingM)
    }

    private func scanPhoto(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            phase = .failed("Couldn't open that photo.")
            Haptics.failure()
            return
        }
        guard let payload = LetTalkQR.decode(from: image) else {
            phase = .failed("No QR code found in that photo.")
            Haptics.failure()
            return
        }
        handle(payload)
    }

    private func handle(_ payload: String) {
        guard phase != .adding else { return }
        guard let userId = LetTalkQR.userId(from: payload) else {
            phase = .failed(QRAddError.notLetTalkCode.localizedDescription)
            Haptics.failure()
            return
        }
        phase = .adding
        Task {
            do {
                let contact = try await ContactManager.shared.addContact(letTalkUserId: userId)
                Haptics.success()
                dismiss()
                onAdded(contact)
            } catch {
                phase = .failed(error.localizedDescription)
                Haptics.failure()
            }
        }
    }
}

/// VisionKit live scanner limited to QR codes.
private struct LiveQRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        // Start once the view is on screen (starting inside makeUIViewController can fail).
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            // didAdd fires once each time a code comes into view, so a failed code can be
            // retried by moving it out of view and back.
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue else { continue }
                DispatchQueue.main.async { self.onCode(payload) }
                return
            }
        }
    }
}
