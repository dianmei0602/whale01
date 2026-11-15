import SwiftUI

/// 记忆：看看它记住了什么，可以一条条删。
///
/// 之前只有「清空全部」，用户不放心——不知道存了什么、删不掉某一条。
struct MemoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var turns: [ChatTurn] = []
    @State private var showClearConfirm = false

    private var formatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        return f
    }

    var body: some View {
        NavigationStack {
            Group {
                if turns.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(CardPalette.screen)
            .navigationTitle("记忆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("清空") { showClearConfirm = true }
                        .disabled(turns.isEmpty)
                        .foregroundColor(turns.isEmpty ? .secondary : Color(red: 0.95, green: 0.42, blue: 0.35))
                }
            }
            .alert("清空全部记忆？", isPresented: $showClearConfirm) {
                Button("清空", role: .destructive) {
                    ChatStore.clear()
                    turns = []
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("清空后模型不再记得你们聊过什么，这一步不能撤销。")
            }
        }
        .preferredColorScheme(nil)
        .onAppear { turns = ChatStore.load() }
    }

    // MARK: - 列表

    private var list: some View {
        List {
            Section {
                ForEach(Array(turns.enumerated()), id: \.offset) { index, turn in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(turn.mine ? "你" : "Nomi")
                                .font(.nomiScaled(size: 12, weight: .semibold))
                                .foregroundColor(turn.mine ? CardPalette.accent : CardPalette.ink)
                            Spacer()
                            Text(formatter.string(from: turn.date))
                                .font(.nomiScaled(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Text(turn.text)
                            .font(.nomiScaled(size: 14.5))
                            .foregroundColor(CardPalette.ink)
                            .lineLimit(4)
                    }
                    .padding(.vertical, 3)
                }
                .onDelete { offsets in
                    // 从后往前删，索引才不会错位
                    for index in offsets.sorted(by: >) {
                        ChatStore.remove(at: index)
                    }
                    turns = ChatStore.load()
                }
            } header: {
                Text("共 \(turns.count) 条 · 左滑删除")
            } footer: {
                Text("只存在这台手机里，不会上传。模型回答时会带上最近 12 条。")
            }
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - 空态

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("还没有记忆")
                .font(.nomiScaled(size: 17, weight: .semibold))
                .foregroundColor(CardPalette.ink)
            Text("和它聊几句，这里就会记下来。")
                .font(.nomiScaled(size: 13.5))
                .foregroundColor(CardPalette.subtle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
