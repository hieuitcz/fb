# FBAudioFix

A rootless iOS tweak focused on Facebook's `AVAudioSession` behavior.

Facebook can occasionally switch to an exclusive Playback audio session while the user is only browsing the feed, interrupting audio from apps such as YouTube. FBAudioFix suppresses those passive Playback transitions while preserving intentional Facebook media playback.

## Current behavior

- Keeps background audio alive during passive Facebook feed browsing.
- Ignores ordinary Facebook bottom-tab taps as media intent.
- Recognizes the Facebook Reels tab semantically and grants it a dedicated 3-second media-intent window.
- Preserves intentional playback when the user opens/taps Facebook video.
- Releases Facebook's exclusive audio state when returning to News Feed.
- Ignores the Home navigation Menu button as media intent.
- Includes a short post-release guard to prevent delayed Facebook Playback requests from immediately reclaiming the audio session.

## Tested

Primary development/testing:
- Facebook 578.1.0
- iOS 17.0, Dopamine rootless
- Injected dylib workflow

Additional validation:
- iPhone 17 Pro Max / iOS 27
- dylib injected into Facebook, dumped as IPA, then signed/installed with Feather

Because Facebook changes internal UI classes and accessibility identifiers over time, future Facebook versions may require updates.

## Build

Requires Theos and an iOS SDK.

```sh
make clean
rm -rf .theos
make package THEOS_PACKAGE_SCHEME=rootless
```

The package is built for `iphoneos-arm64`.

## Injection

The built `FBAudioFix.dylib` can also be injected directly into Facebook. The tweak is filtered to the Facebook app and does not need a preference bundle.

## License

MIT
