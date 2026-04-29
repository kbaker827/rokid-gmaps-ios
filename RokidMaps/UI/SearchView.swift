import SwiftUI

struct SearchView: View {
    @ObservedObject var vm: NavViewModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search destination...", text: $vm.searchQuery)
                    .focused($focused)
                    .onSubmit { vm.performSearch() }
                    .submitLabel(.search)
                if !vm.searchQuery.isEmpty {
                    Button { vm.searchQuery = ""; vm.searchResults = [] } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 4)
            .padding()

            if vm.isSearching {
                ProgressView().padding()
            } else if !vm.searchResults.isEmpty {
                List(vm.searchResults) { result in
                    Button {
                        focused = false
                        vm.selectDestination(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.displayName.components(separatedBy: ",").first ?? result.displayName)
                                .font(.headline)
                                .lineLimit(1)
                            Text(result.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .listStyle(.plain)
            } else if !vm.settingsStore.savedPlaces.isEmpty && vm.searchQuery.isEmpty {
                savedPlacesSection
            }

            Spacer()
        }
    }

    private var savedPlacesSection: some View {
        VStack(alignment: .leading) {
            Text("Saved Places")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal)
            ForEach(vm.settingsStore.savedPlaces) { place in
                Button {
                    vm.navigateTo(savedPlace: place)
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                        Text(place.name)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}
