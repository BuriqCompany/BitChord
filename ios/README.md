# BitChord iOS UI

This folder contains a native SwiftUI app for iOS 15 and later. It is an original iOS implementation in the BitChord fork; the Android application and its existing features remain unchanged.

## Open in Xcode

Open `BitChordIOS.xcodeproj` and run the `BitChordIOS` scheme on an iOS 15+ simulator or device.

## Music

Use **Add songs from Files** in Home or Library to import audio from the iPhone's Files app. Imported files are copied into the app's local Documents folder and can be played from the Library and mini player. The app does not stream YouTube Music, sign in to accounts, or sync with the Android app. Sample artwork on Home is only a design preview, not playable audio.

The player uses a full-screen, album-color backdrop and dark `UIVisualEffectView` material on its controls and navigation, following the blurred artwork treatment used by BitChord. The layout targets iOS 15 and uses restrained rounded rectangles rather than Liquid Glass styling.

This repository is a fork of [kushagrasinghx/BitChord](https://github.com/kushagrasinghx/BitChord). The upstream Android project is licensed under GPL-3.0; this fork retains that license. The separate [BitChord iOS beta page](https://bitchord.hero154.com/) is used as product context, not as a source-code dependency.
