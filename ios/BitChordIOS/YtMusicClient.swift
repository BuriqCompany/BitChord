import Foundation

struct YtMusicTrack: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: URL?
}

enum YtMusicClientError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case clientVersionNotFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "YouTube Music returned an invalid response."
        case .httpStatus(let status):
            return "YouTube Music request failed (HTTP \(status))."
        case .clientVersionNotFound:
            return "Could not read the YouTube Music client version."
        }
    }
}

final class YtMusicClient {
    private let session: URLSession
    private var clientVersion: String?
    private let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36"
    private var languageCode: String { Locale.current.languageCode ?? "en" }
    private var regionCode: String { Locale.current.regionCode ?? "US" }
    private var acceptLanguage: String {
        "\(languageCode)-\(regionCode),\(languageCode);q=0.9"
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchSongs(_ query: String) async throws -> [YtMusicTrack] {
        let version = try await currentClientVersion()
        var components = URLComponents(string: "https://music.youtube.com/youtubei/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "prettyPrint", value: "false"),
            URLQueryItem(name: "hl", value: languageCode)
        ]
        guard let url = components.url else {
            throw YtMusicClientError.invalidResponse
        }

        let body: [String: Any] = [
            "context": [
                "client": [
                    "clientName": "WEB_REMIX",
                    "clientVersion": version,
                    "hl": languageCode,
                    "gl": regionCode
                ],
                "user": ["lockedSafetyMode": false],
                "request": ["useSsl": true]
            ],
            "query": query,
            "params": "EgWKAQIIAWoKEAkQChAFEAMQBA=="
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "X-Origin")
        request.setValue("67", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue(version, forHTTPHeaderField: "X-YouTube-Client-Version")
        request.setValue(acceptLanguage, forHTTPHeaderField: "Accept-Language")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw YtMusicClientError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw YtMusicClientError.httpStatus(response.statusCode)
        }
        let json = try JSONSerialization.jsonObject(with: data)
        return Self.parseTracks(from: json)
    }

    private func currentClientVersion() async throws -> String {
        if let clientVersion = clientVersion {
            return clientVersion
        }

        let url = URL(string: "https://music.youtube.com/")!
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(acceptLanguage, forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw YtMusicClientError.invalidResponse
        }

        let pattern = #""INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)""#
        let expression = try NSRegularExpression(pattern: pattern)
        let htmlRange = NSRange(html.startIndex..., in: html)
        guard let match = expression.firstMatch(in: html, range: htmlRange),
              let versionRange = Range(match.range(at: 1), in: html) else {
            throw YtMusicClientError.clientVersionNotFound
        }
        let version = String(html[versionRange])
        guard !version.isEmpty else {
            throw YtMusicClientError.clientVersionNotFound
        }
        clientVersion = version
        return version
    }

    private static func parseTracks(from json: Any) -> [YtMusicTrack] {
        var renderers: [[String: Any]] = []
        collectRenderers(in: json, named: "musicResponsiveListItemRenderer", into: &renderers)

        var seen = Set<String>()
        return renderers.compactMap { renderer in
            guard let videoID = videoID(in: renderer), seen.insert(videoID).inserted else {
                return nil
            }

            let columns = renderer["flexColumns"] as? [[String: Any]] ?? []
            let title = text(in: columns.first)
            let subtitle = columns.dropFirst().first.map(text(in:)) ?? ""
            let artist = subtitle
                .components(separatedBy: " • ")
                .first(where: { !$0.isEmpty && !$0.contains(":") && !$0.lowercased().contains("song") })
                ?? "Unknown artist"
            guard !title.isEmpty else {
                return nil
            }

            let thumbnailURL = (((renderer["thumbnail"] as? [String: Any])?["musicThumbnailRenderer"] as? [String: Any])?["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]]
            let artwork = thumbnailURL?
                .compactMap { $0["url"] as? String }
                .last
                .flatMap(URL.init(string:))

            return YtMusicTrack(
                id: videoID,
                title: title,
                artist: artist,
                artworkURL: artwork
            )
        }
    }

    private static func collectRenderers(
        in node: Any,
        named name: String,
        into renderers: inout [[String: Any]]
    ) {
        if let dictionary = node as? [String: Any] {
            if let renderer = dictionary[name] as? [String: Any] {
                renderers.append(renderer)
            }
            for key in dictionary.keys.sorted() {
                if let value = dictionary[key] {
                    collectRenderers(in: value, named: name, into: &renderers)
                }
            }
        } else if let array = node as? [Any] {
            for value in array {
                collectRenderers(in: value, named: name, into: &renderers)
            }
        }
    }

    private static func videoID(in renderer: [String: Any]) -> String? {
        if let playlistItem = renderer["playlistItemData"] as? [String: Any],
           let videoID = playlistItem["videoId"] as? String {
            return videoID
        }
        if let overlay = renderer["overlay"] as? [String: Any],
           let thumbnailOverlay = overlay["musicItemThumbnailOverlayRenderer"] as? [String: Any],
           let content = thumbnailOverlay["content"] as? [String: Any],
           let playButton = content["musicPlayButtonRenderer"] as? [String: Any],
           let endpoint = playButton["playNavigationEndpoint"] as? [String: Any],
           let watch = endpoint["watchEndpoint"] as? [String: Any],
           let videoID = watch["videoId"] as? String {
            return videoID
        }
        return nil
    }

    private static func text(in column: [String: Any]?) -> String {
        guard let renderer = column?["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any],
              let text = renderer["text"] as? [String: Any] else {
            return ""
        }
        if let simpleText = text["simpleText"] as? String {
            return simpleText
        }
        return (text["runs"] as? [[String: Any]] ?? [])
            .compactMap { $0["text"] as? String }
            .joined()
    }
}
