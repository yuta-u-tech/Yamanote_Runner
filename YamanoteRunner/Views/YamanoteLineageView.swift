import SwiftUI

struct YamanoteLineageView: View {
    let routeProgress: YamanoteRouteProgress

    private static let geoOrder: [YamanoteStation] = YamanoteRoute.outerSegments.map(\.from)

    var body: some View {
        VStack(spacing: 6) {
            Canvas { context, size in
                draw(in: context, size: size)
            } symbols: {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.green)
                    .tag("runner")
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 4) {
                Image(systemName: "tram.fill")
                Text("出発: \(routeProgress.startingStation.name)")
                Text("›").foregroundStyle(.secondary)
                Text("現在: \(routeProgress.currentSegment.from.name)")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
        }
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let n = Self.geoOrder.count
        let cx = size.width / 2
        let cy = size.height / 2
        let rx = size.width * 0.43
        let ry = size.height * 0.43
        let traversed = traversedArcIndices()
        let passedSet = Set(routeProgress.passedStations.map(\.name))

        for i in 0..<n where !traversed.contains(i) {
            let p1 = pt(i, cx: cx, cy: cy, rx: rx, ry: ry)
            let p2 = pt((i + 1) % n, cx: cx, cy: cy, rx: rx, ry: ry)
            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)
            context.stroke(path, with: .color(.gray.opacity(0.22)), lineWidth: 5)
        }

        for i in traversed {
            let p1 = pt(i, cx: cx, cy: cy, rx: rx, ry: ry)
            let p2 = pt((i + 1) % n, cx: cx, cy: cy, rx: rx, ry: ry)
            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)
            context.stroke(path, with: .color(.green), lineWidth: 5)
        }

        for i in 0..<n {
            let station = Self.geoOrder[i]
            let p = pt(i, cx: cx, cy: cy, rx: rx, ry: ry)
            let isPassed = passedSet.contains(station.name)
            let isStart = station.name == routeProgress.startingStation.name
            let r: CGFloat = isStart ? 5 : 3.5
            let fill: Color = isPassed ? .green : Color(white: 0.6, opacity: 0.7)
            context.fill(
                Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                with: .color(fill)
            )
            if isStart {
                let rr: CGFloat = 9
                context.stroke(
                    Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                    with: .color(.green),
                    lineWidth: 1.5
                )
            }
        }

        if let symbol = context.resolveSymbol(id: "runner") {
            context.draw(symbol, at: runnerPt(cx: cx, cy: cy, rx: rx, ry: ry))
        }
    }

    private func pt(_ index: Int, cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> CGPoint {
        let n = Self.geoOrder.count
        let angle = -CGFloat.pi / 2 + 2 * CGFloat.pi * CGFloat(index) / CGFloat(n)
        return CGPoint(x: cx + rx * cos(angle), y: cy + ry * sin(angle))
    }

    private func runnerPt(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> CGPoint {
        let geoOrder = Self.geoOrder
        guard let fi = geoOrder.firstIndex(of: routeProgress.currentSegment.from),
              let ti = geoOrder.firstIndex(of: routeProgress.currentSegment.to)
        else { return CGPoint(x: cx, y: cy) }
        let p1 = pt(fi, cx: cx, cy: cy, rx: rx, ry: ry)
        let p2 = pt(ti, cx: cx, cy: cy, rx: rx, ry: ry)
        let t = routeProgress.progressInCurrentSegment
        return CGPoint(x: p1.x + (p2.x - p1.x) * t, y: p1.y + (p2.y - p1.y) * t)
    }

    private func traversedArcIndices() -> Set<Int> {
        let geoOrder = Self.geoOrder
        let n = geoOrder.count
        var geoIdx: [String: Int] = [:]
        for (i, s) in geoOrder.enumerated() { geoIdx[s.name] = i }
        var traversed = Set<Int>()
        let passed = routeProgress.passedStations
        guard passed.count >= 2 else { return traversed }
        for i in 0..<(passed.count - 1) {
            guard let ai = geoIdx[passed[i].name],
                  let bi = geoIdx[passed[i + 1].name] else { continue }
            if (ai + 1) % n == bi {
                traversed.insert(ai)
            } else if (bi + 1) % n == ai {
                traversed.insert(bi)
            }
        }
        return traversed
    }
}
