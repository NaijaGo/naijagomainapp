#!/bin/bash

# Exit if any command fails
set -e

# Change directory to the root of the project
cd $CI_PRIMARY_REPOSITORY_PATH

echo "==> Setting up Flutter Environment..."

# Install Flutter SDK using a stable, known version (you can change this if needed)
FLUTTER_VERSION="3.32.8" # Replace with your flutter --version output if different
curl -sLO "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_${FLUTTER_VERSION}-stable.zip"
unzip -qq flutter_macos_${FLUTTER_VERSION}-stable.zip -d $HOME
export PATH="$PATH:$HOME/flutter/bin"
flutter --version

# Run Flutter commands
echo "==> Running flutter precache, pub get, and build"
flutter precache --ios # Install artifacts for iOS
flutter pub get

# Install CocoaPods using Homebrew
echo "==> Installing CocoaPods"
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

# Install CocoaPods dependencies for the iOS project
echo "==> Running pod install for iOS"
cd ios
pod install
