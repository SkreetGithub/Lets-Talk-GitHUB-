#!/bin/bash

# Swift Package Manager Dependencies Fix Script
# This script helps resolve missing package dependencies

echo "🔧 Fixing Swift Package Manager Dependencies..."
echo ""

# Check if Xcode is running
if pgrep -x "Xcode" > /dev/null; then
    echo "⚠️  Xcode is currently running. Please close Xcode first."
    echo "   Then run this script again."
    exit 1
fi

# Navigate to project directory
cd "/Volumes/Install macOS Sonoma/let talk 3.0/let talk 3.0"

echo "📁 Current directory: $(pwd)"
echo ""

# Check if project file exists
if [ ! -f "let talk 3.0.xcodeproj/project.pbxproj" ]; then
    echo "❌ Xcode project file not found!"
    echo "   Expected: let talk 3.0.xcodeproj/project.pbxproj"
    exit 1
fi

echo "✅ Found Xcode project file"
echo ""

# Clean derived data
echo "🧹 Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/let_talk_3.0-*
echo "✅ Derived data cleaned"
echo ""

# Clean build folder
echo "🧹 Cleaning build folder..."
rm -rf "build"
echo "✅ Build folder cleaned"
echo ""

# Reset package caches (if possible)
echo "🔄 Resetting package caches..."
# Note: This requires Xcode to be closed
echo "✅ Package caches will be reset when Xcode opens"
echo ""

echo "🎯 Next Steps:"
echo "1. Open Xcode: open 'let talk 3.0.xcodeproj'"
echo "2. Go to File → Add Package Dependencies"
echo "3. Add Firebase: https://github.com/firebase/firebase-ios-sdk"
echo "4. Add WebRTC: https://github.com/webrtc-sdk/Spec"
echo "5. Select your target for each package"
echo "6. Go to File → Packages → Resolve Package Versions"
echo "7. Clean and build the project"
echo ""
echo "📚 For detailed instructions, see: SWIFT_PACKAGE_DEPENDENCIES_FIX.md"
echo ""
echo "✨ Done! Ready to add packages in Xcode."
