#!/bin/bash

echo "🔍 Checking for missing components in Let's Talk 3.0..."
echo ""

# Check for main app files
echo "📱 Main App Files:"
files=(
    "let_talk_3_0App.swift"
    "MainTabView.swift"
    "AuthView.swift"
    "AuthManager.swift"
    "Config.swift"
    "GoogleService-Info.plist"
)

for file in "${files[@]}"; do
    if [ -f "let talk 3.0/$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file - MISSING"
    fi
done

echo ""
echo "🎯 Core Views:"
views=(
    "ChatsView.swift"
    "ChatDetailView.swift"
    "CallsView.swift"
    "CallView.swift"
    "ContactsView.swift"
    "TranslatorView.swift"
    "SettingsManager.swift"
    "NotificationManager.swift"
)

for view in "${views[@]}"; do
    if [ -f "let talk 3.0/$view" ]; then
        echo "✅ $view"
    else
        echo "❌ $view - MISSING"
    fi
done

echo ""
echo "🔧 Services & Managers:"
services=(
    "WebRTCService.swift"
    "SignalingClient.swift"
    "TranslationService.swift"
    "MessageManager.swift"
    "ContactManager.swift"
    "DataPersistenceManager.swift"
    "DatabaseManager.swift"
)

for service in "${services[@]}"; do
    if [ -f "let talk 3.0/$service" ]; then
        echo "✅ $service"
    else
        echo "❌ $service - MISSING"
    fi
done

echo ""
echo "📦 Models:"
models=(
    "Message.swift"
    "Contact.swift"
    "AppNotification.swift"
)

for model in "${models[@]}"; do
    if [ -f "let talk 3.0/$model" ]; then
        echo "✅ $model"
    else
        echo "❌ $model - MISSING"
    fi
done

echo ""
echo "🎨 UI Components:"
ui_components=(
    "UIComponents.swift"
    "OfflineIndicatorView.swift"
    "PhoneVerificationView.swift"
)

for component in "${ui_components[@]}"; do
    if [ -f "let talk 3.0/$component" ]; then
        echo "✅ $component"
    else
        echo "❌ $component - MISSING"
    fi
done

echo ""
echo "📚 Documentation:"
docs=(
    "FIREBASE_CONFIGURATION_GUIDE.md"
    "GOOGLE_SIGNIN_SETUP.md"
    "BUILD_ISSUE_RESOLUTION.md"
    "DUPLICATE_INFOPLIST_FIX.md"
)

for doc in "${docs[@]}"; do
    if [ -f "let talk 3.0/$doc" ]; then
        echo "✅ $doc"
    else
        echo "❌ $doc - MISSING"
    fi
done

echo ""
echo "🔍 Checking for common missing components..."

# Check for specific missing components
missing_components=()

# Check if ContactRow is defined
if ! grep -q "struct ContactRow" "let talk 3.0/ContactsView.swift"; then
    missing_components+=("ContactRow")
fi

# Check if ProfileImageView is defined
if ! grep -q "struct ProfileImageView" "let talk 3.0/UIComponents.swift"; then
    missing_components+=("ProfileImageView")
fi

# Check if DocumentPicker is defined
if ! grep -q "struct DocumentPicker" "let talk 3.0/OfflineIndicatorView.swift"; then
    missing_components+=("DocumentPicker")
fi

if [ ${#missing_components[@]} -eq 0 ]; then
    echo "✅ All common components are present"
else
    echo "❌ Missing components:"
    for component in "${missing_components[@]}"; do
        echo "   - $component"
    done
fi

echo ""
echo "📊 Summary:"
total_files=$(find "let talk 3.0" -name "*.swift" | wc -l)
echo "Total Swift files: $total_files"

total_docs=$(find "let talk 3.0" -name "*.md" | wc -l)
echo "Total documentation files: $total_docs"

echo ""
echo "✨ Component check complete!"
