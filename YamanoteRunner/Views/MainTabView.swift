import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct MainTabView: View {
    @ObservedObject var appStateStore: AppStateStore
    @EnvironmentObject private var subscriptionService: SubscriptionService

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
                MapTabView(appStateStore: appStateStore)
            }
            .tabItem {
                Label("マップ", systemImage: "map.fill")
            }
        }
        .tint(.green)
        .task {
            await subscriptionService.checkCurrentEntitlement()
        }
    }
}

private struct MapTabView: View {
    @ObservedObject var appStateStore: AppStateStore
    @EnvironmentObject private var subscriptionService: SubscriptionService

    var body: some View {
        switch subscriptionService.status {
        case .subscribed:
            YamanoteMapView(appStateStore: appStateStore)
        case .notSubscribed:
            SubscriptionPaywallView()
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let message):
            ContentUnavailableView(message, systemImage: "exclamationmark.triangle")
        }
    }
}

private struct YamanoteMapView: View {
    @ObservedObject var appStateStore: AppStateStore
    @StateObject private var locationService = WalkingMapLocationService()
    @State private var cameraPosition: MapCameraPosition = .region(Self.defaultRegion)
    @State private var goalCandidates: [WalkingGoalCandidate] = []
    @State private var searchState: GoalSearchState = .idle
    @State private var selectedDirectionIndex: Int = 0
    @Environment(\.openURL) private var openURL

