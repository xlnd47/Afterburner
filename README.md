# Afterburner

**An unofficial Apple TV client for [Boosteroid](https://cloud.boosteroid.com) cloud gaming.** Play your Boosteroid library on the big screen with a real game controller, streamed over WebRTC, in a native tvOS app built for the couch.

![Platform](https://img.shields.io/badge/platform-tvOS%2017%2B-black)
![Language](https://img.shields.io/badge/Swift-5.9%2F6-orange)
![Transport](https://img.shields.io/badge/streaming-WebRTC%20(H.264)-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-experimental-yellow)

> **Unofficial project.** Afterburner is an independent, community-built client. It is **not affiliated with, endorsed by, or supported by Boosteroid**. It talks to Boosteroid's service using the same APIs the official apps use. Use it with your own paid account, for personal and educational purposes.

---

## Overview

Boosteroid ships official apps for many platforms but not for Apple TV. Afterburner fills that gap with a native tvOS app that signs in to your Boosteroid account, lists your library, and streams a running game session straight to your TV with full controller support, including working rumble.

## Highlights

- **Cinematic interface.** The focused game's artwork fills the screen and crossfades as you browse. The Library is a clean 16:9 grid, and the Details screen shows each game full-screen.
- **Sign in with your phone.** The login screen shows a QR code. Scan it, type your email and password on your phone, and the TV signs in. No more typing with the Siri Remote.
- **Redesigned Settings.** Uniform full-width rows in the style of tvOS Settings, an account card with sign-out confirmation, and a "current setup" summary. Help & Support now lives in Settings instead of taking up a tab.
- **Faster artwork.** Images are cached in memory, so art doesn't flash back in on every focus change.

## Features

- **Native tvOS experience.** Built for the Siri Remote and a couch, not a ported web page.
- **Your Boosteroid library.** Sign in with your account and your installed games are right there, with search, sorting and favorites.
- **Low-latency streaming.** H.264 video and audio over WebRTC, the same path the official web client uses.
- **Full controller support.** MFi, Xbox, PlayStation and Nintendo Switch gamepads, with buttons, triggers, sticks and D-pad mapped exactly as the official clients do.
- **Controller rumble.** An on/off toggle plus an intensity setting (Automatic, Weak, Medium, Strong, Very Strong). Some third-party pads running in a compatibility or Xbox emulation mode don't implement vibration at all, even though their buttons work fine.
- **Server and region selection.** Mirrors cloud.boosteroid.com's account settings: allow distant regions, and pick a preferred server location (or Automatic). The server you actually connected to is shown while streaming.
- **Quality settings.** Resolution (720p / 1080p / 1440p / 4K), frame rate (60 / 120 fps), automatic or manual bitrate, and an analog-stick deadzone.
- **Optional performance overlay.** A compact HUD showing bitrate, stream FPS, network latency, and which server you're on.

## Requirements

- An Apple TV running **tvOS 17 or newer**
- An active, paid **Boosteroid** account with a password (see [Signing in](#signing-in))
- A game controller (optional, but the Siri Remote alone isn't much fun)

## Installing

Grab the `.ipa` from the [latest release](../../releases/latest) and install it with a sideloading tool such as [Sideloadly](https://sideloadly.io), signing in with your own Apple ID.

A few things worth knowing before you start:

- The `.ipa` is unsigned on purpose. The sideloading tool signs it with your Apple ID as it installs.
- On an Apple TV without a USB port, sideloading works from **macOS only**. On the Apple TV, open **Settings → Remotes and Devices → Remote App and Devices** and leave that screen open so your Mac can find it.
- With a free Apple ID the app stops working after 7 days and has to be reinstalled. A paid Apple Developer Program membership extends that to a year.

Prefer to build it yourself? See [Building](#building).

## Building

Needs **Xcode 16 or newer**. The WebRTC dependency is already referenced in the project and Xcode resolves it on first open.

1. Clone the repository and open `Afterburner.xcodeproj` in Xcode:
   ```sh
   git clone https://github.com/xlnd47/Afterburner.git
   cd Afterburner
   open Afterburner.xcodeproj
   ```
2. Let Swift Package Manager resolve the WebRTC dependency. If it fails, use **File → Packages → Reset Package Caches** then **Resolve Package Versions** (the xcframework is a large binary download and needs a working connection).
3. Configure signing: select the **Afterburner** target → **Signing & Capabilities** and pick your own team (Automatic signing). If the bundle identifier is already taken, change it to something of your own. See `Local.xcconfig.example` for an xcconfig-based alternative.

   Xcode writes your team id into `project.pbxproj` when it does this, which shouldn't be committed. Install the hook that catches it:

   ```sh
   ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
   ```
4. Pair your Apple TV in **Window → Devices and Simulators** (or pick the tvOS Simulator), select it as the run destination, and build & run (⌘R).

### Building a .ipa

To produce an installable package instead of running from Xcode:

```sh
./scripts/build-ipa.sh              # unsigned — for sideloading tools
DEVELOPMENT_TEAM=ABCDE12345 ./scripts/build-ipa.sh --signed
```

The result lands in `build/Afterburner-<version>.ipa`. Unsigned is the default, since sideloading tools sign the app with the end user's own Apple ID anyway.

## Signing in

Two ways, both on the first screen the app shows:

- **With your phone.** Scan the QR code with your phone's camera. A small sign-in page opens, served by the Apple TV itself on your local network. Type your email and password there. Your phone must be on the same network as the Apple TV. The page uses plain HTTP, since there's no way to get a trusted certificate for a local IP address; a random code in the link keeps other devices on the network from using it.
- **On the TV.** Type your email and password with the Siri Remote (or your iPhone's keyboard via the Apple TV Remote).

Use the same email you sign in with on cloud.boosteroid.com. If you created the account with "Continue with Google", it has no password at all. Set one on the website first, then sign in here with it.

## Usage

**Launching a game.** Pick a game on Home or in the Library and press Play. That enqueues a fresh session for it (waiting in Boosteroid's queue if needed), or resumes it directly if that exact game is already live on the account.

**Controls.** Pair a game controller to your Apple TV in **Settings → Remotes and Devices → Bluetooth**. In-game, press **Play/Pause** on the Siri Remote, or hold **Start + Select** on a controller, to open the options bar. The shoulder buttons switch between Home, Library and Settings.

**Settings.** Stream quality, bitrate, controller deadzone and rumble, the performance overlay, and region/server preference. Changes take effect the next time a game is started. **Help & Support** is at the bottom of Settings.

## Status & limitations

This is an **experimental** client. Signing in, launching a game, streaming, and controller input (including rumble) all work. Rough edges to expect:

- **H.264 only.** Boosteroid delivers H.265 and AV1 only over a transport this app doesn't implement, so streams are H.264. Apple TV can decode HEVC; this is a service-side limit, not a device one.
- **Disconnecting doesn't free the machine right away.** Boosteroid keeps your machine warm for a while after a session ends, so reconnecting soon after resumes the running game instead of starting fresh. The official clients behave the same way.
- **No store browsing.** You can browse, search and favorite the games already in your library, but adding new ones still has to be done from another Boosteroid client.
- **No Google sign-in.** tvOS has no browser, so accounts need a password.

## Contributing

Issues and pull requests are welcome. There is no official documentation behind this client, so real-device testing (different controllers, regions and network conditions) is especially valuable. If you're working on the streaming layer, the code comments mark what's been verified in practice versus what's still a best guess.

## Support

Afterburner is free and open source, and always will be. If it's useful to you, you can support development here:

<a href="https://buymeacoffee.com/xlnd47" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="41" width="174"></a>

## Acknowledgements

- [BoosteroidATV](https://github.com/luizhdramos/BoosteroidATV) by Luiz Ramos: the original client this project is forked from
- [`livekit/webrtc-xcframework`](https://github.com/livekit/webrtc-xcframework): the WebRTC transport
- [webrtc-streamer](https://github.com/mpromonet/webrtc-streamer): the open-source project whose REST signaling shape Boosteroid's media path mirrors
- **[CloudNow](https://github.com/owenselles/CloudNow)**: the sibling GeForce NOW tvOS client whose architecture this project follows

## License

Afterburner's source code is released under the [MIT License](LICENSE), keeping the original BoosteroidATV copyright notice.

## Legal

Afterburner is an unofficial client provided as-is, without warranty, for personal and educational use. "Boosteroid" and all related trademarks belong to their respective owners. This project is not affiliated with or endorsed by Boosteroid, and the MIT license above covers this repository's own code only. It grants no rights to Boosteroid's trademarks, branding, or backend service.
