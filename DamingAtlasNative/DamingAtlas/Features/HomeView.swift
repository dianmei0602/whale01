import SwiftUI

struct HomeView: View {
    @Environment(ContentRepository.self) private var content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("卷首").font(.system(size: 28, weight: .bold, design: .serif))
                Text("洪武元年 — 崇祯十七年 · 五幕长卷").foregroundStyle(DamingTheme.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("不是百科全书，\n是一部能走进去的王朝。")
                        .font(.system(size: 25, weight: .bold, design: .serif))
                    Text("每幕以危机开场，以代价收尾。")
                        .foregroundStyle(.white.opacity(0.86))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(DamingTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                HStack {
                    metric("\(content.bundle.meta.people)", "人物")
                    Divider()
                    metric("\(content.bundle.meta.events)", "事件")
                    Divider()
                    metric("\(content.bundle.meta.chapters)", "章节")
                }
                .padding(.vertical, 14)

                sectionTitle("三线长卷")
                ForEach(content.bundle.editorial.threads) { thread in
                    DamingCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(thread.name).font(.headline)
                            Text(thread.logic).lineLimit(4).foregroundStyle(DamingTheme.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                NavigationLink(value: AppRoute.chapter(content.bundle.chapters.first?.no ?? 1)) {
                    Label("进入时序", systemImage: "clock")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.white)
                        .background(DamingTheme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
        }
        .background(DamingTheme.ground)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(DamingTheme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.headline).padding(.top, 4)
    }
}
