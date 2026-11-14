import SwiftUI

// The separate Settings screen that used to open from the Chats ⚙︎ button was merged into
// More › Settings (UnifiedSettingsView). Its style controls live on here as "Chat & Call Style",
// opened from More › Settings › Appearance.

/// Theme, chat bubble and call screen styling.
struct ChatStyleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        NavigationView {
            List {
                appearanceSection
                chatCallSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Chat & Call Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Appearance Section
    private var appearanceSection: some View {
        Section {
            // Theme Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        ThemePreviewCard(
                            theme: theme,
                            isSelected: settingsManager.settings.theme == theme,
                            action: {
                                settingsManager.setTheme(theme)
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Chat Bubble Colors
            VStack(alignment: .leading, spacing: 12) {
                Text("Chat Bubbles")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sent Messages")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                            ForEach(ChatBubbleColor.allCases, id: \.self) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: settingsManager.settings.chatBubbles.sentColor == color ? 2 : 0)
                                    )
                                    .onTapGesture {
                                        settingsManager.setChatBubbleSentColor(color)
                                    }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Call Interface Background
            VStack(alignment: .leading, spacing: 12) {
                Text("Call Interface")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(CallBackgroundColor.allCases, id: \.self) { color in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color.color)
                                .frame(height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary, lineWidth: settingsManager.settings.callInterface.background == color ? 2 : 0)
                                )
                            
                            Text(color.displayName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .onTapGesture {
                            settingsManager.setCallInterfaceBackground(color)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Appearance")
        }
    }
    
    // MARK: - Chat & Call Section
    private var chatCallSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Chat Bubbles")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Corner Radius")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { settingsManager.settings.chatBubbles.cornerRadius },
                            set: { settingsManager.settings.chatBubbles.cornerRadius = $0; settingsManager.saveSettings() }
                        ),
                        in: 8.0...24.0,
                        step: 2.0
                    )
                    
                    Text("\(Int(settingsManager.settings.chatBubbles.cornerRadius))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Size")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: Binding(
                            get: { settingsManager.settings.chatBubbles.fontSize },
                            set: { settingsManager.settings.chatBubbles.fontSize = $0; settingsManager.saveSettings() }
                        ),
                        in: 12.0...20.0,
                        step: 1.0
                    )
                    
                    Text("\(Int(settingsManager.settings.chatBubbles.fontSize))pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Chat & Call")
        }
    }
    
}

// MARK: - Theme Preview Card
struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if theme.isGradient {
                    LinearGradient(
                        gradient: Gradient(colors: theme.gradientColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme == .light ? Color.white : theme == .dark ? Color.black : Color.primary)
                        .frame(height: 40)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: theme.icon)
                        .font(.caption)
                    Text(theme.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.primary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ChatStyleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ChatStyleSettingsView()
    }
}
