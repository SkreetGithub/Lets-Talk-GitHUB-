#!/bin/bash

echo "Testing WebRTC build configuration..."

cd "/Volumes/Install macOS Sonoma/let talk 3.0/let talk 3.0"

# Try to build just the WebRTC-related files to check for symbol availability
echo "Checking WebRTC symbol availability..."

# Create a simple test file to verify WebRTC symbols
cat > test_webrtc_symbols.swift << 'EOF'
import WebRTC
import Foundation

// Test if RTCEAGLVideoView is available
let testView = RTCEAGLVideoView(frame: .zero)
print("RTCEAGLVideoView is available: \(type(of: testView))")

// Test if other WebRTC classes are available
let factory = RTCPeerConnectionFactory()
print("RTCPeerConnectionFactory is available: \(type(of: factory))")

let config = RTCConfiguration()
print("RTCConfiguration is available: \(type(of: config))")
EOF

echo "Test file created. Now trying to compile..."

# Try to compile the test file
swiftc -import-objc-header -framework WebRTC -framework UIKit -sdk $(xcrun --show-sdk-path --sdk iphonesimulator) test_webrtc_symbols.swift 2>&1 | head -10

# Clean up
rm -f test_webrtc_symbols.swift

echo "WebRTC symbol test completed."
