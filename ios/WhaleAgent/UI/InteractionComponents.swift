import SwiftUI

private struct ReadableFont: ViewModifier {
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 17
    let weight: Font.Weight
    let design: Font.Design
    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: max(13, size), relativeTo: .body)
        self.weight = weight; self.design = design
    }
    func body(content: Content) -> some View { content.font(.system(size: size, weight: weight, design: design)) }
}

extension View {
    func whaleFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(ReadableFont(size: size, weight: weight, design: design))
    }
    func whaleTouchTarget() -> some View { frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
}

struct InlinePlaybackView: View {
    @ObservedObject var model: AppModel
    let onOpen: () -> Void
    var body: some View {
        if let track = model.playback.track {
            HStack(spacing: 12) {
                Button(action: onOpen) {
                    HStack(spacing: 12) {
                        Image(systemName: "music.note").foregroundStyle(WhaleTheme.accent).frame(width: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title).font(.headline).foregroundStyle(WhaleTheme.ink).lineLimit(2)
                            Text(model.playback.isPlaying ? "正在播放" : "已暂停").font(.subheadline).foregroundStyle(WhaleTheme.muted)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
                Button { Task { await model.togglePlayback() } } label: {
                    Image(systemName: model.playback.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundStyle(WhaleTheme.accent).whaleTouchTarget()
                }.buttonStyle(.plain).disabled(model.isMusicBusy)
                    .accessibilityLabel(model.playback.isPlaying ? "暂停音乐" : "继续播放")
            }.whaleCard(padding: 14)
        }
    }
}

struct AssistantActivityView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.isBusy {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(WhaleIMessagePalette.outgoing)
                        .frame(width: 7, height: 7)
                    Text(model.isExecutingTool ? "正在执行" : "正在研究")
                        .whaleFont(size: 14, weight: .semibold)
                        .foregroundStyle(WhaleIMessagePalette.text)
                    Spacer(minLength: 0)
                    if model.canStopReply {
                        Menu {
                            Button("停止整轮等待", systemImage: "stop.circle", role: .destructive) {
                                model.stopReply()
                            }
                            if let pending = model.pending.first {
                                Button("跳过当前操作", systemImage: "forward.end.circle") {
                                    Task { await model.skip(pending) }
                                }
                            }
                        } label: {
                            Label("处理中", systemImage: "ellipsis.circle")
                                .whaleFont(size: 13, weight: .medium)
                                .foregroundStyle(WhaleIMessagePalette.muted)
                                .whaleTouchTarget()
                        }
                        .accessibilityLabel("停止或跳过当前步骤")
                    }
                }

                Text(model.activityDescription)
                    .whaleFont(size: 14)
                    .foregroundStyle(WhaleIMessagePalette.muted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Label(
                    "意图预览 → 执行 → 结果回执",
                    systemImage: "checklist.checked"
                )
                .whaleFont(size: 12, weight: .medium)
                .foregroundStyle(WhaleIMessagePalette.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(WhaleIMessagePalette.incoming, in: WhaleIMessagePalette.incomingShape())
            .accessibilityElement(children: .contain)
        }
    }
}

struct InteractionReceiptCard: View {
    @ObservedObject var model: AppModel

    private var receipt: AgentOperationReceipt? {
        guard let value = model.operationReceipts.first else { return nil }
        guard Date().timeIntervalSince(value.createdAt) < 15 * 60 else { return nil }
        guard [.completed, .failed, .cancelled].contains(value.phase) else { return nil }
        return value
    }

    var body: some View {
        if let receipt {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: receipt.status == "success" ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .whaleFont(size: 16, weight: .semibold)
                    .foregroundStyle(receipt.status == "success" ? WhaleTheme.success : WhaleTheme.warm)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text("操作回执")
                            .whaleFont(size: 12, weight: .bold)
                            .foregroundStyle(WhaleIMessagePalette.outgoing)
                        Text(receipt.createdAt.formatted(date: .omitted, time: .shortened))
                            .whaleFont(size: 12)
                            .foregroundStyle(WhaleIMessagePalette.muted)
                    }
                    Text(receipt.title)
                        .whaleFont(size: 14, weight: .semibold)
                        .foregroundStyle(WhaleIMessagePalette.text)
                    Text(receipt.detail)
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleIMessagePalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .background(WhaleIMessagePalette.incoming, in: WhaleIMessagePalette.incomingShape())
            .accessibilityElement(children: .combine)
        }
    }
}

struct WorkingContextBar: View {
    let context: AgentWorkingContext
    let onOpen: () -> Void
    let onDismiss: () -> Void

