#!/bin/bash

echo "Resetting app state to show splash screen..."

# Reset UserDefaults for the app
defaults delete com.upappllc.Let-s-Talk- 2>/dev/null || true

# Reset onboarding state
defaults write com.upappllc.Let-s-Talk- hasCompletedOnboarding -bool false

# Reset demo mode
defaults write com.upappllc.Let-s-Talk- isDemoMode -bool false

# Reset authentication state
defaults write com.upappllc.Let-s-Talk- isAuthenticated -bool false

echo "App state reset complete!"
echo "Now when you run the app, you should see the splash screen."
echo ""
echo "To run the app:"
echo "1. Open Xcode"
echo "2. Select the 'let talk 3.0' project"
echo "3. Choose a simulator or device"
echo "4. Press Cmd+R to run"
