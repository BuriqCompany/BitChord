# BitChord iOS

This folder contains a native SwiftUI app for iOS 15 and later. It keeps the existing BitChord-inspired player UI and uses a Kotlin Multiplatform framework for YouTube stream resolution.

## Open in Xcode

Open `BitChordIOS.xcodeproj` and run the `BitChordIOS` scheme on an iOS 15+ simulator or device. Before opening Xcode, build the playback framework with `./gradlew -p ios/streamresolver linkReleaseFrameworkIosArm64 linkReleaseFrameworkIosSimulatorArm64`; GitHub Actions runs the same build before Xcode.

## YouTube Music

Home and Search fetch real song results from YouTube Music's WEB_REMIX/InnerTube endpoint without requiring sign-in. Selecting a result resolves an AAC stream through the GPL-licensed InnerTubeX library and plays it with `AVPlayer` inside BitChord. The AVAudioSession is configured for background playback.

SponsorBlock looks up skip segments through its privacy endpoint using a four-character SHA-256 video-ID prefix; it does not send the full video ID to SponsorBlock. Sponsor, self-promotion, and interaction segments are skipped during playback. SponsorBlock is an independent service, and its segment data may be unavailable or out of date.

The player uses the selected song's artwork with a visible iOS 15 `UIVisualEffectView` blur backdrop and rectangular controls inspired by BitChord. InnerTube and SponsorBlock are unofficial integrations and may change independently. No Google account cookies are collected by this iOS implementation.

SponsorBlock data is provided by the SponsorBlock community under CC BY-NC-SA 4.0; attribution is shown in the player. See the [SponsorBlock API and database license](https://github.com/ajayyy/SponsorBlock/wiki/Database-and-API-License) and [API documentation](https://wiki.sponsor.ajay.app/w/API_Docs).

This repository is a fork of [kushagrasinghx/BitChord](https://github.com/kushagrasinghx/BitChord). The upstream Android project is licensed under GPL-3.0; this fork retains that license. The separate [BitChord iOS beta page](https://bitchord.hero154.com/) is used as product context, not as a source-code dependency.
