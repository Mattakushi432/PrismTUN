import Foundation

enum SingBoxError: LocalizedError {
    case binaryNotFound
    case configWriteFailed(Error)
    case processLaunchFailed(Error)
    case apiUnavailable

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:        "sing-box binary not found in app bundle"
        case .configWriteFailed(let e): "Failed to write config: \(e)"
        case .processLaunchFailed(let e): "Failed to launch sing-box: \(e)"
        case .apiUnavailable:        "sing-box API unavailable"
        }
    }
}

actor SingBoxManager {
    private var process: Process?
    private var configURL: URL?

    private let apiBase = URL(string: "http://127.0.0.1:\(SingBoxConfigBuilder.apiPort)")!

    var isRunning: Bool { process?.isRunning == true }

    // MARK: - Lifecycle

    func start(profile: ProxyProfile, mode: ConnectionMode, rules: [RoutingRule]) async throws {
        if isRunning { try await stop() }

        let binaryURL = try binaryPath()
        let config = SingBoxConfigBuilder.build(profile: profile, mode: mode, rules: rules)
        let cfgURL = try writeConfig(config)
        configURL = cfgURL

        let task = Process()
        task.executableURL = binaryURL
        task.arguments = ["run", "-c", cfgURL.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError  = FileHandle.nullDevice

        do {
            try task.run()
            process = task
        } catch {
            throw SingBoxError.processLaunchFailed(error)
        }

        // wait briefly for API to become available
        try await waitForAPI()
    }

    func stop() async throws {
        process?.terminate()
        process?.waitUntilExit()
        process = nil
    }

    // MARK: - API Calls

    func fetchTraffic() async -> TrafficPayload? {
        guard let url = URL(string: "/traffic", relativeTo: apiBase) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return try? JSONDecoder().decode(TrafficPayload.self, from: data)
    }

    func fetchVersion() async -> String? {
        guard let url = URL(string: "/version", relativeTo: apiBase) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json["version"] as? String
    }

    // MARK: - Helpers

    private func binaryPath() throws -> URL {
        guard let url = Bundle.main.url(forResource: "sing-box", withExtension: nil) else {
            throw SingBoxError.binaryNotFound
        }
        // ensure executable bit
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    private func writeConfig(_ config: [String: Any]) throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("prismtun-\(UUID().uuidString).json")
        do {
            let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
            try data.write(to: tmp)
            return tmp
        } catch {
            throw SingBoxError.configWriteFailed(error)
        }
    }

    private func waitForAPI(timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        let url = apiBase.appendingPathComponent("version")
        while Date() < deadline {
            if let _ = try? await URLSession.shared.data(from: url) { return }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw SingBoxError.apiUnavailable
    }
}
