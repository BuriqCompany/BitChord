# BitChord iOS UI

This folder contains a native SwiftUI interface prototype for iOS 15 and later. It is an original iOS implementation in the BitChord fork; the Android application and its existing features remain unchanged.

## Open in Xcode

Open `BitChordIOS.xcodeproj` and run the `BitChordIOS` scheme on an iOS 15+ simulator or device.

## Scope

The current app is a UI-only prototype. Home, Search, Library, the mini player, and the now-playing screen use sample data; audio playback, accounts, downloads, and service integrations are not connected.

The interface uses a dark palette, restrained rounded rectangles, and rectangular system-material blur for the player and bottom navigation. It intentionally avoids pill-shaped controls and Liquid Glass styling.

This repository is a fork of [kushagrasinghx/BitChord](https://github.com/kushagrasinghx/BitChord). The upstream Android project is licensed under GPL-3.0; this fork retains that license. The separate [BitChord iOS beta page](https://bitchord.hero154.com/) is used as product context, not as a source-code dependency.
