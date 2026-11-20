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
                DSPageHeader(
                    title: "training_history".localized,
                    subtitle: nil,
                    dateLine: nil,
                    tick: DS.Colors.paceRun
                )
                .padding(.horizontal, DS.Space.page)
                .padding(.top, DS.Space.sm)
                .padding(.bottom, DS.Space.lg)

                if records.isEmpty { emptyState } else { recordsList }
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
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(DS.Colors.textTertiary)

            Text("no_records".localized)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DS.Colors.textSecondary)
                .padding(.top, DS.Space.xxs)

            Text("history_empty_hint".localized)
                .font(.system(size: 13))
                .foregroundStyle(DS.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.page)
        .padding(.top, DS.Space.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recordsList: some View {
        List {
            Section {
                historyOverview
                    .listRowInsets(EdgeInsets(top: 0, leading: DS.Space.page, bottom: DS.Space.lg, trailing: DS.Space.page))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { date in
                Section {
                    ForEach(groupedRecords[date] ?? []) { record in
                        RecordRow(record: record)
                            .listRowInsets(EdgeInsets(top: 0, leading: DS.Space.page, bottom: 0, trailing: DS.Space.page))
                            .listRowBackground(DS.Colors.card)
                            .listRowSeparatorTint(DS.Colors.divider)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { recordToDelete = record; showDeleteAlert = true } label: {
                                    Label("delete".localized, systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    Text(formatDate(date).uppercased())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(DS.Colors.textTertiary)
                        .padding(.leading, DS.Space.xxs)
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.defaultMinListRowHeight, 52)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 100, for: .scrollContent)
    }

    // MARK: - Overview (figures, not badges)

    private var historyOverview: some View {
        HStack(alignment: .top, spacing: 0) {
            overviewColumn(value: "\(records.count)", label: "total_records".localized)
            overviewDivider
            overviewColumn(value: "\(records.filter(\.completed).count)", label: "completed".localized)
            overviewDivider
            overviewColumn(value: "\(records.filter { !$0.completed }.count)", label: "stopped_status".localized)
        }
        .padding(.vertical, DS.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Colors.borderLight, lineWidth: 1)
        )
    }

    private func overviewColumn(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(value)
                .font(DS.Typo.figure)
                .monospacedDigit()
                .foregroundStyle(DS.Colors.textPrimary)
            Text(label)
                .font(DS.Typo.meta)
                .foregroundStyle(DS.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Space.lg)
    }

    private var overviewDivider: some View {
        Rectangle()
            .fill(DS.Colors.divider)
            .frame(width: 1, height: 32)
            .padding(.top, DS.Space.xxs)
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
            DSLaneTick(length: 16, color: accent)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Space.sm) {
                    Text(record.trainingType == .paceRun ? "pace_run".localized : "interval_training".localized)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text(record.completed ? "completed".localized : "stopped_status".localized)
                        .font(.system(size: 11))
                        .foregroundStyle(record.completed ? DS.Colors.success : DS.Colors.warning)
                }

                Text(formatTime(record.startTime, endTime: record.endTime))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            Spacer(minLength: 0)

            Text(formatElapsed(record.endTime.timeIntervalSince(record.startTime)))
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(DS.Colors.textPrimary)
        }
        .padding(.vertical, DS.Space.sm + 2)
    }

    private func formatTime(_ start: Date, endTime end: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: start) + " – " + f.string(from: end)
    }

    private func formatElapsed(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval.rounded()))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}
