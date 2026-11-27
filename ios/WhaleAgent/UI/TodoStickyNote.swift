import SwiftUI

struct TodoStickyNote: View {
    let item: TodoReminder
    let busy: Bool
    let featured: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var seed: Int {
        item.id.unicodeScalars.reduce(item.listName.count) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7FFF
        }
    }

    private var paper: Color {
        switch seed % 5 {
        case 0: return WhaleTheme.amberSoft
        case 1: return WhaleTheme.roseSoft
        case 2: return WhaleTheme.blueSoft
        case 3: return WhaleTheme.accentSoft
        default: return WhaleTheme.soft
        }
    }

    private var backPaper: Color {
        switch seed % 3 {
        case 0: return WhaleTheme.accentSoft
        case 1: return WhaleTheme.blueSoft
        default: return WhaleTheme.roseSoft
        }
    }

    private var rotation: Double {
        featured ? (seed.isMultiple(of: 2) ? -0.7 : 0.7) : (seed.isMultiple(of: 2) ? 0.45 : -0.45)
    }

    var body: some View {
        note
            .padding(.bottom, featured ? 9 : 0)
            .background {
                if featured {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(backPaper.opacity(0.72))
                        .offset(x: 7, y: 8)
                        .rotationEffect(.degrees(0.8))
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(WhaleTheme.roseSoft.opacity(0.52))
                        .offset(x: -6, y: 4)
                        .rotationEffect(.degrees(-0.55))
                }
            }
            .rotationEffect(.degrees(rotation))
            .padding(.horizontal, featured ? 5 : 2)
            .padding(.top, featured ? 10 : 6)
            .padding(.bottom, featured ? 13 : 5)
            .accessibilityElement(children: .contain)
    }

    private var note: some View {
        VStack(alignment: .leading, spacing: featured ? 14 : 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.listName.uppercased())
                        .tracking(1.2)
                        .whaleFont(size: 10, weight: .bold)
                        .foregroundStyle(WhaleTheme.muted)
                        .lineLimit(1)

                    Label(dueText, systemImage: dueIcon)
                        .whaleFont(size: 12, weight: .semibold)
                        .foregroundStyle(dueColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 6)

                Menu {
                    if item.completed {
                        Button("恢复为待办", systemImage: "arrow.uturn.backward", action: onToggle)
                    } else {
                        Button("标记完成", systemImage: "checkmark.circle", action: onToggle)
                    }
                    Button("删除待办", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .whaleFont(size: 14, weight: .semibold)
                        .foregroundStyle(WhaleTheme.muted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("更多操作")
            }

            HStack(alignment: .top, spacing: 10) {
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(item.completed ? WhaleTheme.success.opacity(0.18) : WhaleTheme.card.opacity(0.52))
                            .overlay {
                                Circle().strokeBorder(
                                    item.completed ? WhaleTheme.success : WhaleTheme.ink.opacity(0.28),
                                    lineWidth: 1.4
                                )
                            }
                            .frame(width: 29, height: 29)

                        if busy {
                            ProgressView().scaleEffect(0.55)
                        } else if item.completed {
                            Image(systemName: "checkmark")
                                .whaleFont(size: 13, weight: .bold)
                                .foregroundStyle(WhaleTheme.success)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.whalePress)
                .disabled(busy)
                .accessibilityLabel(item.completed ? "恢复 \(item.title)" : "完成 \(item.title)")

                VStack(alignment: .leading, spacing: 7) {
                    Text(item.title)
                        .whaleFont(
                            size: featured ? 22 : 17,
                            weight: .bold,
                            design: .rounded
                        )
                        .foregroundStyle(item.completed ? WhaleTheme.muted : WhaleTheme.ink)
                        .strikethrough(item.completed, color: WhaleTheme.muted)
                        .lineLimit(featured ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .whaleSpeakable(item.title)

                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .whaleFont(size: featured ? 14 : 13)
                            .foregroundStyle(WhaleTheme.muted)
                            .lineLimit(featured ? 3 : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .whaleSpeakable(notes)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 7) {
                Label(item.completed ? "已完成" : "待办", systemImage: item.completed ? "checkmark.circle.fill" : "bookmark.fill")
                    .whaleFont(size: 11, weight: .semibold)
                    .foregroundStyle(item.completed ? WhaleTheme.success : WhaleTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WhaleTheme.card.opacity(0.42), in: Capsule())

                if item.deduplicated {
                    Text("已去重")
                        .whaleFont(size: 11, weight: .semibold)
                        .foregroundStyle(WhaleTheme.muted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(WhaleTheme.card.opacity(0.34), in: Capsule())
                }

                Spacer(minLength: 0)

                Image(systemName: "quote.opening")
                    .whaleFont(size: 15, weight: .medium)
                    .foregroundStyle(WhaleTheme.ink.opacity(0.24))
                    .accessibilityHidden(true)
            }
        }
        .padding(featured ? 18 : 14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(paper)
                LinearGradient(
                    colors: [WhaleTheme.card.opacity(0.34), .clear, WhaleTheme.ink.opacity(0.025)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(WhaleTheme.ink.opacity(0.075), lineWidth: 0.8)
        }
        .overlay(alignment: .top) {
            noteFastener
                .offset(y: featured ? -9 : -7)
        }
        .whaleListElevation()
        .contextMenu {
            Button("删除待办", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder
    private var noteFastener: some View {
        if featured {
            Image(systemName: "pin.fill")
                .whaleFont(size: 18, weight: .bold)
                .foregroundStyle(WhaleTheme.accent)
                .rotationEffect(.degrees(-10))
                .shadow(color: WhaleTheme.ink.opacity(0.22), radius: 3, y: 2)
        } else {
            Capsule()
                .fill(WhaleTheme.card.opacity(0.66))
                .frame(width: 72, height: 15)
                .overlay {
                    Capsule().strokeBorder(WhaleTheme.ink.opacity(0.055), lineWidth: 0.6)
                }
                .rotationEffect(.degrees(rotation < 0 ? -2.2 : 2.2))
                .shadow(color: WhaleTheme.ink.opacity(0.08), radius: 2, y: 1)
        }
    }

    private var dueText: String {
        guard let due = item.dueAt else { return "今天" }
        let calendar = Calendar.current
        let time = due.formatted(date: .omitted, time: .shortened)
        if item.completed { return "已完成" }
        if due < Date() { return "已逾期 · \(time)" }
        if calendar.isDateInToday(due) { return "今天 · \(time)" }
        if calendar.isDateInTomorrow(due) { return "明天 · \(time)" }
        return due.formatted(.dateTime.month().day().hour().minute())
    }

    private var dueIcon: String {
        if item.completed { return "checkmark.circle.fill" }
        guard let due = item.dueAt else { return "calendar" }
        if due < Date() { return "exclamationmark.circle.fill" }
        return "clock.fill"
    }

    private var dueColor: Color {
        if item.completed { return WhaleTheme.success }
        guard let due = item.dueAt else { return WhaleTheme.accent }
        if due < Date() { return WhaleTheme.danger }
        if Calendar.current.isDateInToday(due) { return WhaleTheme.coral }
        return WhaleTheme.muted
    }
}
