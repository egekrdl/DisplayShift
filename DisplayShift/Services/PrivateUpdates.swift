import Combine
import Foundation
import Security
import Sparkle

@MainActor
final class PrivateUpdates: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = PrivateUpdates()
    private static let repository = "https://api.github.com/repos/egekrdl/DisplayShift"
    private static let keychainQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.displayshift.app.private-updates",
        kSecAttrAccount as String: "github-release-reader"
    ]

    @Published private(set) var checking = false
    @Published private(set) var hasToken = false
    @Published var message: String?

    private var feed: URL?
    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        hasToken = (try? readToken()) != nil
    }

    func saveToken(_ text: String) {
        let token = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.hasPrefix("github_pat_"),
              token.utf8.allSatisfy({ byte in
                  (48...57).contains(byte) || (65...90).contains(byte) ||
                      (97...122).contains(byte) || byte == 95
              }) else {
            message = "Enter a GitHub fine-grained personal access token."
            return
        }
        let data = Data(token.utf8)
        let query = Self.keychainQuery
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            status = SecItemAdd(item as CFDictionary, nil)
        }
        if status == errSecSuccess {
            hasToken = true
            message = "Update access saved in Keychain."
        } else {
            message = "Keychain could not save update access (\(status))."
        }
    }

    func removeToken() {
        guard !checking else { return }
        let status = SecItemDelete(Self.keychainQuery as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            hasToken = false
            message = "Update access removed."
        } else {
            message = "Keychain could not remove update access (\(status))."
        }
    }

    func check() {
        guard !checking else { return }
        checking = true
        message = nil
        Task {
            do {
                let token = try readToken()
                feed = try await locateFeed(token: token)
                if controller == nil {
                    let controller = SPUStandardUpdaterController(startingUpdater: false,
                                                                 updaterDelegate: self,
                                                                 userDriverDelegate: nil)
                    self.controller = controller
                    controller.startUpdater()
                }
                guard let controller, controller.updater.canCheckForUpdates else {
                    throw UpdateError.unavailable
                }
                controller.updater.httpHeaders = [
                    "Authorization": "Bearer \(token)", "Accept": "application/octet-stream"
                ]
                controller.checkForUpdates(nil)
            } catch {
                checking = false
                message = error.localizedDescription
            }
        }
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        feed?.absoluteString
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        updater.httpHeaders = nil
        checking = false
    }

    private func readToken() throws -> String {
        var query = Self.keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &value)
        if status == errSecItemNotFound { throw UpdateError.noToken }
        guard status == errSecSuccess, let data = value as? Data,
              let token = String(data: data, encoding: .utf8), !token.isEmpty else {
            throw UpdateError.keychain(status)
        }
        return token
    }

    private func locateFeed(token: String) async throws -> URL {
        struct Release: Decodable {
            struct Asset: Decodable { let id: Int64; let name: String }
            let assets: [Asset]
        }
        guard let endpoint = URL(string: Self.repository + "/releases/latest") else { throw UpdateError.unavailable }
        var request = URLRequest(url: endpoint)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw UpdateError.unavailable }
        switch response.statusCode {
        case 200: break
        case 401, 403, 404: throw UpdateError.access
        default: throw UpdateError.server(response.statusCode)
        }
        let release = try JSONDecoder().decode(Release.self, from: data)
        guard let asset = release.assets.first(where: { $0.name == "appcast.xml" }), asset.id > 0,
              let url = URL(string: Self.repository + "/releases/assets/\(asset.id)") else {
            throw UpdateError.noFeed
        }
        return url
    }

    private enum UpdateError: LocalizedError {
        case noToken, keychain(OSStatus), access, noFeed, unavailable, server(Int)
        var errorDescription: String? {
            switch self {
            case .noToken: return "Set up private update access in Settings → Updates."
            case .keychain(let status): return "Keychain could not read update access (\(status))."
            case .access: return "GitHub denied access or has no published release. Check the token and its repository permissions."
            case .noFeed: return "The latest GitHub release does not contain an update feed."
            case .unavailable: return "The update checker is currently unavailable."
            case .server(let status): return "GitHub returned HTTP \(status). Try again later."
            }
        }
    }
}
