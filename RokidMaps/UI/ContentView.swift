import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var vm: NavViewModel
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    init() {
        let ss = SettingsStore()
        _settingsStore = StateObject(wrappedValue: ss)
        _vm = StateObject(wrappedValue: NavViewModel(settingsStore: ss))
    }

    var body: some View {
        ZStack {
            MapView(
                region: mapRegion,
                polyline: vm.routePolyline,
                userLocation: vm.currentLocation?.coordinate
            )
            .ignoresSafeArea()
            .onChange(of: vm.currentLocation) { loc in
                if let loc {
                    mapRegion = MKCoordinateRegion(
                        center: loc.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }

            if case .navigating = vm.navState {
                NavigationHUD(vm: vm)
                    .transition(.move(edge: .top))
            } else if case .arrived = vm.navState {
                arrivedBanner
            } else if case .error(let msg) = vm.navState {
                errorBanner(message: msg)
            }

            VStack {
                topBar
                Spacer()
                if showSearch && !isNavigating {
                    SearchView(vm: vm)
                        .background(Color(.systemGroupedBackground))
                        .transition(.move(edge: .bottom))
                }
                if !isNavigating {
                    bottomButtons
                }
            }
        }
        .animation(.easeInOut, value: showSearch)
        .animation(.easeInOut, value: isNavigating)
        .sheet(isPresented: $showSettings) {
            SettingsView(store: settingsStore)
        }
    }

    private var isNavigating: Bool {
        if case .navigating = vm.navState { return true }
        return false
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(vm.glassesConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(vm.glassesConnected ? "\(vm.glassesClientCount) glasses" : "No glasses")
                    .font(.caption)
            }
            .padding(8)
            .background(.regularMaterial)
            .clipShape(Capsule())

            Spacer()

            if settingsStore.settings.showSpeed, let loc = vm.currentLocation, loc.speed > 0 {
                Text(vm.formatDistance(loc.speed * 3.6 / (settingsStore.settings.useImperial ? 1.60934 : 1)) + (settingsStore.settings.useImperial ? " mph" : " km/h"))
                    .font(.caption.bold())
                    .padding(8)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
            }

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .padding(10)
                    .background(.regularMaterial)
                    .clipShape(Circle())
            }
        }
        .padding()
    }

    private var bottomButtons: some View {
        HStack {
            Button {
                showSearch.toggle()
            } label: {
                Label("Search", systemImage: showSearch ? "xmark" : "magnifyingglass")
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 4)
            }

            Button { vm.saveCurrentPlace() } label: {
                Image(systemName: "bookmark.fill")
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
        }
        .padding(.bottom, 30)
    }

    private var arrivedBanner: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "mappin.circle.fill").font(.title).foregroundColor(.green)
                Text("You have arrived!").font(.headline)
                Spacer()
                Button("Done") { vm.stopNavigation() }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 8)
            .padding()
        }
    }

    private func errorBanner(message: String) -> some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                Text(message).font(.subheadline)
                Spacer()
                Button("Retry") { vm.stopNavigation() }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 8)
            .padding()
        }
    }
}
