# PrismTUN — Native macOS Proxy Client

## Overview

PrismTUN is a native macOS proxy client in the spirit of NekoBox / NekoRay.
It embeds **sing-box** as its core tunnel engine and wraps it in a polished
SwiftUI menu-bar application.

## Feature Set

| Feature | MVP | Phase 2 |
|---|---|---|
| Menu-bar toggle (on/off) | ✅ | |
| System HTTP/SOCKS proxy | ✅ | |
| Multi-profile management | ✅ | |
| Protocol: Shadowsocks | ✅ | |
| Protocol: VMess / VLESS | ✅ | |
| Protocol: Trojan | ✅ | |
| Protocol: SOCKS5 / HTTP | ✅ | |
| URI import (ss://, vmess://, vless://, trojan://) | ✅ | |
| Real-time traffic stats | ✅ | |
| Real-time log viewer | ✅ | |
| Routing rules (domain, IP, GEOIP, GEOSITE) | | ✅ |
| Subscription URL auto-update | | ✅ |
| TUN mode (NetworkExtension) | | ✅ |
| Sparkle auto-update | | ✅ |

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│                   SwiftUI Layer                  │
│  MenuBar  Dashboard  Profiles  Logs  Settings   │
└───────────────────┬─────────────────────────────┘
                    │ @Observable ViewModels
┌───────────────────▼─────────────────────────────┐
│                   Core Layer                     │
│  VPNManager  ProfileManager  SingBoxManager     │
│  SystemProxyManager  NetworkMonitor             │
└───────────────────┬─────────────────────────────┘
                    │ Process + REST API
┌───────────────────▼─────────────────────────────┐
│              sing-box binary                     │
│  (embedded in app bundle as Resources/sing-box)  │
└─────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **sing-box subprocess** — PrismTUN launches the bundled sing-box binary,
   feeds it a generated JSON config, and communicates via the Clash-compatible
   REST API on `127.0.0.1:9090`.

2. **System proxy, not TUN** for MVP — `networksetup` sets the global HTTP/SOCKS
   proxy; no special entitlements required.

3. **`@Observable` throughout** — all view models use the iOS 17+ Observation
   framework for fine-grained SwiftUI invalidation.

4. **Actor-isolated managers** — `SingBoxManager`, `ProfileManager`, and
   `SystemProxyManager` are Swift actors for safe concurrent access.

---

## Project Structure

```
PrismTUN/
├── PrismTUN/                        ← Main app target
│   ├── App/
│   │   └── PrismTUNApp.swift        ← Entry point, lifecycle, menu-bar setup
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── ProxyProfile.swift
│   │   │   ├── ProxyProtocol.swift
│   │   │   ├── ConnectionMode.swift
│   │   │   ├── RoutingRule.swift
│   │   │   ├── TrafficStats.swift
│   │   │   └── LogEntry.swift
│   │   ├── Managers/
│   │   │   ├── VPNManager.swift
│   │   │   ├── ProfileManager.swift
│   │   │   ├── SingBoxManager.swift
│   │   │   ├── SingBoxConfigBuilder.swift
│   │   │   └── SystemProxyManager.swift
│   │   └── Infrastructure/
│   │       ├── ProfileStore.swift
│   │       └── NetworkMonitor.swift
│   └── Features/
│       ├── ContentView.swift
│       ├── MenuBar/
│       │   └── MenuBarController.swift
│       ├── Dashboard/
│       │   ├── DashboardView.swift
│       │   └── DashboardViewModel.swift
│       ├── Profiles/
│       │   ├── ProfileListView.swift
│       │   ├── AddProfileView.swift
│       │   └── ProfilesViewModel.swift
│       ├── Logs/
│       │   ├── LogsView.swift
│       │   └── LogsViewModel.swift
│       └── Settings/
│           └── SettingsView.swift
└── PacketTunnelProvider/            ← Phase 2: NetworkExtension target
    └── PacketTunnelProvider.swift
```

---

## Xcode Project Setup

1. Create new macOS App project named **PrismTUN**
2. Language: Swift · Interface: SwiftUI · Minimum deployment: macOS 14.0
3. Set `LSUIElement = YES` in Info.plist (hides from Dock)
4. Add `sing-box` binary to target → **Resources** group
5. Enable entitlements:
   - `com.apple.security.network.client` — outbound connections
   - `com.apple.security.network.server` — local proxy listener

### sing-box Binary

Download the latest macOS universal binary from
https://github.com/SagerNet/sing-box/releases and place at:

```
PrismTUN/Resources/sing-box
```

---

## sing-box REST API

sing-box exposes a Clash-compatible REST API when `experimental.clash_api` is
configured:

| Endpoint | Method | Purpose |
|---|---|---|
| `/traffic` | GET (SSE) | Real-time traffic bytes |
| `/logs` | GET (SSE) | Real-time log stream |
| `/proxies` | GET | All outbound selectors |
| `/proxies/{name}` | PUT | Select active outbound |
| `/version` | GET | sing-box version |

---

## Implementation Phases

### Phase 1 — MVP (current)
- [x] Project skeleton
- [x] Core models
- [x] sing-box process manager
- [x] Config builder (SS, VMess, VLESS, Trojan, SOCKS5, HTTP)
- [x] System proxy manager
- [x] Profile CRUD + persistence
- [x] SwiftUI: Dashboard, Profiles, Logs, Settings
- [x] Menu-bar integration

### Phase 2
- [ ] Subscription URL fetching + node import
- [ ] Routing rules UI
- [ ] TUN mode (NetworkExtension target)
- [ ] Sparkle auto-update
- [ ] GitHub Actions CI/CD

### Phase 3
- [ ] Rule-set editor (GEOIP/GEOSITE)
- [ ] Multiple simultaneous profiles (group)
- [ ] Localization (EN / ZH / RU / UA)
- [ ] TestFlight / notarized release
