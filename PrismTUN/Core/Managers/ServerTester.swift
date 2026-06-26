import Foundation
import Network
import os

// MARK: - Errors

enum LatencyError: LocalizedError, Sendable {
    case timeout
    var errorDescription: String? { String(localized: "Connection timed out") }
}

// MARK: - Duration helper

extension Duration {
    /// Converts a Swift Duration to integer milliseconds (sub-ms truncated).
    var milliseconds: Int {
        Int(components.seconds * 1_000) + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}

// MARK: - ServerTester

/// Tests proxy server latency via TCP handshake or real HTTP round-trip through a temporary sing-box instance.
///
/// All network operations are `nonisolated` so concurrent `batchTest` child tasks do not serialize
/// on the actor's executor — each ping runs in parallel on the cooperative thread pool.
actor ServerTester {
    static let shared = ServerTester()
    private init() {}

    // MARK: - TCP Ping

    /// Measures the TCP handshake latency to `profile.server:profile.port`.
    /// Returns ~99 s on failure or timeout (5-second hard deadline).
    nonisolated func tcpPing(profile: ProxyProfile) async -> Duration {
        let start = ContinuousClock.now
        let host  = NWEndpoint.Host(profile.server)
        let portValue = UInt16(clamping: profile.port)
        let nwPort = NWEndpoint.Port(rawValue: portValue) ?? .https
        let conn   = NWConnection(host: host, port: nwPort, using: .tcp)

        return await withCheckedContinuation { cont in
            let once = ResumeOnce(cont)

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    once.resume(ContinuousClock.now - start)
                    conn.cancel()
                case .failed, .cancelled:
                    once.resume(.seconds(99))
                default:
                    break
                }
            }
            conn.start(queue: .global(qos: .utility))

            // Hard timeout — cancelled connection triggers .cancelled in the handler above
            Task.detached {
                try? await Task.sleep(for: .seconds(5))
                conn.cancel()
                once.resume(.seconds(99))
            }
        }
    }

    // MARK: - URL Test (real HTTP through a temp sing-box process)

    /// Launches a temporary sing-box instance on a free loopback port, then measures HTTP RTT
    /// to `url` through that proxy. Returns `nil` if sing-box binary is unavailable or connection fails.
    nonisolated func urlTest(
        profile: ProxyProfile,
        url: URL = URL(string: "http://cp.cloudflare.com/generate_204")!
    ) async -> Duration? {
        guard let binaryURL = Bundle.main.url(forResource: "sing-box", withExtension: nil) else {
            return nil
        }
        guard let port = allocFreePort() else { return nil }
        let config = buildMinimalConfig(profile: profile, mixedPort: port)
        guard let cfgURL = writeTestConfig(config) else { return nil }
        defer { try? FileManager.default.removeItem(at: cfgURL) }

        let process = Process()
        process.executableURL  = binaryURL
        process.arguments      = ["run", "-c", cfgURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice

        guard (try? process.run()) != nil else { return nil }
        defer { process.terminate() }

        guard (try? await waitForPort(port, timeout: 3)) != nil else { return nil }

        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable:  1,
            kCFNetworkProxiesHTTPProxy:   "127.0.0.1",
            kCFNetworkProxiesHTTPPort:    port,
            kCFNetworkProxiesHTTPSEnable: 1,
            kCFNetworkProxiesHTTPSProxy:  "127.0.0.1",
            kCFNetworkProxiesHTTPSPort:   port
        ]
        let session = URLSession(configuration: sessionConfig)
        var req = URLRequest(url: url)
        req.timeoutInterval = 5

        let start = ContinuousClock.now
        guard (try? await session.data(for: req)) != nil else { return nil }
        return ContinuousClock.now - start
    }

    // MARK: - Batch Test

    /// Concurrently TCP-pings all profiles (up to `concurrency` at a time), streaming
    /// `(id, Result<Duration, Error>)` pairs as each test completes.
    nonisolated func batchTest(
        profiles: [ProxyProfile],
        concurrency: Int = 5
    ) -> AsyncStream<(UUID, Result<Duration, any Error>)> {
        AsyncStream { continuation in
            Task {
                await withTaskGroup(
                    of: (UUID, Result<Duration, any Error>).self
                ) { group in
                    var idx = 0
                    let initial = min(concurrency, profiles.count)

                    for i in 0..<initial {
                        let p = profiles[i]
                        idx = i + 1
                        group.addTask { await Self.testOne(p) }
                    }

                    for await result in group {
                        continuation.yield(result)
                        if idx < profiles.count {
                            let p = profiles[idx]
                            idx += 1
                            group.addTask { await Self.testOne(p) }
                        }
                    }
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Private Helpers

    private static func testOne(_ p: ProxyProfile) async -> (UUID, Result<Duration, any Error>) {
        let d = await ServerTester.shared.tcpPing(profile: p)
        if d >= .seconds(10) {
            return (p.id, .failure(LatencyError.timeout))
        }
        return (p.id, .success(d))
    }

    /// Allocates a free TCP port by binding to port 0 and reading the assigned port number.
    private nonisolated func allocFreePort() -> Int? {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { Darwin.close(fd) }

        var addr = sockaddr_in()
        addr.sin_family      = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = INADDR_ANY
        addr.sin_port        = 0

        let bound: Int32 = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sptr in
                Darwin.bind(fd, sptr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { return nil }

        var outAddr = sockaddr_in()
        var outLen  = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named: Int32 = withUnsafeMutablePointer(to: &outAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sptr in
                Darwin.getsockname(fd, sptr, &outLen)
            }
        }
        guard named == 0 else { return nil }
        return Int(outAddr.sin_port.bigEndian)
    }

    private nonisolated func buildMinimalConfig(profile: ProxyProfile, mixedPort: Int) -> [String: Any] {
        [
            "log": ["level": "error"],
            "inbounds": [[
                "type": "mixed",
                "tag":  "mixed-in",
                "listen": "127.0.0.1",
                "listen_port": mixedPort
            ]],
            "outbounds": [
                SingBoxConfigBuilder.buildProxyOutbound(profile: profile),
                ["type": "direct", "tag": "direct"]
            ]
        ]
    }

    private nonisolated func writeTestConfig(_ config: [String: Any]) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismtun-test-\(UUID().uuidString).json")
        guard let data = try? JSONSerialization.data(withJSONObject: config) else { return nil }
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return url
    }

    /// Polls a loopback TCP port until it accepts connections or the deadline passes.
    private nonisolated func waitForPort(_ port: Int, timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            if fd >= 0 {
                var addr = sockaddr_in()
                addr.sin_family      = sa_family_t(AF_INET)
                addr.sin_port        = UInt16(port).bigEndian
                inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)
                let result: Int32 = withUnsafeMutablePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sptr in
                        Darwin.connect(fd, sptr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                Darwin.close(fd)
                if result == 0 { return }
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw LatencyError.timeout
    }
}

// MARK: - ResumeOnce

/// Guarantees a CheckedContinuation is resumed exactly once when both the NWConnection
/// callback and the timeout Task race to resume it.
///
/// @unchecked Sendable: OSAllocatedUnfairLock makes all mutations atomic.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)
    private let cont: CheckedContinuation<Duration, Never>

    init(_ cont: CheckedContinuation<Duration, Never>) { self.cont = cont }

    func resume(_ value: Duration) {
        let should = lock.withLock { (state: inout Bool) -> Bool in
            guard !state else { return false }
            state = true
            return true
        }
        if should { cont.resume(returning: value) }
    }
}
