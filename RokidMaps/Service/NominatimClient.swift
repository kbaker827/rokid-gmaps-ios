import Foundation
import CoreLocation

struct SearchResult: Identifiable {
    let id = UUID()
    let displayName: String
    let lat: Double
    let lng: Double
}

enum NominatimClient {
    private static let baseURL = "https://nominatim.openstreetmap.org/search"
    private static let userAgent = "RokidHudMaps/1.0"

    static func search(query: String, limit: Int = 6) async throws -> [SearchResult] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?q=\(encoded)&format=json&limit=\(limit)&addressdetails=0") else {
            return []
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try parseResults(data)
    }

    static func searchNearby(query: String, lat: Double, lng: Double, radiusMeters: Double = 2500, limit: Int = 6) async throws -> [SearchResult] {
        let latDelta = radiusMeters / 111_320.0
        let lngDelta = radiusMeters / (111_320.0 * max(cos(lat * .pi / 180), 0.2))
        let bbox = "\(lng - lngDelta),\(lat + latDelta),\(lng + lngDelta),\(lat - latDelta)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?q=\(encoded)&format=json&limit=\(limit)&addressdetails=0&viewbox=\(bbox)&bounded=1") else {
            return []
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        var results = try parseResults(data)
        results.sort { haversineM(lat, lng, $0.lat, $0.lng) < haversineM(lat, lng, $1.lat, $1.lng) }
        return results
    }

    private static func parseResults(_ data: Data) throws -> [SearchResult] {
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return arr.compactMap { obj -> SearchResult? in
            guard let name = obj["display_name"] as? String,
                  let latStr = obj["lat"] as? String, let lat = Double(latStr),
                  let lngStr = obj["lon"] as? String, let lng = Double(lngStr) else { return nil }
            return SearchResult(displayName: name, lat: lat, lng: lng)
        }
    }

    static func haversineM(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let r = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return r * 2 * asin(sqrt(a))
    }
}
