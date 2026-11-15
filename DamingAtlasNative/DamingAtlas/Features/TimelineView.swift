import SwiftUI

struct TimelineView: View {
    @Environment(ContentRepository.self) private var content

    var body: some View {
        List {
            Section("五幕 · 二十章") {
                ForEach(content.bundle.chapters) { chapter in
                    NavigationLink(value: AppRoute.chapter(chapter.no)) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(chapter.volume).font(.caption).foregroundStyle(DamingTheme.accent)
                            Text(chapter.title).font(.headline)
                            Text("\(chapter.years) · 主导线：\(chapter.thread)")
                                .font(.caption)
                                .foregroundStyle(DamingTheme.secondary)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .navigationTitle("王朝时序")
    }
}

struct ChapterDetailView: View {
    @Environment(ContentRepository.self) private var content
    let chapterNumber: Int

    private var chapter: Chapter? { content.chaptersByNumber[chapterNumber] }
    private var events: [HistoryEvent] {
        (chapter?.eventIds ?? []).compactMap { content.eventsByID[$0] }
    }

    var body: some View {
        ScrollView {
            if let chapter {
                VStack(alignment: .leading, spacing: 16) {
                    Text(chapter.volume).font(.caption).foregroundStyle(DamingTheme.accent)
                    Text(chapter.title).font(.system(size: 28, weight: .bold, design: .serif))
                    Text(chapter.intro).font(.body).foregroundStyle(DamingTheme.secondary)
                    ForEach(events) { event in
                        NavigationLink(value: AppRoute.event(event.id)) {
                            DamingCard {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(event.time.display).font(.caption).foregroundStyle(DamingTheme.accent)
                                    Text(event.title).font(.headline)
                                    Text("\(event.cat) · \(event.place)").font(.caption).foregroundStyle(DamingTheme.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(chapter?.title ?? "章节")
        .navigationBarTitleDisplayMode(.inline)
    }
}
