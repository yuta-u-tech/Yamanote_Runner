# Vol.2 Foundation

## Goal

Vol.2 adds a walking map layer on top of the current Yamanote progress loop. The existing v0.1 behavior remains the source of truth for HealthKit distance sync, route progress, history, and badges.

## Scope

- Show a map-oriented walking experience without changing the v0.1 Yamanote route calculation.
- Reuse daily HealthKit distance and history records instead of introducing a second distance source.
- Keep paid or subscription behavior behind a feature boundary until the App Store product and entitlement flow are implemented.
- Preserve offline and permission-denied behavior: the app must still work as the v0.1 progress tracker.

## Non-Goals

- Real-time turn-by-turn navigation.
- Social sharing, ranking, or friend features.
- Replacing Yamanote progress with GPS traces.
- Migrating all persistence to SwiftData before the first map prototype proves the data shape.

## Architecture Boundaries

| Area | Vol.2 Direction |
| --- | --- |
| Distance source | Continue using `HealthDistanceService` and `AppStateStore.syncTodayDistance`. |
| Route progress | Continue using `YamanoteRoute.progress` for station and lap state. |
| Map state | Add separately from route progress so the map can be disabled without corrupting v0.1 data. |
| Entitlement | Introduce a small feature gate before adding StoreKit product logic. |
| Persistence | Keep v0.1 `UserDefaults` keys stable; add new keys only under a Vol.2 namespace. |

## First Implementation Slice

1. Add a MapKit map tab that does not require StoreKit.
2. Show the user's current location on a real map.
3. Use `AppStateStore.routeProgress.distanceToNextStationKilometers` as the target walking distance.
4. Suggest nearby walking goals, such as cafes and parks, whose distance from the user is close to the next-station distance.
5. Keep map-specific state local to the map view until a paid feature boundary is introduced.
6. Add tests for feature gating and state isolation when StoreKit or unlock behavior is added.

## Current Slice

- `MainTabView` includes a `マップ` tab.
- The map centers on the user's current location after location permission is granted.
- The distance to the next Yamanote station is reused as a walking-distance target.
- Nearby cafes and parks are searched with MapKit and ranked by distance gap from that target.
- StoreKit and subscription unlock logic are intentionally not included yet.

## Acceptance Criteria

- v0.1 Home, History, and Badge tabs keep working with existing persisted data.
- Vol.2 code can be disabled without changing route progress or history.
- The first map shell builds and can handle location permission denied or unavailable states.
- No App Store subscription assumptions are hard-coded before product IDs are decided.
