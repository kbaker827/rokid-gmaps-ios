import SwiftUI

struct NavigationHUD: View {
    @ObservedObject var vm: NavViewModel

    var body: some View {
        VStack(spacing: 0) {
            instructionBar
            Spacer()
            bottomBar
        }
    }

    private var instructionBar: some View {
        HStack(spacing: 16) {
            Image(systemName: maneuverIcon(vm.currentManeuver))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 52)

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.currentInstruction)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text("In \(vm.formatDistance(vm.stepDistance))")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
        }
        .padding()
        .background(Color.blue)
        .cornerRadius(0)
    }

    private var bottomBar: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(vm.formatDistance(vm.totalDistance))
                    .font(.headline)
                Text("remaining")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack {
                Text(vm.formatDuration(vm.totalDuration))
                    .font(.headline)
                Text("ETA")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: vm.stopNavigation) {
                Label("Stop", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.95))
        .shadow(radius: 4)
    }

    private func maneuverIcon(_ maneuver: String) -> String {
        switch maneuver {
        case "left": return "arrow.turn.up.left"
        case "right": return "arrow.turn.up.right"
        case "slight left": return "arrow.up.left"
        case "slight right": return "arrow.up.right"
        case "sharp left": return "arrow.turn.down.left"
        case "sharp right": return "arrow.turn.down.right"
        case "uturn": return "arrow.uturn.left"
        case "arrive": return "mappin.circle.fill"
        case "depart": return "location.fill"
        case "straight": return "arrow.up"
        default: return "arrow.up"
        }
    }
}
