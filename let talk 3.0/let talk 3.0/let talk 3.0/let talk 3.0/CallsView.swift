import SwiftUI
import AVFoundation

struct CallsView: View {
    @StateObject private var viewModel = CallsViewModel()
    @State private var showDialpad = false
    @State private var searchText = ""
    @State private var selectedCall: CallRecord?
    @State private var showCallDetails = false
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.calls.isEmpty {
                EmptyCallsView()
            } else {
                callsList
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showDialpad = true }) {
                        Image(systemName: "phone.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                            .shadow(radius: 3)
                    }
                    .padding(.bottom, 100) // Add bottom padding to avoid tab bar
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search calls")
        .sheet(isPresented: $showDialpad) {
            EnhancedDialpadView(isPresented: $showDialpad)
        }
        .sheet(item: $selectedCall) { call in
            CallDetailsView(call: call)
        }
        .refreshable {
            await viewModel.refreshCalls()
        }
    }
    
    private var callsList: some View {
        List {
            ForEach(groupedCalls.keys.sorted(by: >), id: \.self) { date in
                Section(header: Text(formatDate(date))) {
                    ForEach(groupedCalls[date] ?? []) { call in
                        CallRow(call: call)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedCall = call
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteCall(call)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    viewModel.initiateCall(to: call.contact)
                                } label: {
                                    Label("Call", systemImage: "phone")
                                }
                                .tint(.green)
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var groupedCalls: [Date: [CallRecord]] {
        Dictionary(grouping: filteredCalls) { call in
            Calendar.current.startOfDay(for: call.timestamp)
        }
    }
    
    private var filteredCalls: [CallRecord] {
        if searchText.isEmpty {
            return viewModel.calls
        } else {
            return viewModel.calls.filter { call in
                call.contact.name.localizedCaseInsensitiveContains(searchText) ||
                call.contact.phone.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }
}

struct CallRow: View {
    let call: CallRecord
    
    var body: some View {
        HStack(spacing: 12) {
            ProfileImageView(imageURL: call.contact.imageURL,
                           placeholderText: call.contact.initials)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(call.contact.name)
                    .font(.system(size: 16, weight: .semibold))
                
                HStack {
                    Image(systemName: callTypeIcon)
                        .foregroundColor(callTypeColor)
                    
                    Text(call.type.rawValue)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    if call.isMissed {
                        Text("Missed")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatTime(call.timestamp))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                if call.duration > 0 {
                    Text(formatDuration(call.duration))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var callTypeIcon: String {
        switch call.type {
        case .audio:
            return "phone.fill"
        case .video:
            return "video.fill"
        }
    }
    
    private var callTypeColor: Color {
        call.isMissed ? .red : .blue
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}

struct EmptyCallsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "phone.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Call History")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your call history will appear here")
                .foregroundColor(.gray)
        }
    }
}

class CallsViewModel: ObservableObject {
    @Published var calls: [CallRecord] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let databaseManager = DatabaseManager.shared
    private let webRTCService = WebRTCService()
    
    init() {
        loadCalls()
    }
    
    func loadCalls() {
        isLoading = true
        
        Task {
            do {
                calls = try await databaseManager.fetchCalls()
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    func refreshCalls() async {
        do {
            calls = try await databaseManager.fetchCalls()
        } catch {
            self.error = error
        }
    }
    
    func deleteCall(_ call: CallRecord) {
        Task {
            do {
                try await databaseManager.deleteCall(call.id)
                if let index = calls.firstIndex(where: { $0.id == call.id }) {
                    calls.remove(at: index)
                }
            } catch {
                self.error = error
            }
        }
    }
    
    func initiateCall(to contact: Contact) {
        Task {
            do {
                try await webRTCService.startCall(to: contact.phone)
            } catch {
                self.error = error
            }
        }
    }
}

struct CallRecord: Identifiable {
    let id: String
    let contact: Contact
    let type: CallType
    let timestamp: Date
    let duration: Int
    let isMissed: Bool
    let direction: CallDirection
    
    enum CallType: String {
        case audio = "Audio"
        case video = "Video"
    }
    
    enum CallDirection: String {
        case incoming
        case outgoing
    }
}

// MARK: - Missing Components
struct DialpadView: View {
    @Binding var isPresented: Bool
    @State private var phoneNumber = ""
    @StateObject private var viewModel = DialpadViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(phoneNumber.isEmpty ? "Enter number" : phoneNumber)
                    .font(.title)
                    .padding()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                    ForEach(1...9, id: \.self) { number in
                        DialpadButton(number: "\(number)", letters: "")
                    }
                    
                    DialpadButton(number: "*", letters: "")
                    DialpadButton(number: "0", letters: "+")
                    DialpadButton(number: "#", letters: "")
                }
                
                HStack {
                    Button("Call") {
                        viewModel.makeCall(to: phoneNumber)
                        isPresented = false
                    }
                    .disabled(phoneNumber.isEmpty)
                    .padding()
                    .background(phoneNumber.isEmpty ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("Clear") {
                        phoneNumber = ""
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            .navigationTitle("Dialpad")
            .navigationBarItems(trailing: Button("Cancel") {
                isPresented = false
            })
        }
    }
}


class DialpadViewModel: ObservableObject {
    private let webRTCService = WebRTCService.shared
    
    func makeCall(to phoneNumber: String) {
        Task {
            do {
                try await webRTCService.startCall(to: phoneNumber)
            } catch {
                // Handle error
            }
        }
    }
}

struct CallDetailsView: View {
    let call: CallRecord
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ProfileImageView(imageURL: call.contact.imageURL, placeholderText: call.contact.initials)
                    .frame(width: 100, height: 100)
                
                Text(call.contact.name)
                    .font(.title)
                
                Text(call.contact.phone)
                    .font(.headline)
                    .foregroundColor(.blue)
                
                HStack {
                    Image(systemName: call.type == .audio ? "phone.fill" : "video.fill")
                    Text(call.type.rawValue)
                }
                
                Text("Duration: \(formatDuration(call.duration))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Call Details")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}

struct CallsView_Previews: PreviewProvider {
    static var previews: some View {
        CallsView()
    }
}
