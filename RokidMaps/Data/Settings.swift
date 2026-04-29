import Foundation

struct SavedPlace: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var lat: Double
    var lng: Double
}

struct MapSettings: Codable {
    var useImperial: Bool = false
    var showSpeed: Bool = true
    var showSpeedLimit: Bool = true
}

final class SettingsStore: ObservableObject {
    @Published var settings: MapSettings {
        didSet { save() }
    }
    @Published var savedPlaces: [SavedPlace] {
        didSet { savePlaces() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "map_settings"),
           let decoded = try? JSONDecoder().decode(MapSettings.self, from: data) {
            settings = decoded
        } else {
            settings = MapSettings()
        }
        if let data = UserDefaults.standard.data(forKey: "saved_places"),
           let decoded = try? JSONDecoder().decode([SavedPlace].self, from: data) {
            savedPlaces = decoded
        } else {
            savedPlaces = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "map_settings")
        }
    }

    private func savePlaces() {
        if let data = try? JSONEncoder().encode(savedPlaces) {
            UserDefaults.standard.set(data, forKey: "saved_places")
        }
    }
}
