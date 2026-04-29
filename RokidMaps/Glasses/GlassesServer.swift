import Foundation
import Network

final class GlassesServer {
    private let port: NWEndpoint.Port = 8085
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "glasses.maps")

    var onClientConnected: (() -> Void)?
    var onClientDisconnected: (() -> Void)?
    var clientCount: Int { connections.count }

    func start() {
        guard let l = try? NWListener(using: .tcp, on: port) else { return }
        listener = l
        l.newConnectionHandler = { [weak self] c in self?.accept(c) }
        l.start(queue: queue)
    }

    func stop() {
        listener?.cancel(); listener = nil
        connections.forEach { $0.cancel() }; connections.removeAll()
    }

    private func accept(_ conn: NWConnection) {
        connections.append(conn)
        conn.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.remove(conn) }
            else if case .cancelled = state { self?.remove(conn) }
        }
        conn.start(queue: queue)
        onClientConnected?()
    }

    private func remove(_ conn: NWConnection) {
        connections.removeAll { $0 === conn }
        onClientDisconnected?()
    }

    // MARK: - Messages

    func sendLocation(lat: Double, lng: Double, bearing: Float, speed: Float, accuracy: Float, speedLimit: Int = -1, distToNext: Double = -1) {
        send([
            "type": "state",
            "latitude": lat, "longitude": lng,
            "bearing": bearing, "speed": speed, "accuracy": accuracy,
            "speedLimitKmh": speedLimit, "distToNextStep": distToNext
        ])
    }

    func sendStep(instruction: String, maneuver: String, distance: Double) {
        send(["type": "step", "instruction": instruction, "maneuver": maneuver, "distance": distance])
    }

    func sendRoute(waypoints: [[String: Double]], totalDistance: Double, totalDuration: Double) {
        send(["type": "route", "waypoints": waypoints, "totalDistance": totalDistance, "totalDuration": totalDuration])
    }

    func sendStatus(_ text: String) {
        send(["type": "status", "text": text])
    }

    private func send(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        let raw = Data(line.utf8)
        for conn in connections {
            conn.send(content: raw, completion: .idempotent)
        }
    }
}
