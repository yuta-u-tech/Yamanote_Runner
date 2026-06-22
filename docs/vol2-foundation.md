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

1. Add an unavailable/locked map tab shell that does not require StoreKit.
2. Define the map view model state separately from `AppStateStore`.
3. Decide the first map data source:
   - static Yamanote route visualization, or
   - user walking path mock, or
   - MapKit user-location preview.
4. Add tests for feature gating and state isolation.

## Acceptance Criteria

- v0.1 Home, History, and Badge tabs keep working with existing persisted data.
- Vol.2 code can be disabled without changing route progress or history.
- The first map shell builds and runs in simulator with dummy data.
- No App Store subscription assumptions are hard-coded before product IDs are decided.
