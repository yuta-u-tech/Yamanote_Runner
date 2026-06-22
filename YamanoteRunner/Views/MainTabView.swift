import MapKit
import SwiftUI

struct MainTabView: View {
    @ObservedObject var appStateStore: AppStateStore

    var body: some View {
        TabView {
            HomeView(appStateStore: appStateStore)
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }

            NavigationStack {
                HistoryView(records: appStateStore.historyRecords)
            }
            .tabItem {
                Label("履歴", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                BadgeView(badges: RunnerBadge.all(unlockedBadgeIDs: appStateStore.unlockedBadgeIDs))
            }
            .tabItem {
                Label("バッジ", systemImage: "medal.fill")
            }

            NavigationStack {
                YamanoteMapView(appStateStore: appStateStore)
            }
            .tabItem {
                Label("マップ", systemImage: "map.fill")
            }
        }
        .tint(.green)
    }
}

private struct YamanoteMapView: View {
    @ObservedObject var appStateStore: AppStateStore
    @State private var cameraPosition: MapCameraPosition = .region(Self.defaultRegion)

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.105, longitudeDelta: 0.125)
    )

    private var progress: YamanoteRouteProgress {
        appStateStore.routeProgress
    }

    private var routeStations: [YamanoteStation] {
        YamanoteRoute.allStations(
            startingAt: appStateStore.startingStation,
            direction: appStateStore.selectedDirection
        )
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        let coordinates = routeStations.compactMap { Self.stationCoordinates[$0.name] }
        guard let firstCoordinate = coordinates.first else { return coordinates }
        return coordinates + [firstCoordinate]
    }

    private var currentCoordinate: CLLocationCoordinate2D? {
        guard let from = Self.stationCoordinates[progress.currentSegment.from.name],
            let to = Self.stationCoordinates[progress.currentSegment.to.name]
        else {
            return nil
        }

        let fraction = min(max(progress.progressInCurrentSegment, 0), 1)
        return CLLocationCoordinate2D(
            latitude: from.latitude + (to.latitude - from.latitude) * fraction,
            longitude: from.longitude + (to.longitude - from.longitude) * fraction
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(.green, lineWidth: 4)

                ForEach(routeStations) { station in
                    if let coordinate = Self.stationCoordinates[station.name] {
                        Marker(station.name, systemImage: stationSymbol(for: station), coordinate: coordinate)
                            .tint(stationTint(for: station))
                    }
                }

                if let currentCoordinate {
                    Annotation("現在地", coordinate: currentCoordinate) {
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.green)
                            .background(.background, in: Circle())
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .top)

            mapSummary
                .padding(.horizontal, 14)
                .padding(.top, 12)
        }
        .navigationTitle("マップ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mapSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: "map.fill")
                .font(.headline)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(progress.currentSegment.from.name)〜\(progress.currentSegment.to.name)")
                    .font(.subheadline.weight(.semibold))
                Text("\(appStateStore.startingStation.name) · \(appStateStore.selectedDirection.rawValue) · \(progress.currentLapNumber)周目")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func stationSymbol(for station: YamanoteStation) -> String {
        if station.id == progress.startingStation.id {
            return "flag.fill"
        }

        if station.id == progress.currentSegment.to.id {
            return "tram.fill"
        }

        return "circle.fill"
    }

    private func stationTint(for station: YamanoteStation) -> Color {
        if station.id == progress.currentSegment.to.id {
            return .green
        }

        if progress.passedStations.contains(where: { $0.id == station.id }) {
            return .gray
        }

        return .secondary
    }

    private static let stationCoordinates: [String: CLLocationCoordinate2D] = [
        "東京": CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125),
        "神田": CLLocationCoordinate2D(latitude: 35.691690, longitude: 139.770883),
        "秋葉原": CLLocationCoordinate2D(latitude: 35.698683, longitude: 139.774219),
        "御徒町": CLLocationCoordinate2D(latitude: 35.707438, longitude: 139.774632),
        "上野": CLLocationCoordinate2D(latitude: 35.713768, longitude: 139.777254),
        "鶯谷": CLLocationCoordinate2D(latitude: 35.721484, longitude: 139.778015),
        "日暮里": CLLocationCoordinate2D(latitude: 35.727772, longitude: 139.770987),
        "西日暮里": CLLocationCoordinate2D(latitude: 35.732135, longitude: 139.766787),
        "田端": CLLocationCoordinate2D(latitude: 35.738062, longitude: 139.760860),
        "駒込": CLLocationCoordinate2D(latitude: 35.736489, longitude: 139.746875),
        "巣鴨": CLLocationCoordinate2D(latitude: 35.733492, longitude: 139.739345),
        "大塚": CLLocationCoordinate2D(latitude: 35.731401, longitude: 139.728662),
        "池袋": CLLocationCoordinate2D(latitude: 35.728926, longitude: 139.710380),
        "目白": CLLocationCoordinate2D(latitude: 35.721204, longitude: 139.706587),
        "高田馬場": CLLocationCoordinate2D(latitude: 35.712285, longitude: 139.703782),
        "新大久保": CLLocationCoordinate2D(latitude: 35.701306, longitude: 139.700044),
        "新宿": CLLocationCoordinate2D(latitude: 35.690921, longitude: 139.700258),
        "代々木": CLLocationCoordinate2D(latitude: 35.683061, longitude: 139.702042),
        "原宿": CLLocationCoordinate2D(latitude: 35.670168, longitude: 139.702687),
        "渋谷": CLLocationCoordinate2D(latitude: 35.658034, longitude: 139.701636),
        "恵比寿": CLLocationCoordinate2D(latitude: 35.646690, longitude: 139.710106),
        "目黒": CLLocationCoordinate2D(latitude: 35.633998, longitude: 139.715828),
        "五反田": CLLocationCoordinate2D(latitude: 35.626446, longitude: 139.723444),
        "大崎": CLLocationCoordinate2D(latitude: 35.619700, longitude: 139.728553),
        "品川": CLLocationCoordinate2D(latitude: 35.628471, longitude: 139.738760),
        "高輪ゲートウェイ": CLLocationCoordinate2D(latitude: 35.635500, longitude: 139.740700),
        "田町": CLLocationCoordinate2D(latitude: 35.645736, longitude: 139.747575),
        "浜松町": CLLocationCoordinate2D(latitude: 35.655646, longitude: 139.756749),
        "新橋": CLLocationCoordinate2D(latitude: 35.666195, longitude: 139.758587),
        "有楽町": CLLocationCoordinate2D(latitude: 35.675069, longitude: 139.763328)
    ]
}

#Preview {
    MainTabView(appStateStore: AppStateStore(userDefaults: .standard))
}
