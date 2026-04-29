import Foundation

struct NavigationStep {
    let instruction: String
    let maneuver: String
    let distance: Double
    let duration: Double
    let locationLat: Double
    let locationLng: Double
}

struct RouteWaypoint {
    let latitude: Double
    let longitude: Double
}

struct RouteResult {
    let waypoints: [RouteWaypoint]
    let steps: [NavigationStep]
    let totalDistance: Double
    let totalDuration: Double
}

enum OsrmClient {
    private static let userAgent = "RokidHudMaps/1.0"

    static func getRoute(fromLat: Double, fromLng: Double, toLat: Double, toLng: Double) async throws -> RouteResult {
        guard let url = URL(string: "https://router.project-osrm.org/route/v1/driving/\(fromLng),\(fromLat);\(toLng),\(toLat)?overview=full&geometries=geojson&steps=true") else {
            throw NSError(domain: "OsrmClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try parseResponse(data)
    }

    private static func parseResponse(_ data: Data) throws -> RouteResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["code"] as? String == "Ok",
              let routes = json["routes"] as? [[String: Any]],
              let route = routes.first else {
            throw NSError(domain: "OsrmClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid OSRM response"])
        }

        let totalDistance = route["distance"] as? Double ?? 0
        let totalDuration = route["duration"] as? Double ?? 0

        var waypoints: [RouteWaypoint] = []
        if let geometry = route["geometry"] as? [String: Any],
           let coords = geometry["coordinates"] as? [[Double]] {
            let stride = max(1, coords.count / 500)
            for i in Swift.stride(from: 0, to: coords.count, by: stride) {
                let c = coords[i]
                if c.count >= 2 { waypoints.append(RouteWaypoint(latitude: c[1], longitude: c[0])) }
            }
            if let last = coords.last, last.count >= 2 {
                let lw = RouteWaypoint(latitude: last[1], longitude: last[0])
                if waypoints.last.map({ abs($0.latitude - lw.latitude) + abs($0.longitude - lw.longitude) > 0.00001 }) ?? true {
                    waypoints.append(lw)
                }
            }
        }

        var steps: [NavigationStep] = []
        if let legs = route["legs"] as? [[String: Any]] {
            for leg in legs {
                if let legSteps = leg["steps"] as? [[String: Any]] {
                    for s in legSteps {
                        guard let maneuverObj = s["maneuver"] as? [String: Any],
                              let loc = maneuverObj["location"] as? [Double],
                              loc.count >= 2 else { continue }
                        let type = maneuverObj["type"] as? String ?? ""
                        let modifier = maneuverObj["modifier"] as? String ?? ""
                        let name = s["name"] as? String ?? ""
                        steps.append(NavigationStep(
                            instruction: buildInstruction(type: type, modifier: modifier, name: name),
                            maneuver: toManeuverKey(type: type, modifier: modifier),
                            distance: s["distance"] as? Double ?? 0,
                            duration: s["duration"] as? Double ?? 0,
                            locationLat: loc[1],
                            locationLng: loc[0]
                        ))
                    }
                }
            }
        }

        return RouteResult(waypoints: waypoints, steps: steps, totalDistance: totalDistance, totalDuration: totalDuration)
    }

    private static func buildInstruction(type: String, modifier: String, name: String) -> String {
        let street = name.isEmpty ? "" : " onto \(name)"
        switch type {
        case "depart": return "Head\(street.isEmpty ? " out" : street)"
        case "arrive": return "Arrive at destination"
        case "turn": return "\(modifierLabel(modifier))\(street)"
        case "new name": return "Continue\(street)"
        case "merge": return "Merge\(street)"
        case "on ramp": return "Take ramp\(street)"
        case "off ramp": return "Exit\(street)"
        case "fork": return "\(modifierLabel(modifier)) at fork\(street)"
        case "end of road": return "\(modifierLabel(modifier))\(street)"
        case "roundabout", "rotary": return "Enter roundabout, exit\(street)"
        case "roundabout turn": return "\(modifierLabel(modifier)) at roundabout\(street)"
        default: return "Continue\(street)"
        }
    }

    private static func modifierLabel(_ modifier: String) -> String {
        switch modifier {
        case "left": return "Turn left"
        case "right": return "Turn right"
        case "straight": return "Continue straight"
        case "slight left": return "Slight left"
        case "slight right": return "Slight right"
        case "sharp left": return "Sharp left"
        case "sharp right": return "Sharp right"
        case "uturn": return "Make a U-turn"
        default: return "Continue"
        }
    }

    private static func toManeuverKey(type: String, modifier: String) -> String {
        switch type {
        case "arrive": return "arrive"
        case "depart": return "depart"
        case "roundabout", "rotary": return modifier.isEmpty ? "straight" : modifier
        default: return modifier.isEmpty ? "straight" : modifier
        }
    }
}
