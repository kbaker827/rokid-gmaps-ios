import Foundation
import CoreLocation
import MapKit

enum NavState {
    case idle, searching, routing, navigating, arrived, error(String)
}

@MainActor
final class NavViewModel: ObservableObject, NavigationManagerDelegate {
    @Published var navState: NavState = .idle
    @Published var searchResults: [SearchResult] = []
    @Published var searchQuery = ""
    @Published var isSearching = false

    @Published var currentInstruction = ""
    @Published var currentManeuver = ""
    @Published var stepDistance: Double = 0
    @Published var totalDistance: Double = 0
    @Published var totalDuration: Double = 0
    @Published var routePolyline: [CLLocationCoordinate2D] = []

    @Published var currentLocation: CLLocation?
    @Published var currentSpeed: Double = 0
    @Published var currentBearing: Float = 0
    @Published var glassesConnected = false
    @Published var glassesClientCount = 0
    @Published var statusText = "Ready"

    @Published var destination: SearchResult?

    let settingsStore: SettingsStore
    let locationService = LocationService()
    private let navManager = NavigationManager()
    private let glassesServer = GlassesServer()
    private var locationBroadcastTask: Task<Void, Never>?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        navManager.delegate = self
        setupLocation()
        setupGlassesServer()
    }

    private func setupLocation() {
        locationService.requestPermission()
        locationService.startUpdating()
        locationService.onLocationUpdate = { [weak self] loc in
            Task { @MainActor [weak self] in
                self?.handleLocationUpdate(loc)
            }
        }
    }

    private func setupGlassesServer() {
        glassesServer.onClientConnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                glassesClientCount = glassesServer.clientCount
                glassesConnected = true
            }
        }
        glassesServer.onClientDisconnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                glassesClientCount = glassesServer.clientCount
                glassesConnected = glassesClientCount > 0
            }
        }
        glassesServer.start()
    }

    private func handleLocationUpdate(_ loc: CLLocation) {
        currentLocation = loc
        currentSpeed = max(loc.speed, 0)
        if loc.course >= 0 { currentBearing = Float(loc.course) }

        navManager.onLocationUpdate(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)

        let distToNext = navManager.distanceToNextStep(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        glassesServer.sendLocation(
            lat: loc.coordinate.latitude,
            lng: loc.coordinate.longitude,
            bearing: currentBearing,
            speed: Float(currentSpeed),
            accuracy: Float(loc.horizontalAccuracy),
            distToNext: distToNext
        )
    }

    // MARK: - Search

    func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        searchResults = []
        Task {
            if let loc = currentLocation {
                searchResults = (try? await NominatimClient.searchNearby(query: searchQuery, lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)) ?? []
            } else {
                searchResults = (try? await NominatimClient.search(query: searchQuery)) ?? []
            }
            isSearching = false
        }
    }

    func selectDestination(_ result: SearchResult) {
        destination = result
        searchResults = []
        searchQuery = result.displayName
        guard let loc = currentLocation else {
            statusText = "Waiting for GPS..."
            return
        }
        navState = .routing
        statusText = "Calculating route..."
        navManager.startNavigation(
            destLat: result.lat, destLng: result.lng,
            currentLat: loc.coordinate.latitude, currentLng: loc.coordinate.longitude
        )
    }

    func stopNavigation() {
        navManager.stopNavigation()
        navState = .idle
        destination = nil
        routePolyline = []
        currentInstruction = ""
        statusText = "Ready"
        glassesServer.sendStatus("Navigation stopped")
    }

    func saveCurrentPlace() {
        guard let loc = currentLocation else { return }
        let place = SavedPlace(name: "Current location", lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        settingsStore.savedPlaces.append(place)
    }

    func navigateTo(savedPlace: SavedPlace) {
        let result = SearchResult(displayName: savedPlace.name, lat: savedPlace.lat, lng: savedPlace.lng)
        selectDestination(result)
    }

    func formatDistance(_ meters: Double) -> String {
        if settingsStore.settings.useImperial {
            let feet = meters * 3.28084
            return feet < 1000 ? String(format: "%.0f ft", feet) : String(format: "%.1f mi", feet / 5280)
        } else {
            return meters < 1000 ? String(format: "%.0f m", meters) : String(format: "%.1f km", meters / 1000)
        }
    }

    func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    // MARK: - NavigationManagerDelegate

    nonisolated func navigationManager(_ mgr: NavigationManager, didCalculateRoute result: RouteResult) {
        Task { @MainActor in
            navState = .navigating
            totalDistance = result.totalDistance
            totalDuration = result.totalDuration
            routePolyline = result.waypoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            let wps = result.waypoints.map { ["latitude": $0.latitude, "longitude": $0.longitude] }
            glassesServer.sendRoute(waypoints: wps, totalDistance: result.totalDistance, totalDuration: result.totalDuration)
            statusText = "Navigating"
        }
    }

    nonisolated func navigationManager(_ mgr: NavigationManager, didChangeStep step: NavigationStep) {
        Task { @MainActor in
            currentInstruction = step.instruction
            currentManeuver = step.maneuver
            stepDistance = step.distance
            glassesServer.sendStep(instruction: step.instruction, maneuver: step.maneuver, distance: step.distance)
        }
    }

    nonisolated func navigationManager(_ mgr: NavigationManager, didFailWithError message: String) {
        Task { @MainActor in
            navState = .error(message)
            statusText = "Route error"
            glassesServer.sendStatus("Route error: \(message)")
        }
    }

    nonisolated func navigationManagerDidArrive(_ mgr: NavigationManager) {
        Task { @MainActor in
            navState = .arrived
            statusText = "Arrived!"
            glassesServer.sendStatus("Arrived at destination")
        }
    }

    nonisolated func navigationManagerIsRerouting(_ mgr: NavigationManager) {
        Task { @MainActor in
            statusText = "Rerouting..."
            glassesServer.sendStatus("Rerouting...")
        }
    }
}
