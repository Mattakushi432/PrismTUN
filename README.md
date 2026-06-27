# PrismTUN

A macOS menu-bar proxy client powered by [sing-box](https://github.com/SagerNet/sing-box).

Supports Shadowsocks, VMess, VLESS (+Reality), Trojan, Hysteria2, TUIC, WireGuard, ShadowTLS, and more.

## Features

- **System Proxy** and **TUN** connection modes
- Subscription management with auto-update
- Live latency testing with colour-coded badges
- Routing rules editor with geosite/geoip presets
- Real-time traffic stats and live log streaming
- Active connections viewer (close individual or all)
- DNS settings: DoH, DoT, DoQ, FakeIP, custom rules
- Geo asset auto-updater (geoip.db / geosite.db)
- QR code import and export for profiles
- Menu bar quick-switcher for profiles and modes

## Requirements

| Component | Minimum version |
|-----------|----------------|
| macOS | 14.0 (Sonoma) |
| Xcode | 16.0 |
| sing-box | **1.10.0** |
| xcodegen | 2.38+ |

## Quick start

```bash
brew install xcodegen
git clone https://github.com/Mattakushi432/PrismTUN.git
cd PrismTUN
xcodegen generate
open PrismTUN.xcodeproj
```

Build and run the **PrismTUN** scheme in Xcode. The sing-box binary is fetched automatically on first build.

## Build from the command line

```bash
# 1. Install xcodegen
brew install xcodegen

# 2. Generate project
xcodegen generate

# 3. Build (sing-box binary fetched automatically by the pre-build script)
xcodebuild \
  -scheme PrismTUN \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  build
```

To pre-fetch the binary without building:

```bash
bash Scripts/fetch-singbox.sh
```

## Running tests

```bash
xcodebuild test \
  -scheme PrismTUNTests \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

84 unit tests covering URI parsers, `SingBoxConfigBuilder` outbounds, subscription parsing, and routing rule serialisation.

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘1 | Dashboard |
| ⌘2 | Profiles |
| ⌘3 | Routing |
| ⌘4 | Connections |
| ⌘5 | Logs |
| ⌘6 | Settings |
| ⌘N | New profile |
| ⌘K | Connect / Disconnect |

## Connection modes

| Mode | Description |
|------|-------------|
| System Proxy | Sets macOS HTTP/HTTPS/SOCKS proxy to `127.0.0.1:2080` |
| Global | Routes all traffic through the proxy outbound |
| Direct | All traffic bypasses the proxy |
| TUN | Full tunnel via `NEPacketTunnelProvider` (requires signing) |

## Importing subscriptions

1. Open **Profiles → Add Subscription** (or press ⌘N then switch to Subscriptions).
2. Paste the subscription URL and configure update interval.
3. Click **Update** — profiles are parsed and grouped under the subscription name.
4. Select a profile with a green latency badge, then click **Connect**.

Supported subscription formats: base64-encoded URI list, plain-text URI list.

## TUN mode

TUN mode requires:

- **Developer ID Application** certificate (not available with free Apple accounts).
- A provisioning profile with the `com.apple.developer.networking.networkextension` capability (`packet-tunnel-provider` entitlement).
- User approval of the System Extension on the target Mac.

Ad-hoc signed builds (`CODE_SIGN_IDENTITY = "-"`) cannot activate TUN mode. The app falls back to System Proxy automatically.

## sing-box binary

The binary is **not committed** to this repository. It is downloaded at build time by `Scripts/fetch-singbox.sh` from the latest GitHub Release and lipo-merged into a universal binary (arm64 + x86_64). The result is embedded at `Contents/Resources/sing-box` inside the app bundle.

Minimum supported version: **1.10.0**. The Clash-compatible API (`experimental.clash_api`) and TUN inbound require this version or later.

## CI

GitHub Actions runs on `macos-15` on every push to `main` and `tests-ci`:

- **build** job: `xcodegen generate` → `xcodebuild build`.
- **test** job: `xcodegen generate` → SwiftLint → `xcodebuild test -scheme PrismTUNTests` (84 unit tests).

## License

MIT
