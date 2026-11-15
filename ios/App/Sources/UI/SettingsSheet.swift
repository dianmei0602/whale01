import SwiftUI
import UIKit

/// 设置：按 iOS 设置页的分组方式重排。
///
/// 一屏只放四块：你是谁、两个总开关、三个入口、高级。
/// 里面所有细节都收进子页，主页面不再是一条条往下滚的长表单。
struct SettingsSheet: View {

    var state: AppState
    var showsDoneButton: Bool = true

    @Environment(\.dismiss) private var dismiss
    @State private var showMemory = false
    @State private var showPhysicsBox = false
    @State private var nickname = ""

    private var memoryCount: Int { ChatStore.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                title

                ScrollView {
                    VStack(spacing: 14) {
                        userCard
                        togglesCard
                        linksCard
                        advancedCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
            }
            .background(CardPalette.screen)
            .navigationBarHidden(true)
            .sheet(isPresented: $showMemory) { MemoryView() }
            .sheet(isPresented: $showPhysicsBox) { PhysicsBoxView() }
            .onAppear {
                nickname = state.settings.nickname
            }
        }
    }

    // MARK: - 顶部

    private var topBar: some View {
        HStack(spacing: 10) {
            NomiAvatar(size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Nomi")
                    .font(.nomiScaled(size: 16, weight: .semibold))
                    .foregroundColor(CardPalette.ink)

                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 0.23, green: 0.82, blue: 0.51))
                        .frame(width: 6, height: 6)
                    Text("在线 · 正在陪着你")
                        .font(.nomiScaled(size: 11.5))
                        .foregroundColor(CardPalette.subtle)
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("完成")
                    .font(.nomiScaled(size: 15, weight: .semibold))
                    .foregroundColor(CardPalette.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(CardPalette.raised)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var title: some View {
        HStack {
            Text("设置")
                .font(.nomiScaled(size: 32, weight: .bold))
                .foregroundColor(CardPalette.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: - 卡片

    private var userCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(nickname.isEmpty ? "还没起名字" : nickname)
                .font(.nomiScaled(size: 20, weight: .bold))
                .foregroundColor(CardPalette.ink)

            Text("Nomi 已了解 \(memoryCount) 条记录，全部保存在本机。")
                .font(.nomiScaled(size: 13))
                .foregroundColor(CardPalette.subtle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(cardBackground)
    }

    private var togglesCard: some View {
        VStack(spacing: 0) {
            settingToggle(icon: "speaker.wave.2.fill",
                          tint: Color(red: 0.94, green: 0.53, blue: 0.23),
                          title: "声音",
                          subtitle: "回答时朗读，使用叶子音色",
                          isOn: Binding(
                            get: { state.settings.voiceEnabled },
                            set: { newValue in
                                var value = state.settings
                                value.voiceEnabled = newValue
                                state.updateSettings(value)
                            }
                          ))

            divider

            settingToggle(icon: "bell.fill",
                          tint: Color(red: 0.23, green: 0.72, blue: 0.45),
                          title: "主动提醒",
                          subtitle: "每天最多 3 条，不抢你的事",
                          isOn: Binding(
                            get: { anyNoticeOn },
                            set: { newValue in setAllNotices(newValue) }
                          ))
        }
        .background(cardBackground)
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                PrivacyPage(state: state)
            } label: {
                settingRow(icon: "checkmark.shield.fill",
                           tint: Color(red: 0.35, green: 0.45, blue: 0.58),
                           title: "隐私与数据",
                           subtitle: "查看哪些内容会发给模型")
            }
            .buttonStyle(.plain)

            divider

            Button {
                showMemory = true
            } label: {
                settingRow(icon: "brain",
                           tint: Color(red: 0.55, green: 0.42, blue: 0.85),
                           title: "记忆",
                           subtitle: "\(memoryCount) 条，可逐条查看和删除")
            }
            .buttonStyle(.plain)

            divider

            NavigationLink {
                PermissionPage(state: state)
            } label: {
                settingRow(icon: "gearshape.2.fill",
                           tint: Color(red: 0.42, green: 0.47, blue: 0.55),
                           title: "系统权限",
                           subtitle: "相机、日历、位置和通知")
            }
            .buttonStyle(.plain)
        }
        .background(cardBackground)
    }

    private var advancedCard: some View {
        NavigationLink {
            AdvancedPage(state: state, showPhysicsBox: $showPhysicsBox)
        } label: {
            settingRow(icon: "slider.horizontal.3",
                       tint: Color(red: 0.42, green: 0.47, blue: 0.55),
                       title: "高级",
                       subtitle: "API Key、位置、提醒时间、外观")
        }
        .buttonStyle(.plain)
        .background(cardBackground)
    }

    // MARK: - 零件

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(CardPalette.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            )
    }

    private var divider: some View {
        Rectangle()
            .fill(CardPalette.line)
            .frame(height: 0.5)
            .padding(.leading, 58)
    }

    private func settingToggle(icon: String,
                               tint: Color,
                               title: String,
                               subtitle: String,
                               isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            iconTile(icon, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.nomiScaled(size: 15.5, weight: .medium))
                    .foregroundColor(CardPalette.ink)
                Text(subtitle)
                    .font(.nomiScaled(size: 12.5))
                    .foregroundColor(CardPalette.subtle)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(CardPalette.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func settingRow(icon: String,
                            tint: Color,
                            title: String,
                            subtitle: String) -> some View {
        HStack(spacing: 12) {
            iconTile(icon, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.nomiScaled(size: 15.5, weight: .medium))
                    .foregroundColor(CardPalette.ink)
                Text(subtitle)
                    .font(.nomiScaled(size: 12.5))
                    .foregroundColor(CardPalette.subtle)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.nomiScaled(size: 12.5, weight: .semibold))
                .foregroundColor(CardPalette.subtle.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func iconTile(_ symbol: String, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(tint.opacity(0.16))
            .frame(width: 30, height: 30)
            .overlay(
                Image(systemName: symbol)
                    .font(.nomiScaled(size: 14, weight: .semibold))
                    .foregroundColor(tint)
            )
    }

    // MARK: - 通知总开关

    private var anyNoticeOn: Bool {
        state.settings.rainAlertEnabled
            || state.settings.bedtimeAlertEnabled
            || state.settings.morningBriefingEnabled
            || state.settings.meetingAlertEnabled
            || state.settings.standUpEnabled
    }

    private func setAllNotices(_ on: Bool) {
        var value = state.settings
        value.rainAlertEnabled = on
        value.bedtimeAlertEnabled = on
        value.morningBriefingEnabled = on
        value.meetingAlertEnabled = on
        value.standUpEnabled = on
        state.updateSettings(value)

        if on {
            Task {
                _ = await NotificationService.requestPermission()
                await state.refresh()
            }
        }
    }
}
