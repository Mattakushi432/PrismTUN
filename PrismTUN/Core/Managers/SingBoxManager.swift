import Foundation

enum SingBoxError: LocalizedError {
    case binaryNotFound
    case configWriteFailed(Error)
    case processLaunchFailed(Error)
    case apiUnavailable(stderr: String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:               "sing-box binary not found in app bundle"
        case .configWriteFailed(let e):     "Failed to write config: \(e)"
        case .processLaunchFailed(let e):   "Failed to launch sing-box: \(e)"
        case .apiUnavailable(let stderr):
            stderr.isEmpty
                ? "sing-box API unavailable after timeout"
                : "sing-box API unavailable: \(stderr.suffix(400))"
        }
    }
}

actor SingBoxManager {
    private var process: Process?
    private var configURL: URL?
    private var apiSecret: String = ""
    private var quarantineCleared = false

    private let apiBase = URL(string: "http://127.0.0.1:\(SingBoxConfigBuilder.apiPort)")!

    var isRunning: Bool { process?.isRunning == true }

    // MARK: - Lifecycle

    func start(
        profile: ProxyProfile,
        mode: ConnectionMode,
        rules: [RoutingRule],
        dnsConfig: DNSConfig = .default,
        apiSecret: String
    ) async throws {
        if isRunning { try await stop() }

        self.apiSecret = apiSecret

        let binaryURL = try binaryPath()
        await clearQuarantineOnce(url: binaryURL)
        let config    = SingBoxConfigBuilder.build(profile: profile, mode: mode, rules: rules, dnsConfig: dnsConfig, apiSecret: apiSecret)
        let cfgURL    = try writeConfig(config)
        configURL = cfgURL

        let task = Process()
        task.executableURL = binaryURL
        task.arguments     = ["run", "-c", cfgURL.path]
        task.standardOutput = FileHandle.nullDevice

        // Capture stderr for diagnostics — exposed in SingBoxError if API wait times out
        let stderrPipe = Pipe()
        task.standardError = stderrPipe

        do {
            try task.run()
            process = task
        } catch {
            try? FileManager.default.removeItem(at: cfgURL)
            configURL = nil
            throw SingBoxError.processLaunchFailed(error)
        }

        do {
            try await waitForAPI()
        } catch {
            let stderrData   = stderrPipe.fileHandleForReading.availableData
            let stderrOutput = String(data: stderrData, encoding: .utf8) ?? ""
            try? await stop()
            throw SingBoxError.apiUnavailable(stderr: stderrOutput)
        }
    }

    func stop() async throws {
        guard let p = process else { return }
        // Non-blocking wait — avoids occupying a cooperative thread
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            p.terminationHandler = { _ in cont.resume() }
            p.terminate()
        }
        process = nil
        if let url = configURL {
            try? FileManager.default.removeItem(at: url)
            configURL = nil
        }
    }

    // MARK: - Connections API

    // nonisolated: mirrors logsStream pattern — apiSecret supplied by caller, no actor state accessed.
    nonisolated func connectionsStream(apiSecret: String) -> AsyncStream<[ActiveConnection]> {
        AsyncStream { continuation in
            var components = URLComponents()
            components.scheme = "ws"
            components.host = "127.0.0.1"
            components.port = SingBoxConfigBuilder.apiPort
            components.path = "/connections"
            if !apiSecret.isEmpty {
                components.queryItems = [URLQueryItem(name: "token", value: apiSecret)]
            }
            guard let url = components.url else {
                continuation.finish()
                return
            }
            var request = URLRequest(url: url)
            if !apiSecret.isEmpty {
                request.setValue("Bearer \(apiSecret)", forHTTPHeaderField: "Authorization")
            }
            let wsTask = URLSession.shared.webSocketTask(with: request)
            wsTask.resume()

            let task = Task {
                let decoder = JSONDecoder()
                do {
                    while !Task.isCancelled {
                        let message = try await wsTask.receive()
                        guard case .string(let text) = message,
                              let data = text.data(using: .utf8),
                              let payload = try? decoder.decode(ConnectionsPayload.self, from: data),
                              let connections = payload.connections
                        else { continue }
                        continuation.yield(connections)
                    }
                } catch {}
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                wsTask.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    func closeConnection(id: String) async {
        guard let url = URL(string: "/connections/\(id)", relativeTo: apiBase) else { return }
        var req = authorizedRequest(url: url)
        req.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: req)
    }

    func closeAllConnections() async {
        guard let url = URL(string: "/connections", relativeTo: apiBase) else { return }
        var req = authorizedRequest(url: url)
        req.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - Log Streaming

    // nonisolated: no actor-isolated state accessed; apiSecret passed by caller at connect time.
    nonisolated func logsStream(apiSecret: String) -> AsyncStream<LogEntry> {
        AsyncStream { continuation in
            var components = URLComponents()
            components.scheme = "ws"
            components.host = "127.0.0.1"
            components.port = SingBoxConfigBuilder.apiPort
            components.path = "/logs"
            components.queryItems = [URLQueryItem(name: "level", value: "debug")]
            if !apiSecret.isEmpty {
                components.queryItems?.append(URLQueryItem(name: "token", value: apiSecret))
            }
            guard let url = components.url else {
                continuation.finish()
                return
            }
            var request = URLRequest(url: url)
            if !apiSecret.isEmpty {
                request.setValue("Bearer \(apiSecret)", forHTTPHeaderField: "Authorization")
            }
            let wsTask = URLSession.shared.webSocketTask(with: request)
            wsTask.resume()

            let task = Task {
                let decoder = JSONDecoder()
                do {
                    while !Task.isCancelled {
                        let message = try await wsTask.receive()
                        guard case .string(let text) = message,
                              let data = text.data(using: .utf8),
                              let payload = try? decoder.decode(LogPayload.self, from: data)
                        else { continue }
                        let entry = LogEntry(timestamp: Date(), level: payload.level, message: payload.payload)
                        continuation.yield(entry)
                    }
                } catch {
                    // WebSocket closed or cancelled — exit cleanly
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
                wsTask.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    // MARK: - API Calls

    func fetchTraffic() async -> TrafficPayload? {
        guard let url = URL(string: "/traffic", relativeTo: apiBase) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(for: authorizedRequest(url: url)) else { return nil }
        return try? JSONDecoder().decode(TrafficPayload.self, from: data)
    }

    func fetchVersion() async -> String? {
        guard let url = URL(string: "/version", relativeTo: apiBase) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(for: authorizedRequest(url: url)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["version"] as? String
    }

    // MARK: - Helpers

    private func authorizedRequest(url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if !apiSecret.isEmpty { req.setValue("Bearer \(apiSecret)", forHTTPHeaderField: "Authorization") }
        return req
    }

    // Removes com.apple.quarantine so Gatekeeper does not block the embedded binary.
    // Non-blocking: uses withCheckedContinuation + terminationHandler, matching SystemProxyManager.
    // Errors are silently ignored — the attribute is absent on notarized builds and after first removal.
    private func clearQuarantineOnce(url: URL) async {
        guard !quarantineCleared else { return }
        quarantineCleared = true
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-d", "com.apple.quarantine", url.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            return
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            task.terminationHandler = { _ in cont.resume() }
        }
    }

    private func binaryPath() throws -> URL {
        guard let url = Bundle.main.url(forResource: "sing-box", withExtension: nil) else {
            throw SingBoxError.binaryNotFound
        }
        // posixPermissions = 0o755 confirmed; if codesigning prevents the write the OS will
        // surface the error at process launch, not here.
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func writeConfig(_ config: [String: Any]) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismtun-\(UUID().uuidString).json")
        do {
            let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try data.write(to: tmp, options: .atomic)
            // Restrict to owner-read/write only — proxy credentials are embedded in this file
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
            return tmp
        } catch {
            throw SingBoxError.configWriteFailed(error)
        }
    }

    private func waitForAPI(timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        let url      = apiBase.appendingPathComponent("version")
        var lastError: Error?
        while Date() < deadline {
            do {
                _ = try await URLSession.shared.data(for: authorizedRequest(url: url))
                return
            } catch {
                lastError = error
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw lastError ?? SingBoxError.apiUnavailable(stderr: "")
    }
}
