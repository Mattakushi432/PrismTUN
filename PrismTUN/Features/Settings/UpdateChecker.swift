import Foundation

struct UpdateResult: Sendable {
    let title: String
    let message: String
    let releaseURL: URL?
}

actor UpdateChecker {
    static let shared = UpdateChecker()
    private init() {}

    private struct GitHubRelease: Decodable {
        let tag_name: String
        let html_url: String
    }

    func checkLatestRelease() async throws -> UpdateResult {
        // Force-unwrap is safe: this is a hardcoded compile-time constant URL
        let apiURL = URL(string: "https://api.github.com/repos/prismtun/prismtun/releases/latest")!
        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            return UpdateResult(
                title: String(localized: "Up to Date"),
                message: String(localized: "No releases are published yet. You are running the latest build."),
                releaseURL: nil
            )
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let tag = release.tag_name
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let releaseURL = URL(string: release.html_url)

        if current >= latest {
            return UpdateResult(
                title: String(localized: "Up to Date"),
                message: String(localized: "You are running the latest version (\(current))."),
                releaseURL: nil
            )
        }
        return UpdateResult(
            title: String(localized: "Update Available"),
            message: String(localized: "Version \(latest) is available. You have \(current)."),
            releaseURL: releaseURL
        )
    }
}
