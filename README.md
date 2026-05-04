# Rokid GMaps iOS


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS navigation HUD companion app for Rokid AR glasses using OpenStreetMap / OSRM routing.

Converted from the Android original. Replaces Google Maps SDK + Bluetooth SPP with MapKit + OSRM/Nominatim + NWListener TCP.

## What it does

- **Location tracking**: CLLocationManager with background location support.
- **Destination search**: Nominatim (OpenStreetMap) geocoding — no API key required.
- **Route calculation**: OSRM open-source routing — no API key required, driving mode.
- **Turn-by-turn navigation**: Step advance at 150m threshold, off-route detection at 80m, 15s reroute cooldown.
- **Glasses HUD**: TCP server on port 8085 streams location updates, step changes, and route geometry as JSON lines.
- **MapKit overlay**: Route polyline drawn on the map view.
- **Saved places**: Bookmark locations to quickly navigate back.
- **Units**: Toggle imperial/metric in settings.

## Android → iOS mapping

| Android | iOS |
|---------|-----|
| `NominatimClient` | `NominatimClient` (URLSession async/await) |
| `OsrmClient` | `OsrmClient` (URLSession async/await) |
| `NavigationManager` | `NavigationManager` (step advance, off-route, reroute) |
| `BluetoothSppManager` | `GlassesServer` (NWListener TCP :8085) |
| `HudStreamingService` | `NavViewModel` (location → glasses pipeline) |
| Google Maps SDK | MapKit + MKPolyline |

## SDK Setup

The glasses now connect over **Bluetooth via the Rokid AI glasses SDK** — no Wi-Fi port or TCP server needed.

The only thing left for each app is filling in the three credential constants (`kAppKey`, `kAppSecret`, `kAccessKey`) from [account.rokid.com/#/setting/prove](https://account.rokid.com/#/setting/prove), then running `pod install`.

1. **Get credentials** at <https://account.rokid.com/#/setting/prove> and paste them into the glasses Swift file:
   ```swift
   private let kAppKey    = "YOUR_APP_KEY"
   private let kAppSecret = "YOUR_APP_SECRET"
   private let kAccessKey = "YOUR_ACCESS_KEY"
   ```

2. **Install CocoaPods dependencies** from the repo root:
   ```bash
   pod install
   open *.xcworkspace   # always open the .xcworkspace, not .xcodeproj
   ```

3. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Setup

1. Open `RokidMaps.xcodeproj` in Xcode 15+.
2. Set your team in Signing & Capabilities.
3. Enable **Location background mode** if you need background navigation.
4. Build and run on an iPhone (iOS 17+).
5. Allow location permission when prompted.
6. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Glasses protocol (TCP :8085)

Each message is a JSON object followed by `\n`:

```json
{"type":"state","latitude":37.33,"longitude":-122.0,"bearing":270,"speed":13.4,"accuracy":5,"distToNextStep":320}
{"type":"step","instruction":"Turn right onto Main St","maneuver":"right","distance":450}
{"type":"route","waypoints":[...],"totalDistance":12500,"totalDuration":680}
{"type":"status","text":"Rerouting..."}
```

## APIs used (all free, no key required)

- **OSRM**: `router.project-osrm.org` — open-source routing engine
- **Nominatim**: `nominatim.openstreetmap.org` — OpenStreetMap geocoding

## Requirements

- iOS 17.0+
- Xcode 15+
- No API keys needed
