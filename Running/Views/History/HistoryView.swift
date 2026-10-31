import SwiftUI

struct HistoryView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var storage = StorageManager.shared
    @State private var records: [TrainingRecord] = []
    @State private var showDeleteAlert = false
    @State private var recordToDelete: TrainingRecord?

    var body: some View {
        ZStack {
            DS.Colors.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                // Audit B3: page header matching the training tab idiom
                // (HomeView hides the system navigation bar, so the inline
                // navigationTitle never rendered inside the home tabs).
                Text("training_history".localized)
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if records.isEmpty { emptyState } else { recordsList }
                }
            }
        }
        .navigationTitle("training_history".localized)
        .onAppear { loadRecords() }
        .alert("confirm_delete".localized, isPresented: $showDeleteAlert) {
            Button("cancel".localized, role: .cancel) {}
            Button("delete".localized, role: .destructive) { if let record = recordToDelete { deleteRecord(record) } }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.lg) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(DS.Colors.textTertiary)
            Text("no_records".localized)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var recordsList: some View {
        List {
            Section {
                historyOverview
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
            }
            ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { date in
                Section(header: Text(formatDate(date)).foregroundStyle(DS.Colors.textTertiary)) {
                    ForEach(groupedRecords[date] ?? []) { record in
                        RecordRow(record: record)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { recordToDelete = record; showDeleteAlert = true } label: { Label("delete".localized, systemImage: "trash") }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var historyOverview: some View {
        HStack(spacing: DS.Space.sm) {
            statPill(value: "\(records.count)", label: "history".localized, tint: DS.Colors.paceRun)
            statPill(value: "\(records.filter(\.completed).count)", label: "completed".localized, tint: DS.Colors.success)
            statPill(value: "\(records.filter { !$0.completed }.count)", label: "stopped_status".localized, tint: DS.Colors.warning)
        }
    }

    private func statPill(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(DS.Colors.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DS.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 1)
                .fill(tint)
                .frame(width: 20, height: 2)
                .padding(.top, 6)
        }
    }

    private var groupedRecords: [Date: [TrainingRecord]] { Dictionary(grouping: records) { Calendar.current.startOfDay(for: $0.createdAt) } }
    private func loadRecords() { records = storage.loadTrainingRecords() }
    private func deleteRecord(_ record: TrainingRecord) { storage.deleteTrainingRecord(record); loadRecords() }
    private func formatDate(_ date: Date) -> String { let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: date) }
}

// MARK: - Record Row

struct RecordRow: View {
    let record: TrainingRecord

    private var accent: Color { record.trainingType == .paceRun ? DS.Colors.paceRun : DS.Colors.interval }

    var body: some View {
        HStack(spacing: DS.Space.md) {
            // Accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accent)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Space.sm) {
                    Text(record.trainingType == .paceRun ? "pace_run".localized : "interval_training".localized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text(record.completed ? "completed".localized : "stopped_status".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(record.completed ? DS.Colors.success : DS.Colors.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill((record.completed ? DS.Colors.success : DS.Colors.warning).opacity(DS.Opacity.light))
                        )
                }

                Text(formatTime(record.startTime, endTime: record.endTime))
                    .font(.system(size: 12))
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            Spacer(minLength: 0)

            Text(formatElapsed(record.endTime.timeIntervalSince(record.startTime)))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
    }

    private func formatTime(_ start: Date, endTime end: Date) -> String { let f = DateFormatter(); f.timeStyle = .short; return f.string(from: start) + " – " + f.string(from: end) }
    private func formatElapsed(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval.rounded()))
        let h = s / 3600; let m = (s % 3600) / 60; let sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}
