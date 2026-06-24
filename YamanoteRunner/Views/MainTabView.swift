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
    @State private var searchState: WalkingGoalSearchState = .idle
    @State private var guidanceState = WalkingGuidanceState()
    @State private var walkingRoute: MKRoute?
    @State private var routeState: WalkingRouteState = .idle
    @State private var routeTask: Task<Void, Never>?
    @Environment(\.openURL) private var openURL

    private static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671),
        span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
    )

    private var progress: YamanoteRouteProgress { appStateStore.routeProgress }
    private var targetDistanceKilometers: Double { progress.distanceToNextStationKilometers }
    private var targetDistanceMeters: CLLocationDistance {
        WalkingGoalService.targetDistanceMeters(fromNextStationKilometers: targetDistanceKilometers)
    }
    private var selectedCandidate: WalkingGoalCandidate? { guidanceState.selectedCandidate }
    private var isActivelyGuiding: Bool {
        guidanceState.status == .guiding || guidanceState.status == .arrived
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                UserAnnotation()

                if let candidate = selectedCandidate {
                    Marker(candidate.name, systemImage: "mappin.circle.fill", coordinate: candidate.coordinate)
                        .tint(.green)
                    if let walkingRoute {
                        MapPolyline(walkingRoute.polyline)
                            .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }
                }

                if !isActivelyGuiding {
                    ForEach(goalCandidates.filter { $0.id != selectedCandidate?.id }) { candidate in
                        Marker(candidate.name, systemImage: candidate.category.symbolName, coordinate: candidate.coordinate)
                            .tint(candidate.category.tint)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 10) {
                if isActivelyGuiding {
                    activeGuidanceBar
                } else {
                    guidancePanel
                    candidatePanel
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .navigationTitle("マップ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            locationService.requestLocation()
        }
        .onDisappear {
            locationService.stopUpdating()
            routeTask?.cancel()
        }
        .onChange(of: locationService.location) { _, location in
            guard let location else { return }
            handleLocationUpdate(location)
        }
        .onChange(of: targetDistanceKilometers) { _, _ in
            guard !isActivelyGuiding else { return }
            guard let location = locationService.location else { return }
            searchGoals(from: location)
        }
    }

    private var activeGuidanceBar: some View {
        HStack(spacing: 10) {
            Image(systemName: guidanceState.status == .arrived ? "checkmark.circle.fill" : "figure.walk.motion")
                .font(.headline)
                .foregroundStyle(guidanceState.status == .arrived ? Color.green : Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(guidanceInstructionText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(activeRouteStatusText)
                    .font(.caption2)
                    .foregroundStyle(guidanceState.status == .arrived ? Color.green : Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                guard let location = locationService.location, let candidate = selectedCandidate else { return }
                requestWalkingRoute(from: location, to: candidate, shouldFitCamera: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(routeState == .loading || selectedCandidate == nil)
            .accessibilityLabel("徒歩ルートを再設定")

            Button {
                cancelGuidance()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("案内を中断")
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var guidancePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "map.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(progress.currentSegment.to.name)まであと\(formattedKilometers(targetDistanceKilometers))")
                        .font(.subheadline.weight(.semibold))
                    Text("現実の目的地: 約\(formattedMeters(targetDistanceMeters))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            switch locationService.authorizationState {
            case .notDetermined:
                Button {
                    locationService.requestLocation()
                } label: {
                    Label("現在地を使って探す", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

            case .denied:
                VStack(alignment: .leading, spacing: 8) {
                    Text("位置情報を許可すると、次の駅までの距離感に近い目的地を探せます。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label("設定を開く", systemImage: "gearshape.fill")
                    }
                    .buttonStyle(.bordered)
                }

            case .available:
                guidanceControls
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var guidanceControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let candidate = selectedCandidate {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: candidate.category.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(candidate.category.tint)
                        .frame(width: 24, height: 24)
                        .background(candidate.category.tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("\(candidate.category.displayName) · \(formattedMeters(candidate.straightLineDistanceMeters)) · 目標との差 \(formattedMeters(candidate.distanceGapMeters))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                if guidanceState.status == .guiding || guidanceState.status == .arrived {
                    HStack(spacing: 8) {
                        Image(systemName: guidanceState.status == .arrived ? "checkmark.circle.fill" : "location.north.line.fill")
                            .foregroundStyle(guidanceState.status == .arrived ? Color.green : Color.accentColor)
                        Text(guidanceInstructionText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    ProgressView(value: guidanceState.progress)
                        .tint(.green)
                    Text(guidanceStatusText)
                        .font(.caption)
                        .foregroundStyle(guidanceState.status == .arrived ? Color.green : Color.secondary)
                }

                HStack(spacing: 8) {
                    Button {
                        if let location = locationService.location {
                            guidanceState.start(from: location)
                            locationService.startUpdating()
                            requestWalkingRoute(from: location, to: candidate, shouldFitCamera: true)
                        }
                    } label: {
                        Label(primaryGuidanceButtonTitle, systemImage: primaryGuidanceButtonIcon)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(guidanceState.status == .guiding || guidanceState.status == .arrived || locationService.location == nil)

                    Button {
                        cancelGuidance()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("案内をキャンセル")
                }

                Button {
                    openInAppleMaps(candidate)
                } label: {
                    Label("Apple Mapsでも開く", systemImage: "arrow.triangle.turn.up.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                Text("候補を選ぶと、Yamanote_Runner 内で目的地までの残距離と到着進捗を確認できます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var candidatePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("距離が近い目的地", systemImage: "figure.walk")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if searchState == .searching {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            switch locationService.authorizationState {
            case .notDetermined:
                Text("現在地の許可待ちです。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .denied:
                Text("位置情報がオフのため候補を表示できません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .available:
                if goalCandidates.isEmpty {
                    Text(searchState.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(goalCandidates) { candidate in
                                Button {
                                    select(candidate)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: candidate.category.symbolName)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(candidate.category.tint)
                                            .frame(width: 24, height: 24)
                                            .background(candidate.category.tint.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(candidate.name)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.primary)
                                                .lineLimit(1)
                                            Text("\(formattedMeters(candidate.straightLineDistanceMeters)) · 差 \(formattedMeters(candidate.distanceGapMeters))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer(minLength: 0)

                                        Image(systemName: candidate.id == selectedCandidate?.id ? "checkmark.circle.fill" : "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(candidate.id == selectedCandidate?.id ? Color.green : Color.secondary)
                                    }
                                    .frame(width: 178, alignment: .leading)
                                    .padding(8)
                                    .background(.thinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var guidanceInstructionText: String {
        if guidanceState.status == .arrived {
            return "目的地付近に到着しました"
        }
        if routeState == .loading {
            return "徒歩ルートを取得中です"
        }
        let direction = guidanceState.directionText() ?? "目的地の方向"
        let remaining = formattedMeters(guidanceState.remainingDistanceMeters ?? 0)
        return "\(direction)へ約\(remaining)進んでください"
    }

    private var activeRouteStatusText: String {
        if guidanceState.status == .arrived {
            return "別の候補は中断後に選択できます"
        }
        switch routeState {
        case .idle:
            return guidanceStatusText
        case .loading:
            return "道路に沿った徒歩経路を検索しています"
        case .ready:
            return "\(guidanceStatusText) · 徒歩ルート表示中"
        case .failed:
            return "\(guidanceStatusText) · 徒歩ルートを取得できませんでした"
        }
    }

    private var guidanceStatusText: String {
        if guidanceState.status == .arrived {
            return "到着しました。別の候補はキャンセル後に選択できます。"
        }
        return "残り \(formattedMeters(guidanceState.remainingDistanceMeters ?? 0)) · 進捗 \(guidanceState.progress.formatted(.percent.precision(.fractionLength(0))))"
    }

    private var primaryGuidanceButtonTitle: String {
        guidanceState.status == .arrived ? "到着済み" : "アプリ内案内を開始"
    }

    private var primaryGuidanceButtonIcon: String {
        guidanceState.status == .arrived ? "checkmark.circle.fill" : "location.north.line.fill"
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        if guidanceState.status == .guiding || guidanceState.status == .candidateSelected {
            guidanceState.updateLocation(location)
        }

        if let candidate = selectedCandidate {
            if walkingRoute == nil {
                fitCamera(user: location.coordinate, target: candidate.coordinate)
            }
            if guidanceState.status == .guiding {
                requestWalkingRoute(from: location, to: candidate, shouldFitCamera: false)
            }
        } else {
            centerMap(on: location.coordinate)
        }

        if guidanceState.status != .guiding && guidanceState.status != .arrived {
            searchGoals(from: location)
        }
    }

    private func select(_ candidate: WalkingGoalCandidate) {
        guard let location = locationService.location else { return }
        guidanceState.select(candidate, from: location)
        walkingRoute = nil
        routeState = .idle
        requestWalkingRoute(from: location, to: candidate, shouldFitCamera: true)
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

    private func fitCamera(to mapRect: MKMapRect) {
        let paddedRect = mapRect.insetBy(dx: -mapRect.width * 0.25, dy: -mapRect.height * 0.25)
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(MKCoordinateRegion(paddedRect))
        }
    }

    private func openInAppleMaps(_ candidate: WalkingGoalCandidate) {
        let placemark = MKPlacemark(coordinate: candidate.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = candidate.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    private func cancelGuidance() {
        guidanceState.cancel()
        walkingRoute = nil
        routeState = .idle
        routeTask?.cancel()
        if let location = locationService.location {
            searchGoals(from: location)
            centerMap(on: location.coordinate)
        }
    }

    private func requestWalkingRoute(
        from location: CLLocation,
        to candidate: WalkingGoalCandidate,
        shouldFitCamera: Bool
    ) {
        routeTask?.cancel()
        routeState = .loading
        routeTask = Task {
            do {
                let route = try await WalkingRouteSearch.route(
                    from: location.coordinate,
                    to: candidate.coordinate
                )
                await MainActor.run {
                    guard selectedCandidate?.id == candidate.id else { return }
                    walkingRoute = route
                    routeState = .ready
                    guidanceState.updateRouteDistance(route.distance)
                    if shouldFitCamera {
                        fitCamera(to: route.polyline.boundingMapRect)
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard selectedCandidate?.id == candidate.id else { return }
                    walkingRoute = nil
                    routeState = .failed
                    if shouldFitCamera {
                        fitCamera(user: location.coordinate, target: candidate.coordinate)
                    }
                }
            }
        }
    }

    private func searchGoals(from location: CLLocation) {
        searchState = .searching
        Task {
            do {
                let candidates = try await WalkingGoalMapSearch.search(
                    near: location.coordinate,
                    targetDistanceMeters: targetDistanceMeters
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
        if meters < 1000 {
            return "\(meters.formatted(.number.precision(.fractionLength(0))))m"
        }
        let kilometers = meters / 1000
        return "\(kilometers.formatted(.number.precision(.fractionLength(1))))km"
    }
}

private enum LocationAuthorizationState {
    case notDetermined
    case denied
    case available
}

private enum WalkingRouteState: Equatable {
    case idle
    case loading
    case ready
    case failed
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
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 20
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

    func startUpdating() {
        #if DEBUG
        if isDummy { return }
        #endif
        guard authorizationState == .available else { return }
        locationManager.startUpdatingLocation()
    }

    func stopUpdating() {
        locationManager.stopUpdatingLocation()
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

private enum WalkingGoalMapSearch {
    static func search(
        near coordinate: CLLocationCoordinate2D,
        targetDistanceMeters: CLLocationDistance
    ) async throws -> [WalkingGoalCandidate] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let searchRadiusMeters = WalkingGoalService.searchRadiusMeters(forTargetDistanceMeters: targetDistanceMeters)
        let spanDegrees = searchRadiusMeters / 111_000
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: spanDegrees, longitudeDelta: spanDegrees)
        )

        var candidates: [WalkingGoalCandidate] = []
        for category in WalkingGoalCategory.allCases {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = category.searchQuery
            request.region = region
            let response = try await MKLocalSearch(request: request).start()

            let categoryCandidates = response.mapItems.compactMap { mapItem -> WalkingGoalCandidate? in
                guard let destination = mapItem.placemark.location else { return nil }
                let distance = origin.distance(from: destination)
                let gap = abs(distance - targetDistanceMeters)
                let name = mapItem.name ?? category.displayName
                return WalkingGoalCandidate(
                    id: "\(category.rawValue)-\(name)-\(mapItem.placemark.coordinate.latitude)-\(mapItem.placemark.coordinate.longitude)",
                    name: name,
                    coordinate: mapItem.placemark.coordinate,
                    category: category,
                    straightLineDistanceMeters: distance,
                    distanceGapMeters: gap,
                    address: mapItem.placemark.title,
                    sourceName: "MapKit"
                )
            }

            candidates.append(contentsOf: categoryCandidates)
        }

        return WalkingGoalService.rankedCandidates(
            candidates,
            targetDistanceMeters: targetDistanceMeters
        )
    }
}

private enum WalkingRouteSearch {
    static func route(
        from sourceCoordinate: CLLocationCoordinate2D,
        to destinationCoordinate: CLLocationCoordinate2D
    ) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: sourceCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate))
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else {
            throw WalkingRouteSearchError.routeNotFound
        }
        return route
    }
}

private enum WalkingRouteSearchError: Error {
    case routeNotFound
}

private extension WalkingGoalCategory {
    var symbolName: String {
        switch self {
        case .cafe:
            return "cup.and.saucer.fill"
        case .park:
            return "tree.fill"
        case .convenienceStore:
            return "bag.fill"
        case .landmark:
            return "building.columns.fill"
        }
    }

    var tint: Color {
        switch self {
        case .cafe:
            return .brown
        case .park:
            return .green
        case .convenienceStore:
            return .blue
        case .landmark:
            return .purple
        }
    }
}

#Preview {
    MainTabView(appStateStore: AppStateStore(userDefaults: .standard))
        .environmentObject(SubscriptionService(initialStatus: .subscribed))
}
