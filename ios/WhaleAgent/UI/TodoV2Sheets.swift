struct TodoScheduleSheet: View {
    let item: TodoReminder
    @ObservedObject var model: AppModel
    let onChanged: (TodoReminder?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [TodoScheduleCandidate] = []
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title)
                            .font(.headline)
                        Text("读取真实日历后给出候选空档；点选后才写入提醒时间。")
                            .font(.subheadline)
                            .foregroundStyle(WhaleTheme.muted)
                    }
                    .padding(.vertical, 4)
                }

                Section("候选空档") {
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("正在核对日历…")
                        }
                    } else if candidates.isEmpty {
                        Text(errorText ?? "今天没有找到合适空档。")
                            .foregroundStyle(WhaleTheme.muted)
                    } else {
                        ForEach(candidates) { candidate in
                            Button {
                                Task { await apply(candidate) }
                            } label: {
                                HStack {
                                    Image(systemName: "clock.badge.checkmark")
                                        .foregroundStyle(WhaleTheme.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.start.formatted(.dateTime.hour().minute()))
                                            .font(.body.weight(.semibold))
                                        Text("至 \(candidate.end.formatted(date: .omitted, time: .shortened))")
                                            .font(.caption)
                                            .foregroundStyle(WhaleTheme.muted)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle")
                                        .foregroundStyle(WhaleTheme.accent)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("移入收件箱", systemImage: "tray.and.arrow.down") {
                        Task { await moveToInbox() }
                    }
                    Button("重新查找", systemImage: "arrow.clockwise") {
                        Task { await loadCandidates() }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WhaleBackdrop())
            .tint(WhaleTheme.accent)
            .navigationTitle("智能排期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .task { await loadCandidates() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func loadCandidates() async {
        isLoading = true
        errorText = nil
        if model.upcomingEvents.isEmpty {
            await model.refreshDashboard(force: true)
        }
        candidates = TodoSchedulePlanner.candidates(for: item, events: model.upcomingEvents)
        isLoading = false
    }

    private func apply(_ candidate: TodoScheduleCandidate) async {
        do {
            let updated = try await model.rescheduleTodoReminder(item, dueAt: candidate.start)
            onChanged(updated)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func moveToInbox() async {
        do {
            let updated = try await model.rescheduleTodoReminder(item, dueAt: nil)
            onChanged(updated)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
