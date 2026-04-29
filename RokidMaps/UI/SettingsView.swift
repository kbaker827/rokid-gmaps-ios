import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Toggle("Imperial units (mi/ft)", isOn: $store.settings.useImperial)
                    Toggle("Show speed", isOn: $store.settings.showSpeed)
                    Toggle("Show speed limit", isOn: $store.settings.showSpeedLimit)
                }
                Section("Saved Places") {
                    if store.savedPlaces.isEmpty {
                        Text("No saved places yet.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(store.savedPlaces) { place in
                            VStack(alignment: .leading) {
                                Text(place.name).font(.headline)
                                Text(String(format: "%.4f, %.4f", place.lat, place.lng))
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .onDelete { store.savedPlaces.remove(atOffsets: $0) }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
