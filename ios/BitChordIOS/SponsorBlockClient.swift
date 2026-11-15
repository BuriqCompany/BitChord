import CryptoKit
import Foundation

struct SponsorBlockSegment: Identifiable {
    let id: String
    let start: Double
    let end: Double
    let category: String
}

struct SponsorBlockClient {
    private let categories = ["sponsor", "selfpromo", "interaction"]
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func segments(for videoID: String) async throws -> [SponsorBlockSegment] {
        let hash = SHA256.hash(data: Data(videoID.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let prefix = String(hash.prefix(4))
        var components = URLComponents(string: "https://sponsor.ajay.app/api/skipSegments/\(prefix)")!
        components.queryItems = categories.map { URLQueryItem(name: "category", value: $0) }
            + [URLQueryItem(name: "actionType", value: "skip")]
        guard let url = components.url else {
            throw SponsorBlockError.invalidResponse
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpShouldHandleCookies = false
        request.setValue("BitChord-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw SponsorBlockError.invalidResponse
        }
        if response.statusCode == 404 {
            return []
        }
        guard (200..<300).contains(response.statusCode) else {
            throw SponsorBlockError.httpStatus(response.statusCode)
        }

        let videos = try JSONDecoder().decode([SponsorBlockVideo].self, from: data)
        guard let video = videos.first(where: { $0.videoID == videoID }) else {
            return []
        }
        return video.segments
            .compactMap { segment in
                guard segment.actionType == "skip", segment.segment.count == 2 else {
                    return nil
                }
                let start = segment.segment[0]
                let end = segment.segment[1]
                guard start.isFinite, end.isFinite, start >= 0, end > start else {
                    return nil
                }
                return SponsorBlockSegment(
                    id: segment.uuid,
                    start: start,
                    end: end,
                    category: segment.category
                )
            }
            .sorted { $0.start < $1.start }
    }
}

private struct SponsorBlockVideo: Decodable {
    let videoID: String
    let segments: [SponsorBlockRecord]
}

private struct SponsorBlockRecord: Decodable {
    let segment: [Double]
    let uuid: String
    let category: String
    let actionType: String

    enum CodingKeys: String, CodingKey {
        case segment
        case uuid = "UUID"
        case category
        case actionType
    }
}

enum SponsorBlockError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "SponsorBlock returned an invalid response."
        case .httpStatus(let status):
            return "SponsorBlock request failed (HTTP \(status))."
        }
    }
}
