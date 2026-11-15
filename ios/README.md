# BitChord iOS UI

This folder contains a native SwiftUI app for iOS 15 and later. It is an original iOS implementation in the BitChord fork; the Android application and its existing features remain unchanged.

## Open in Xcode

Open `BitChordIOS.xcodeproj` and run the `BitChordIOS` scheme on an iOS 15+ simulator or device.

## YouTube Music

Home and Search fetch real song results from YouTube Music's WEB_REMIX/InnerTube search endpoint without requiring sign-in. Selecting a result opens its official YouTube Music watch page for playback; audio is not extracted or played inside the app. YouTube Music's unofficial endpoint can change without notice.

The native player uses the selected song's artwork with a visible iOS 15 `UIVisualEffectView` blur backdrop and rectangular controls inspired by BitChord. It does not import local audio or use sample songs.

This repository is a fork of [kushagrasinghx/BitChord](https://github.com/kushagrasinghx/BitChord). The upstream Android project is licensed under GPL-3.0; this fork retains that license. The separate [BitChord iOS beta page](https://bitchord.hero154.com/) is used as product context, not as a source-code dependency.