    private static let cardinalDirections: [(label: String, bearing: Double)] = [
        ("北", 0), ("東", 90), ("南", 180), ("西", 270)
    ]

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
    )

    private var progress: YamanoteRouteProgress { appStateStore.routeProgress }
    private var targetDistanceKilometers: Double { progress.distanceToNextStationKilometers }
    private var targetDistanceMeters: Double { max(300, targetDistanceKilometers * 1000) }

    private var selectedBearing: Double {
        Self.cardinalDirections[selectedDirectionIndex].bearing
    }

    private var selectedTarget: WalkingTarget? {
        guard let location = locationService.location else { return nil }
        let targets = WalkingTargetCalculator.cardinalCandidates(
            from: location.coordinate,
            distanceMeters: targetDistanceMeters
        )
        return targets[selectedDirectionIndex]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                if let target = selectedTarget, let location = locationService.location {
                    Annotation(target.label, coordinate: target.coordinate) {
                        Image(systemName: "flag.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(.green))
                    }
                    MapPolyline(coordinates: [location.coordinate, target.coordinate])
                        .stroke(.green, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                }

                ForEach(goalCandidates) { candidate in
                    Marker(candidate.name, systemImage: candidate.symbolName, coordinate: candidate.coordinate)
                        .tint(candidate.tint)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                summaryAndDirectionPanel
                goalCandidatePanel
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .navigationTitle("マップ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationService.requestLocation()
        }
        .onChange(of: locationService.location) { _, location in
            guard let location else { return }
            if let target = selectedTarget {
                fitCamera(user: location.coordinate, target: target.coordinate)
            } else {
                centerMap(on: location.coordinate)
            }
            searchGoals(from: location)
        }
        .onChange(of: selectedDirectionIndex) { _, _ in
            guard let location = locationService.location,
                  let target = selectedTarget else { return }
            fitCamera(user: location.coordinate, target: target.coordinate)
        }
        .onChange(of: targetDistanceKilometers) { _, _ in
            guard let location = locationService.location else { return }
            searchGoals(from: location)
            if let target = selectedTarget {
                fitCamera(user: location.coordinate, target: target.coordinate)
            }
        }
    }

    private var summaryAndDirectionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "map.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(progress.currentSegment.to.name)まであと\(formattedKilometers(targetDistanceKilometers))")
                        .font(.subheadline.weight(.semibold))
                    Text("今日の散歩目標: \(formattedKilometers(targetDistanceKilometers))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if locationService.authorizationState == .available {
                Picker("方向", selection: $selectedDirectionIndex) {
                    ForEach(Self.cardinalDirections.indices, id: \.self) { i in
                        Text(Self.cardinalDirections[i].label).tag(i)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    openInAppleMaps()
                } label: {
                    Label("Apple Maps で案内を開始", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(selectedTarget == nil)
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var goalCandidatePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("周辺の散歩スポット", systemImage: "figure.walk")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if searchState == .searching {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            switch locationService.authorizationState {
            case .notDetermined:
                Button {
                    locationService.requestLocation()
                } label: {
                    Label("現在地を使って探す", systemImage: "location.fill")
                }
                .buttonStyle(.borderedProminent)

            case .denied:
                VStack(alignment: .leading, spacing: 6) {
                    Text("位置情報を許可すると、今いる場所から\(progress.currentSegment.to.name)までの距離感に近い散歩先を探せます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("設定で位置情報を許可する") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }

            case .available:
                if goalCandidates.isEmpty {
                    Text(searchState.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(goalCandidates.prefix(3)) { candidate in
                        HStack(spacing: 8) {
                            Image(systemName: candidate.symbolName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(candidate.tint)
                                .frame(width: 22, height: 22)
                                .background(candidate.tint.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(candidate.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(formattedMeters(candidate.distanceMeters)) · 目標との差 \(formattedMeters(candidate.distanceGapMeters))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
            ))
        }
    }

    private func fitCamera(user: CLLocationCoordinate2D, target: CLLocationCoordinate2D) {
        let minLat = min(user.latitude, target.latitude)
        let maxLat = max(user.latitude, target.latitude)
        let minLon = min(user.longitude, target.longitude)
        let maxLon = max(user.longitude, target.longitude)
        let latPadding = max((maxLat - minLat) * 0.4, 0.005)
        let lonPadding = max((maxLon - minLon) * 0.4, 0.005)
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: (minLat + maxLat) / 2,
                    longitude: (minLon + maxLon) / 2
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: (maxLat - minLat) + latPadding * 2,
                    longitudeDelta: (maxLon - minLon) + lonPadding * 2
                )
            ))
        }
    }

    private func openInAppleMaps() {
        guard let target = selectedTarget else { return }
        let placemark = MKPlacemark(coordinate: target.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = "散歩目標地点（\(target.label)方向）"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    private func searchGoals(from location: CLLocation) {
        searchState = .searching
        Task {
            do {
                let candidates = try await WalkingGoalSearch.search(
                    near: location.coordinate,
                    targetDistanceKilometers: targetDistanceKilometers
                )
                await MainActor.run {
                    goalCandidates = candidates
                    searchState = candidates.isEmpty ? .empty : .idle
                }
            } catch {
                await MainActor.run {
                    goalCandidates = []
                    searchState = .failed
                }
            }
        }
    }

    private func formattedKilometers(_ kilometers: Double) -> String {
        "\(kilometers.formatted(.number.precision(.fractionLength(1))))km"
    }

    private func formattedMeters(_ meters: CLLocationDistance) -> String {
        let kilometers = meters / 1000
        return "\(kilometers.formatted(.number.precision(.fractionLength(1))))km"
    }
}

private enum LocationAuthorizationState {
    case notDetermined
    case denied
    case available
}

private enum GoalSearchState: Equatable {
    case idle
    case searching
    case empty
    case failed

    var message: String {
        switch self {
        case .idle:
            return "現在地の近くから、次の駅までの距離感に近い目的地を探します。"
        case .searching:
            return "候補を検索中です。"
        case .empty:
            return "近い距離の候補が見つかりませんでした。"
        case .failed:
            return "候補を取得できませんでした。"
        }
    }
}

private struct WalkingGoalCandidate: Identifiable {
    let id: String
    let name: String
    let category: WalkingGoalCategory
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: CLLocationDistance
    let distanceGapMeters: CLLocationDistance

    var symbolName: String {
        category.symbolName
    }

    var tint: Color {
        category.tint
    }
}

private enum WalkingGoalCategory: String, Hashable {
    case cafe
    case park

    var query: String {
        switch self {
        case .cafe:
            return "カフェ"
        case .park:
            return "公園"
        }
    }

    var symbolName: String {
        switch self {
        case .cafe:
            return "cup.and.saucer.fill"
        case .park:
            return "tree.fill"
        }
    }

    var tint: Color {
        switch self {
        case .cafe:
            return .brown
        case .park:
            return .green
        }
    }
}

@MainActor
private final class WalkingMapLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationState: LocationAuthorizationState = .notDetermined
    @Published private(set) var location: CLLocation?

    private let locationManager = CLLocationManager()
    #if DEBUG
    private let isDummy = ProcessInfo.processInfo.arguments.contains("-dummy")
    #endif

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        updateAuthorizationState(locationManager.authorizationStatus)
    }

    func requestLocation() {
        #if DEBUG
        if isDummy {
            authorizationState = .available
            location = CLLocation(latitude: 35.6580, longitude: 139.7016)
            return
        }
        #endif
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationState = .available
            locationManager.requestLocation()
        case .denied, .restricted:
            authorizationState = .denied
        @unknown default:
            authorizationState = .denied
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthorizationState(manager.authorizationStatus)
            if authorizationState == .available {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.location = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.location = manager.location
        }
    }

    private func updateAuthorizationState(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            authorizationState = .notDetermined
        case .authorizedAlways, .authorizedWhenInUse:
            authorizationState = .available
        case .denied, .restricted:
            authorizationState = .denied
        @unknown default:
            authorizationState = .denied
        }
    }
}

private enum WalkingGoalSearch {
    static func search(
        near coordinate: CLLocationCoordinate2D,
        targetDistanceKilometers: Double
    ) async throws -> [WalkingGoalCandidate] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let targetMeters = max(300, targetDistanceKilometers * 1000)
        let searchRadiusMeters = max(1200, targetMeters * 1.8)
        let spanDegrees = searchRadiusMeters / 111_000
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees)
        )

        var candidates: [WalkingGoalCandidate] = []
        for category in [WalkingGoalCategory.cafe, .park] {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = category.query
            request.region = region
            let response = try await MKLocalSearch(request: request).start()

            let categoryCandidates = response.mapItems.compactMap { mapItem -> WalkingGoalCandidate? in
                let destination = mapItem.placemark.location
                guard let destination else { return nil }
                let distance = origin.distance(from: destination)
                guard distance > 80 else { return nil }
                let gap = abs(distance - targetMeters)
                let name = mapItem.name ?? category.query
                return WalkingGoalCandidate(
                    id: "\(category.rawValue)-\(name)-\(mapItem.placemark.coordinate.latitude)-\(mapItem.placemark.coordinate.longitude)",
                    name: name,
                    category: category,
                    coordinate: mapItem.placemark.coordinate,
                    distanceMeters: distance,
                    distanceGapMeters: gap
                )
            }

            candidates.append(contentsOf: categoryCandidates)
        }

        return Array(
            candidates
                .sorted { lhs, rhs in
                    if lhs.distanceGapMeters == rhs.distanceGapMeters {
                        return lhs.distanceMeters < rhs.distanceMeters
                    }
                    return lhs.distanceGapMeters < rhs.distanceGapMeters
                }
                .prefix(6)
        )
    }
}

#Preview {
    MainTabView(appStateStore: AppStateStore(userDefaults: .standard))
        .environmentObject(SubscriptionService(initialStatus: .subscribed))
}
