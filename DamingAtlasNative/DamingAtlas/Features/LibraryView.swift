import SwiftUI

struct LibraryView: View {
    @Environment(ContentRepository.self) private var content
    @State private var mode = 0

    var body: some View {
        List {
            Picker("典籍分类", selection: $mode) {
                Text("奏疏").tag(0)
                Text("文献").tag(1)
                Text("长文").tag(2)
                Text("出处").tag(3)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if mode == 0 {
                Section("奏疏与原文状态") {
                    ForEach(content.bundle.memorials) { item in
                        NavigationLink(value: AppRoute.memorial(item.id)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title).font(.headline)
                                Text(item.note).font(.caption).foregroundStyle(DamingTheme.secondary)
                                Text(item.status).font(.caption2).foregroundStyle(DamingTheme.accent)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            } else if mode == 1 {
                Section("明代重要文献") {
                    ForEach(content.bundle.works) { work in
                        NavigationLink(value: AppRoute.work(work.id)) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(work.title).font(.headline)
                                Text("\(work.author) · \(work.period)")
                                    .font(.caption)
                                    .foregroundStyle(DamingTheme.secondary)
                                Text(work.category).font(.caption2).foregroundStyle(DamingTheme.accent)
                            }
                        }
                    }
                }
            } else if mode == 2 {
                Section("三线长文") {
                    ForEach(content.bundle.editorial.threads) { thread in
                        DamingCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(thread.name).font(.headline)
                                Text(thread.logic).lineLimit(5).foregroundStyle(DamingTheme.secondary)
                            }
                        }
                    }
                }
            } else {
                Section("史料书目") {
                    ForEach(content.bundle.sources) { source in
                        NavigationLink(value: AppRoute.source(source.id)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.title).font(.headline)
                                Text("\(source.author) · \(source.citationStatus)")
                                    .font(.caption)
                                    .foregroundStyle(DamingTheme.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("典籍")
    }
}

struct MemorialDetailView: View {
    @Environment(ContentRepository.self) private var content
    let memorialID: String

    var body: some View {
        if let item = content.memorialsByID[memorialID] {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(item.title).font(.system(size: 28, weight: .bold, design: .serif))
                    Text("\(item.year) · \(item.status)").foregroundStyle(DamingTheme.secondary)
                    if !item.excerpt.isEmpty {
                        Text(item.excerpt)
                            .font(.system(.title3, design: .serif))
                            .padding()
                            .background(DamingTheme.raised)
                    }
                    Text(item.note).foregroundStyle(DamingTheme.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ReferenceWorkDetailView: View {
    @Environment(ContentRepository.self) private var content
    let workID: String

    var body: some View {
        if let work = content.worksByID[workID] {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("明代文献 · \(work.category)").font(.caption).foregroundStyle(DamingTheme.accent)
                    Text(work.title).font(.system(size: 28, weight: .bold, design: .serif))
                    Text("\(work.author) · \(work.period)").foregroundStyle(DamingTheme.secondary)
                    Text(work.summary).font(.system(.body, design: .serif)).lineSpacing(8)
                    DamingCard {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("使用边界").font(.headline)
                            Text(work.note).font(.caption).foregroundStyle(DamingTheme.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(work.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SourceDetailView: View {
    @Environment(ContentRepository.self) private var content
    let sourceID: String

    var body: some View {
        if let source = content.sourcesByID[sourceID] {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(source.title).font(.system(size: 28, weight: .bold, design: .serif))
                    Text(source.author).foregroundStyle(DamingTheme.secondary)
                    Text(source.note)
                    Text("校订状态：\(source.citationStatus)").font(.caption).foregroundStyle(DamingTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(source.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ChoiceView: View {
    var body: some View {
        ContentUnavailableView(
            "甲申抉择",
            systemImage: "seal",
            description: Text("HTML 原型的四问流程已保留；原生版在内容路由稳定后接入逐项史料回放。")
        )
        .navigationTitle("甲申")
    }
}