    private var tint: Color {
        context.needsAttention ? WhaleTheme.warm : WhaleTheme.accent
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    Image(systemName: context.needsAttention ? "hand.raised.fill" : "scope")
                        .whaleFont(size: 15, weight: .semibold)
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("当前任务")
                                .whaleFont(size: 11, weight: .bold)
                                .foregroundStyle(tint)
                            Text(context.status.title)
                                .whaleFont(size: 11, weight: .medium)
                                .foregroundStyle(WhaleTheme.muted)
                        }
                        Text(context.goal)
                            .whaleFont(size: 14, weight: .semibold)
                            .foregroundStyle(WhaleTheme.ink)
                            .lineLimit(1)
                        Text(context.summary)
                            .whaleFont(size: 12)
                            .foregroundStyle(WhaleTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .whaleFont(size: 12, weight: .semibold)
                        .foregroundStyle(WhaleTheme.muted.opacity(0.7))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("当前任务，\(context.goal)，\(context.status.title)")
            .accessibilityHint("回到原对话")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .whaleFont(size: 12, weight: .bold)
                    .foregroundStyle(WhaleTheme.muted)
                    .frame(width: 34, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("结束当前任务上下文")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 7)
        .background(WhaleTheme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .accessibilityIdentifier("working-context")
    }
}

struct OperationPreviewCard<Actions: View>: View {
    let preview: OperationPreview
    private let actions: Actions

    init(_ preview: OperationPreview, @ViewBuilder actions: () -> Actions) {
        self.preview = preview
        self.actions = actions()
    }

    private var tint: Color {
        switch preview.kind {
        case .delete: return WhaleTheme.danger
        case .external: return WhaleIMessagePalette.outgoing
        case .create, .update, .save: return WhaleIMessagePalette.outgoing
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon)
                    .whaleFont(size: 17, weight: .semibold)
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(preview.actionLabel)
                            .whaleFont(size: 11, weight: .bold)
                            .foregroundStyle(tint)
                        Text("执行前预览")
                            .whaleFont(size: 11)
                            .foregroundStyle(WhaleIMessagePalette.muted)
                    }
                    Text(preview.title)
                        .whaleFont(size: 18, weight: .bold, design: .rounded)
                        .foregroundStyle(WhaleIMessagePalette.text)
                }
                Spacer(minLength: 0)
            }

            Text(preview.summary)
                .whaleFont(size: 15, weight: .medium)
                .foregroundStyle(WhaleIMessagePalette.text)
                .fixedSize(horizontal: false, vertical: true)

            if !preview.rows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(preview.rows) { row in
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: row.icon)
                                .whaleFont(size: 12, weight: .semibold)
                                .foregroundStyle(WhaleIMessagePalette.muted)
                                .frame(width: 18)
                            Text(row.label)
                                .whaleFont(size: 12, weight: .medium)
                                .foregroundStyle(WhaleIMessagePalette.muted)
                                .frame(width: 42, alignment: .leading)
                            Text(row.value)
                                .whaleFont(size: 13, weight: .semibold)
                                .foregroundStyle(WhaleIMessagePalette.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 8)
                        if row.id != preview.rows.last?.id {
                            Divider().overlay(WhaleIMessagePalette.line)
                        }
                    }
                }
                .padding(.horizontal, 11)
                .background(WhaleIMessagePalette.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Label(preview.note, systemImage: "checkmark.shield")
                .whaleFont(size: 12)
                .foregroundStyle(WhaleIMessagePalette.muted)
                .fixedSize(horizontal: false, vertical: true)

            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(WhaleIMessagePalette.incoming, in: WhaleIMessagePalette.incomingShape())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("operation-preview")
    }

    private var icon: String {
        switch preview.kind {
        case .create: return "plus.circle.fill"
        case .update: return "arrow.triangle.2.circlepath"
        case .delete: return "trash.fill"
        case .external: return "arrow.up.forward.app.fill"
        case .save: return "square.and.arrow.down.fill"
        }
    }
}

struct DiscoverHubView: View {
    @ObservedObject var model: AppModel
    let onOpen: (DiscoverChannel) -> Void
    let onSettings: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("发现").font(.largeTitle.bold()).foregroundStyle(WhaleTheme.ink)
                    Spacer()
                    Button(action: onSettings) { Image(systemName: "gearshape").whaleTouchTarget() }
                        .accessibilityLabel("设置")
                }
                Text("想读的、想听的，都在这里。")
                    .font(.body).foregroundStyle(WhaleTheme.muted)
                InlinePlaybackView(model: model) { onOpen(.music) }
                VStack(spacing: 0) {
                    ForEach(DiscoverChannel.allCases) { channel in
                        Button { onOpen(channel) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: channel.icon).font(.title3).foregroundStyle(WhaleTheme.accent)
                                    .frame(width: 44, height: 44).background(WhaleTheme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(channel.title).font(.headline).foregroundStyle(WhaleTheme.ink)
                                    Text(channel.subtitle).font(.subheadline).foregroundStyle(WhaleTheme.muted).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").foregroundStyle(WhaleTheme.muted)
                            }.padding(.vertical, 13).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(channel.title).accessibilityHint(channel.subtitle)
                            .accessibilityIdentifier("discover-channel-" + channel.rawValue)
                        if channel != DiscoverChannel.allCases.last { Divider() }
                    }
                }.whaleCard()
            }.padding(20)
        }.scrollIndicators(.hidden).background(WhaleTheme.background)
    }
}
