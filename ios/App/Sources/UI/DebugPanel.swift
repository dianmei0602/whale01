import SwiftUI

/// 长按「早上好」呼出的调试面板。
/// 目的：不靠天气、不靠时间，也能把每条规则和每档表情看一遍。
struct DebugPanel: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    private let scenarios: [(id: String, title: String)] = [
        ("clear", "空的一天"),
        ("rain", "雨天 · 带伞"),
        ("air", "空气差 · 改室内"),
        ("warm", "降温 · 加衣服"),
        ("meet", "有会议 · 专注"),
        ("sport", "运动窗口 · 兴奋"),
        ("sleep", "睡前 · 困"),
        ("todo", "有待办 · 打量")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("场景") {
                    ForEach(scenarios.indices, id: \.self) { index in
                        Button(scenarios[index].title) {
                            state.debugScenario(scenarios[index].id)
                        }
                    }
                }

                Section("表情") {
                    ForEach(PetMood.all, id: \.id) { mood in
                        Button(mood.id) {
                            state.debugMood(mood)
                        }
                    }
                }

                Section("年龄") {
                    HStack {
                        Button("+7 天") { state.debugAdvanceAge(7) }
                        Spacer()
                        Button("+30 天") { state.debugAdvanceAge(30) }
                        Spacer()
                        Button("+90 天") { state.debugAdvanceAge(90) }
                    }
                    .buttonStyle(.bordered)
                }

                Section {
                    Button("重置为真实数据") { state.debugReset() }
                }
            }
            .navigationTitle("调试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}