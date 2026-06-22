import SwiftUI

struct HistoryView: View {
    let records: [DailyRunHistoryRecord]

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var selectedRecord: DailyRunHistoryRecord? {
        let cal = Calendar.current
        return records.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var recentDays: [(date: Date, record: DailyRunHistoryRecord?)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let record = records.first { cal.isDate($0.date, inSameDayAs: date) }
            return (date, record)
        }
    }

    var body: some View {
        List {
            Section {
                WeeklyBarChart(days: recentDays, selectedDate: $selectedDate)
                    .frame(height: 130)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            Section {
                DatePicker(
                    "日付",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }

            Section {
                if let record = selectedRecord {
                    HistoryRecordDetail(record: record)
                } else {
                    ContentUnavailableView(
                        "この日の記録なし",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("ヘルスケアから距離を同期すると、日別の記録がここに表示されます。")
                    )
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("履歴")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeeklyBarChart: View {
    let days: [(date: Date, record: DailyRunHistoryRecord?)]
    @Binding var selectedDate: Date

    private var maxDistance: Double {
        max(1, days.compactMap(\.record?.distanceKilometers).max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(days, id: \.date) { day in
                let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selectedDate)
                DayBar(
                    date: day.date,
                    distance: day.record?.distanceKilometers,
                    maxDistance: maxDistance,
                    isSelected: isSelected
                )
                .onTapGesture { selectedDate = day.date }
                .animation(.easeInOut(duration: 0.18), value: isSelected)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

private struct DayBar: View {
    let date: Date
    let distance: Double?
    let maxDistance: Double
    let isSelected: Bool

    private var fraction: Double {
        guard let d = distance, maxDistance > 0 else { return 0 }
        return d / maxDistance
    }

    var body: some View {
        VStack(spacing: 3) {
            if let distance {
                Text(shortKm(distance))
                    .font(.system(size: 9))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .green : .secondary)
            } else {
                Text("").font(.system(size: 9))
            }

            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Capsule()
                        .fill(barColor)
                        .frame(height: max(3, geo.size.height * fraction))
                }
            }

            Text(weekdayLabel)
                .font(.system(size: 9))
                .foregroundStyle(isSelected ? .green : .secondary)

            Text(dayLabel)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .green : .primary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var barColor: Color {
        if isSelected { return .green }
        return distance != nil ? .green.opacity(0.35) : .gray.opacity(0.15)
    }

    private var weekdayLabel: String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    private var dayLabel: String {
        date.formatted(.dateTime.day())
    }

    private func shortKm(_ km: Double) -> String {
        "\(km.formatted(.number.precision(.fractionLength(1))))km"
    }
}

private struct HistoryRecordDetail: View {
    let record: DailyRunHistoryRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(formattedKm(record.distanceKilometers))
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.green)
                Spacer()
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                if let stepCount = record.stepCount {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("歩数")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Label("\(stepCount.formatted())歩", systemImage: "shoeprints.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("到達駅")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Label(record.reachedStationName, systemImage: "tram.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("周回")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Label("\(record.currentLapNumber)周目", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            if !record.passedStationNames.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("通過駅")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(record.passedStationNames.joined(separator: " → "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedKm(_ km: Double) -> String {
        "\(km.formatted(.number.precision(.fractionLength(1))))km"
    }
}
