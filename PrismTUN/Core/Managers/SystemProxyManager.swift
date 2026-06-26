import Foundation

enum SystemProxyError: LocalizedError {
    case commandFailed(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let status, let output):
            "networksetup failed (exit \(status)): \(output.isEmpty ? "(no output)" : output)"
        }
    }
}

actor SystemProxyManager {
    private var networkService: String = "Wi-Fi"

    func enable(host: String = "127.0.0.1", port: Int = SingBoxConfigBuilder.mixedPort) async throws {
        networkService = try await detectActiveService()
        try await setProxy(host: host, port: port, enabled: true)
    }

    func disable() async throws {
        try await setProxy(host: "127.0.0.1", port: SingBoxConfigBuilder.mixedPort, enabled: false)
    }

    // MARK: - Private

    private func detectActiveService() async throws -> String {
        let result = try await runNetworkSetup(args: ["-listallnetworkservices"])
        let services = result.components(separatedBy: "\n")
            .filter { !$0.isEmpty && !$0.hasPrefix("*") && $0 != "An asterisk (*) denotes that a network service is disabled." }
        return services.first { $0.contains("Wi-Fi") } ?? services.first ?? "Wi-Fi"
    }

    private func setProxy(host: String, port: Int, enabled: Bool) async throws {
        let portStr = String(port)
        if enabled {
            try await runNetworkSetup(args: ["-setwebproxy",            networkService, host, portStr])
            try await runNetworkSetup(args: ["-setsecurewebproxy",      networkService, host, portStr])
            try await runNetworkSetup(args: ["-setsocksfirewallproxy",  networkService, host, portStr])
            try await runNetworkSetup(args: ["-setwebproxystate",           networkService, "on"])
            try await runNetworkSetup(args: ["-setsecurewebproxystate",     networkService, "on"])
            try await runNetworkSetup(args: ["-setsocksfirewallproxystate", networkService, "on"])
        } else {
            try await runNetworkSetup(args: ["-setwebproxystate",           networkService, "off"])
            try await runNetworkSetup(args: ["-setsecurewebproxystate",     networkService, "off"])
            try await runNetworkSetup(args: ["-setsocksfirewallproxystate", networkService, "off"])
        }
    }

    @discardableResult
    private func runNetworkSetup(args: [String]) async throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = pipe

        try task.run()

        // Non-blocking wait — avoids occupying a cooperative thread
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            task.terminationHandler = { _ in cont.resume() }
        }

        let data   = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard task.terminationStatus == 0 else {
            throw SystemProxyError.commandFailed(status: task.terminationStatus, output: output)
        }
        return output
    }
}
