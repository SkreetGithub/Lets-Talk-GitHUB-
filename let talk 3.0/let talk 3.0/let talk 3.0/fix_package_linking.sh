#!/bin/bash

echo "🔧 Fixing Swift Package Manager Linking Issues..."
echo ""

# Check if Xcode is running
if pgrep -x "Xcode" > /dev/null; then
    echo "⚠️  Xcode is currently running. Closing Xcode..."
    pkill -f Xcode
    sleep 3
fi

echo "🧹 Cleaning all build data and caches..."

# Remove derived data
echo "   Removing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Remove project build folder
echo "   Removing project build folder..."
rm -rf "/Volumes/Install macOS Sonoma/let talk 3.0/let talk 3.0/build"

# Clear Swift Package Manager caches
echo "   Clearing Swift Package Manager caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm

# Clear Xcode caches
echo "   Clearing Xcode caches..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode

echo "✅ All caches and build data cleared"
echo ""

echo "📦 Package URLs to add in Xcode:"
echo ""
echo "Firebase iOS SDK:"
echo "   https://github.com/firebase/firebase-ios-sdk"
echo ""
echo "WebRTC iOS SDK:"
echo "   https://github.com/webrtc-sdk/Spec"
echo ""

echo "🎯 Next Steps:"
echo "1. Open Xcode: open 'let talk 3.0.xcodeproj'"
echo "2. Remove any existing Firebase/WebRTC packages from Package Dependencies"
echo "3. Add Firebase package with URL above"
echo "4. Select these products: FirebaseAuth, FirebaseCore, FirebaseFirestore, FirebaseMessaging"
echo "5. IMPORTANT: Select your app target when prompted"
echo "6. Add WebRTC package with URL above"
echo "7. Select WebRTC product and your app target"
echo "8. Go to File → Packages → Resolve Package Versions"
echo "9. Clean and build the project"
echo ""

echo "🔍 Verification:"
echo "- Check that packages appear in 'Frameworks, Libraries, and Embedded Content'"
echo "- Verify no 'Missing package product' errors"
echo "- Ensure project builds successfully"
echo ""

echo "📚 For detailed instructions, see: PACKAGE_LINKING_FIX.md"
echo ""
echo "✨ Ready to fix package linking in Xcode!"
