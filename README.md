# PrismTUN

A macOS proxy client powered by [sing-box](https://github.com/SagerNet/sing-box).

## Requirements

| Component | Minimum version |
|-----------|----------------|
| macOS | 14.0 (Sonoma) |
| Xcode | 16.0 |
| sing-box | **1.10.0** |
| xcodegen | 2.38+ |

## Build

### 1. Install tooling

```bash
brew install xcodegen
```

### 2. Generate the Xcode project

```bash
xcodegen generate
```

### 3. Build (sing-box binary is fetched automatically)

```bash
xcodebuild -scheme PrismTUN -destination 'platform=macOS' build
```

On first build, the pre-build script (`Scripts/fetch-singbox.sh`) downloads the latest
sing-box universal binary (arm64 + x86_64) from GitHub Releases and lipo-combines it.
The post-build script embeds it at `Contents/Resources/sing-box` inside the app bundle.

To pre-fetch the binary without building:

```bash
bash Scripts/fetch-singbox.sh
```

## Connection modes

| Mode | Description |
|------|-------------|
| System Proxy | Sets macOS HTTP/HTTPS/SOCKS system proxy to `127.0.0.1:2080` |
| Global | Routes all traffic through the proxy outbound |
| Direct | All traffic bypasses the proxy |

## TUN mode (Phase 9)

TUN mode requires:
- **Developer ID Application** certificate (not available with free Apple accounts)
- A provisioning profile with the `com.apple.developer.networking.networkextension` capability
  (`packet-tunnel-provider` entitlement)
- System Extension approval on the target Mac

Ad-hoc signed builds (`CODE_SIGN_IDENTITY = "-"`) cannot use TUN mode.

## sing-box binary

The binary is **not committed** to this repository. It is downloaded at build time by
`Scripts/fetch-singbox.sh`. The file is listed in `.gitignore` at
`PrismTUN/Resources/Binaries/sing-box`.

Minimum supported version: **1.10.0**. The Clash-compatible API (`experimental.clash_api`)
and the TUN inbound features used by PrismTUN require this version or later.

## License

MIT
