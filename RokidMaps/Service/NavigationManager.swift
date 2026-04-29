import Foundation

protocol NavigationManagerDelegate: AnyObject {
    func navigationManager(_ mgr: NavigationManager, didCalculateRoute result: RouteResult)
    func navigationManager(_ mgr: NavigationManager, didChangeStep step: NavigationStep)
    func navigationManager(_ mgr: NavigationManager, didFailWithError message: String)
    func navigationManagerDidArrive(_ mgr: NavigationManager)
    func navigationManagerIsRerouting(_ mgr: NavigationManager)
}

final class NavigationManager {
    private enum Constants {
        static let stepAdvanceRadius = 150.0
        static let offRouteRadius = 80.0
        static let arrivalRadius = 30.0
        static let rerouteCooldown = 15.0
    }

    weak var delegate: NavigationManagerDelegate?

    private(set) var isNavigating = false
    private(set) var steps: [NavigationStep] = []
    private(set) var routeWaypoints: [RouteWaypoint] = []
    private(set) var currentStepIndex = 0

    private var destLat = 0.0
    private var destLng = 0.0
    private var lastRerouteTime = Date.distantPast

    var currentInstruction: String { steps[safe: currentStepIndex]?.instruction ?? "" }
    var currentManeuver: String { steps[safe: currentStepIndex]?.maneuver ?? "" }
    var currentStepDistance: Double { steps[safe: currentStepIndex]?.distance ?? 0 }

    func startNavigation(destLat: Double, destLng: Double, currentLat: Double, currentLng: Double) {
        self.destLat = destLat
        self.destLng = destLng
        isNavigating = true
        calculateRoute(fromLat: currentLat, fromLng: currentLng, toLat: destLat, toLng: destLng)
    }

    func stopNavigation() {
        isNavigating = false
        steps = []
        routeWaypoints = []
        currentStepIndex = 0
    }

    func onLocationUpdate(lat: Double, lng: Double) {
        guard isNavigating, !steps.isEmpty else { return }

        let distToDest = haversineM(lat, lng, destLat, destLng)
        if distToDest < Constants.arrivalRadius && currentStepIndex >= steps.count - 2 {
            isNavigating = false
            DispatchQueue.main.async { self.delegate?.navigationManagerDidArrive(self) }
            return
        }

        if currentStepIndex < steps.count - 1 {
            let next = steps[currentStepIndex + 1]
            if haversineM(lat, lng, next.locationLat, next.locationLng) < Constants.stepAdvanceRadius {
                advanceStep()
                return
            }
        }

        let nearestDist = nearestRouteDistance(lat: lat, lng: lng)
        if nearestDist > Constants.offRouteRadius {
            let now = Date()
            if now.timeIntervalSince(lastRerouteTime) > Constants.rerouteCooldown {
                lastRerouteTime = now
                DispatchQueue.main.async { self.delegate?.navigationManagerIsRerouting(self) }
                calculateRoute(fromLat: lat, fromLng: lng, toLat: destLat, toLng: destLng)
            }
        }
    }

    func distanceToNextStep(lat: Double, lng: Double) -> Double {
        guard isNavigating, !steps.isEmpty else { return -1 }
        let idx = min(currentStepIndex + 1, steps.count - 1)
        return haversineM(lat, lng, steps[idx].locationLat, steps[idx].locationLng)
    }

    private func advanceStep() {
        currentStepIndex += 1
        let step = steps[currentStepIndex]
        DispatchQueue.main.async { self.delegate?.navigationManager(self, didChangeStep: step) }
    }

    private func calculateRoute(fromLat: Double, fromLng: Double, toLat: Double, toLng: Double) {
        Task {
            do {
                let result = try await OsrmClient.getRoute(fromLat: fromLat, fromLng: fromLng, toLat: toLat, toLng: toLng)
                await MainActor.run { self.applyRoute(result) }
            } catch {
                await MainActor.run { self.delegate?.navigationManager(self, didFailWithError: error.localizedDescription) }
            }
        }
    }

    private func applyRoute(_ result: RouteResult) {
        routeWaypoints = result.waypoints
        steps = result.steps
        currentStepIndex = 0
        delegate?.navigationManager(self, didCalculateRoute: result)
        if let first = steps.first {
            delegate?.navigationManager(self, didChangeStep: first)
        }
    }

    private func nearestRouteDistance(lat: Double, lng: Double) -> Double {
        routeWaypoints.map { haversineM(lat, lng, $0.latitude, $0.longitude) }.min() ?? .greatestFiniteMagnitude
    }

    private func haversineM(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        NominatimClient.haversineM(lat1, lng1, lat2, lng2)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
