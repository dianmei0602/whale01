import SwiftUI
import UIKit

/// The conversation starter. Tapping 对话 lands here: a real chat surface with
/// a rotating daily note, immediate prompts and the state the phone actually has.
@MainActor
struct WhaleHomeCanvas: View {
    @ObservedObject var model: AppModel
    let bottomInset: CGFloat
    let onOpenRecords: () -> Void
    let onOpenMusic: () -> Void
    let onOpenTodo: () -> Void
    let onOpenDiscover: (DiscoverChannel) -> Void
    let onOpenConversation: () -> Void
    @State private var weatherDays: [WeatherDaySummary] = []
    @State private var weather: WeatherSnapshot?
    @State private var weatherLocation = ""
    @State private var weatherLoading = false
    @State private var weatherError: String?
    @State private var weatherStartedAt: Date?
    @State private var weatherFetchedAt: Date?
    @AppStorage("whale.home.showQuote") private var showQuote = true
    @State private var quoteExpanded = false
    @State private var showWeatherDetail = false
    @State private var homeTodos: [TodoReminder] = []
    @StateObject private var digest = HomeDigestModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var weatherExpanded = ProcessInfo.processInfo.environment["WHALE_DEMO_WEATHER"] == "1"
    @State private var manualCity = UserDefaults.standard.string(forKey: "home.weather.city") ?? ""

    private static let weatherCacheKey = "home-weather-v1"
    private static let weatherRefreshInterval: TimeInterval = 8 * 60 * 60

    private struct CachedWeather: Codable {
        let fetchedAt: Date
        let payload: JSONValue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if showQuote { dailyQuote }
                todayCard
                categoryGrid
            }.frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, WhaleTheme.pagePadding).padding(.top, 12).padding(.bottom, 24)
        }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
            .background(WhaleBackdrop())
            .task {
                await loadWeatherIfNeeded()
                await loadHomeTodos()
                await model.refreshDashboard()
                await digest.prime()
            }
            .onChange(of: model.permissionsSnapshot) { _, _ in Task { await loadWeatherIfNeeded(); await loadHomeTodos() } }
            .sheet(isPresented: $showWeatherDetail) {
                NavigationStack {
                    ScrollView { weatherCard.padding(20) }.background(WhaleTheme.background)
                        .navigationTitle("天气详情").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { showWeatherDetail = false } } }
                }
            }
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("常用操作")
                .whaleFont(size: 15, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 8, alignment: .top),
                    count: textSize.isAccessibilitySize ? 1 : 2
                ),
                spacing: 8
            ) {
                ForEach(Array(DiscoverChannel.allCases.enumerated()), id: \.element) { offset, channel in
                    Button {
                        if channel == .music { onOpenMusic() }
                        else { onOpenDiscover(channel) }
                    } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 7) {
                                Image(systemName: channel.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(channel.title)
                                    .whaleFont(size: 14, weight: .semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.84)
                                Spacer(minLength: 2)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(channel.entryInk.opacity(0.72))
                            }
                            RollingSummaryText(
                                lines: summaryLines(for: channel),
                                delay: Double(offset) * 0.55,
                                maxLines: 1,
                                fontSize: 12,
                                foreground: channel.entryInk
                            )
                        }
                        .foregroundStyle(channel.entryInk)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
                        .background(
                            channel.homeCardBackground,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(channel.entryInk.opacity(0.10), lineWidth: 0.6)
                        }
                    }
                    .buttonStyle(.whalePress)
                    .accessibilityLabel(channel.title)
                        .accessibilityIdentifier("home-channel-" + channel.rawValue)
                }
            }
        }
    }

    private func summaryLines(for channel: DiscoverChannel) -> [String] {
        if channel == .music { return musicSummaryLines }
        let live = digest.lines[channel] ?? []
        return live.isEmpty ? [channel.subtitle] : live
    }

    private var musicSummaryLines: [String] {
        if let track = model.playback.track {
            let state = model.playback.state == "playing" ? "正在播放" : "已暂停"
            var rows = ["\(state) · \(track.title) — \(track.artist)"]
            if !model.musicTracks.isEmpty {
                rows.append("曲库 \(model.musicTracks.count) 首 · \(model.musicPlayMode.title)")
            }
            return rows
        }
        return ["系统资料库 · 本地音乐", "点按进入播放控制"]
    }
    private var todayWeather: some View {
        Button {
            if locationStatus == "granted", weatherDays.isEmpty, !weatherLoading {
                Task { await loadWeather(force: true) }
            } else {
                weatherExpanded = true; showWeatherDetail = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: weatherDays.first?.icon ?? "cloud.sun")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(WhaleTheme.accent)
                Text(compactWeatherText)
                    .lineLimit(1)
            }
            .whaleFont(size: 12, weight: .regular)
            .foregroundStyle(WhaleTheme.muted)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-today-weather")
            .accessibilityHint("查看天气详情；天气未获取时重新查询")
    }

    private var compactWeatherText: String {
        if weatherLoading && weatherDays.isEmpty { return "天气查询中" }
        if weatherError != nil && weatherDays.isEmpty { return "天气获取失败" }
        guard let day = weatherDays.first else {
            return locationStatus == "granted" ? "刷新天气" : "查看天气"
        }
        let place = weatherLocation.isEmpty ? "当前位置" : weatherLocation
        return "\(place) \(currentTemperatureText) \(weather?.current?.summary ?? day.summary)"
    }
    private var dailyQuote: some View {
        TimelineView(.periodic(from: Date(), by: 60)) { context in
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { quoteExpanded.toggle() }
            } label: {
                let quote = DailyQuote.item(at: context.date)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text("每日一句")
                            .whaleFont(size: 12, weight: .medium)
                        Spacer(minLength: 8)
                        Text(context.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(WhaleTheme.muted)
                    }
                    .foregroundStyle(WhaleTheme.muted)

                    Text(quote.text)
                        .whaleFont(size: 18, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                        .lineSpacing(4)
                        .lineLimit(quoteExpanded || textSize.isAccessibilitySize ? nil : 3)

                    Text(quote.source)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WhaleTheme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .whaleCard(padding: 16)
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.whalePress)
                .accessibilityIdentifier("home-inspiration-card")
                .accessibilityHint("点击展开每日一句")
                .contextMenu { Button("隐藏今日一句") { showQuote = false } }
        }
    }
    private func loadHomeTodos() async {
        guard model.permissionsSnapshot["reminder"] == "granted" else { homeTodos = []; return }
        homeTodos = (try? await model.loadTodoReminders(includeCompleted: false)) ?? homeTodos
    }

    // MARK: - Weather

    private var locationStatus: String {
        model.permissionsSnapshot["location"] ?? "unknown"
    }

    private var weatherCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            if let today = weatherDays.first {
                weatherSummary(today)
                if locationStatus != "granted" {
                    Label("定位未开启 · 显示上次位置 \(weatherLocation)", systemImage: "mappin.slash")
                        .whaleFont(size: 12, weight: .medium)
                        .foregroundStyle(WhaleTheme.muted)
                }
            } else if let weatherError {
                VStack(alignment: .leading, spacing: 7) {
                    Text("暂时没有取得天气数据")
                        .whaleFont(size: 16, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                    Text(weatherError)
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Button("重新查询") {
                            Task { await loadWeather(force: true) }
                        }
                        .whaleFont(size: 14, weight: .semibold)
                        .foregroundStyle(WhaleTheme.accent)
                        .buttonStyle(.plain)
                        if locationStatus == "denied" {
                            Button("去系统设置") { model.openSystemSettings() }
                                .whaleFont(size: 14, weight: .medium)
                                .foregroundStyle(WhaleTheme.muted)
                                .buttonStyle(.plain)
                        }
                    }
                }
                manualCityEntry
            } else if locationStatus == "granted" || weatherLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(WhaleTheme.accent)
                    Text("正在读取所在地天气…")
                        .whaleFont(size: 14)
                        .foregroundStyle(WhaleTheme.muted)
                    Spacer(minLength: 0)
                }
                .frame(height: 48)
            } else {
                locationPermissionPrompt
                manualCityEntry
            }
        }
        .whaleCard(padding: 18)
    }

    private func weatherSummary(_ today: WeatherDaySummary) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { weatherExpanded.toggle() }
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: today.icon)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(WhaleTheme.coral, WhaleTheme.moon)
                        .whaleFont(size: 31, weight: .medium)
                        .frame(width: 52, height: 52)
                        .background(WhaleTheme.coral.opacity(0.09), in: RoundedRectangle(cornerRadius: 17, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(weather?.current?.summary ?? today.summary)
                                .whaleFont(size: 20, weight: .bold, design: .rounded)
                                .foregroundStyle(WhaleTheme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Spacer(minLength: 0)
                            Text(currentTemperatureText)
                                .whaleFont(size: 34, weight: .bold, design: .rounded)
                                .foregroundStyle(WhaleTheme.ink)
                        }
                        Text(weatherMetaLine(today))
                            .whaleFont(size: 13, weight: .medium)
                            .foregroundStyle(WhaleTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 4)

                    if weatherLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(WhaleTheme.accent)
                    } else {
                        Image(systemName: weatherExpanded ? "chevron.up" : "chevron.down")
                            .whaleFont(size: 13, weight: .bold)
                            .foregroundStyle(WhaleTheme.muted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("天气详情")

            if !weatherExpanded, let current = weather?.current {
                weatherQuickStats(current)
            }

            if weatherExpanded {
                if let hours = weather?.hours, !hours.isEmpty {
                    Rectangle()
                        .fill(WhaleTheme.line)
                        .frame(height: 0.5)
                    hourlyStrip(hours)
                }

                if let sun = weather?.sun {
                    HStack(spacing: 18) {
                        Label("日出 \(sun.sunriseText)", systemImage: "sunrise.fill")
                        Label("日落 \(sun.sunsetText)", systemImage: "sunset.fill")
                        Spacer(minLength: 0)
                    }
                    .whaleFont(size: 13, weight: .medium)
                    .foregroundStyle(WhaleTheme.muted)
                }

                if let current = weather?.current, !weatherDays.isEmpty {
                    Rectangle()
                        .fill(WhaleTheme.line)
                        .frame(height: 0.5)
                    metricsGrid(current, today: today)
                }

                HStack(spacing: 5) {
                    Text("Open-Meteo · 真实预报")
                        .whaleFont(size: 13, weight: .medium)
                        .foregroundStyle(WhaleTheme.muted.opacity(0.75))
                    Spacer()
                    Button {
                        Task { await loadWeather(force: true) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("刷新")
                        }
                    }
                    .whaleFont(size: 13, weight: .semibold)
                    .foregroundStyle(WhaleTheme.accent)
                    .buttonStyle(.plain)
                    .accessibilityLabel("刷新天气")
                }
            }
        }
    }

    private var locationPermissionPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .whaleFont(size: 28, weight: .medium)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(WhaleTheme.coral, WhaleTheme.coral.opacity(0.12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(locationStatus == "denied" ? "定位权限未开启" : "查看真实天气")
                        .whaleFont(size: 17, weight: .semibold)
                        .foregroundStyle(WhaleTheme.ink)
                    Text("可以开启定位，也可以直接输入城市名查询。")
                        .whaleFont(size: 13)
                        .foregroundStyle(WhaleTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
            }

            Button(locationStatus == "denied" ? "去系统设置开启定位" : "使用当前位置") {
                if locationStatus == "denied" {
                    model.openSystemSettings()
                } else {
                    Task {
                        await model.requestPermission("location")
                        if model.permissionsSnapshot["location"] == "granted" {
                            await loadWeather(force: true)
                        }
                    }
                }
            }
            .whaleFont(size: 14, weight: .semibold)
            .foregroundStyle(WhaleTheme.accent)
            .buttonStyle(.plain)
        }
    }

    private var manualCityEntry: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.2")
                .foregroundStyle(WhaleTheme.muted)
            TextField("输入城市，如 杭州 / 北京", text: $manualCity)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { queryManualCity() }
                .accessibilityIdentifier("weather-manual-city")
            Button("查询") { queryManualCity() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(trimmedManualCity.isEmpty ? WhaleTheme.muted : WhaleTheme.accent)
                .disabled(trimmedManualCity.isEmpty)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(WhaleTheme.soft.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var trimmedManualCity: String {
        manualCity.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func queryManualCity() {
        let city = trimmedManualCity
        guard !city.isEmpty else { return }
        UserDefaults.standard.set(city, forKey: "home.weather.city")
        Task { await loadWeather(force: true, city: city) }
    }

    private var currentTemperatureText: String {
        if let value = weather?.current?.temperatureC {
            return "\(Int(value.rounded()))°"
        }
        return weatherDays.first?.temperatureText ?? "—"
    }

    private func weatherMetaLine(_ today: WeatherDaySummary) -> String {
        var parts = [weatherLocation.isEmpty ? "当前位置" : weatherLocation, today.temperatureText]
        if let rain = today.precipitationText {
            parts.append(rain)
        }
        return parts.joined(separator: " · ")
    }

    private func weatherQuickStats(_ current: WeatherSnapshot.Current) -> some View {
        HStack(spacing: 10) {
            weatherQuickStat(
                "体感",
                current.apparentC.map { "\(Int($0.rounded()))°" } ?? "—",
                icon: "thermometer.medium"
            )
            weatherQuickStat(
                "湿度",
                current.humidity.map { "\(Int($0.rounded()))%" } ?? "—",
                icon: "humidity.fill"
            )
            weatherQuickStat(
                "风速",
                current.windKph.map { String(format: "%.0f km/h", $0) } ?? "—",
                icon: "wind"
            )
        }
        .padding(10)
        .background(WhaleTheme.soft.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.snappy(duration: 0.2)) { weatherExpanded.toggle() }
        }
    }

    private func weatherQuickStat(_ label: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .whaleFont(size: 13, weight: .semibold)
                Text(label)
                    .whaleFont(size: 13, weight: .medium)
            }
            .foregroundStyle(WhaleTheme.muted)
            Text(value)
                .whaleFont(size: 15, weight: .semibold, design: .rounded)
                .foregroundStyle(WhaleTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hourlyStrip(_ hours: [WeatherSnapshot.Hour]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("逐小时预报")
                .whaleFont(size: 14, weight: .semibold)
                .foregroundStyle(WhaleTheme.muted)
            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    ForEach(hours) { hour in
                        VStack(spacing: 5) {
                            Text(hour.hourLabel)
                                .whaleFont(size: 13, weight: .medium)
                                .foregroundStyle(WhaleTheme.muted)
                            Image(systemName: hour.icon)
                                .whaleFont(size: 17, weight: .medium)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(hour.isDay ? WhaleTheme.coral : WhaleTheme.moon, WhaleTheme.moon.opacity(0.5))
                            Text(hour.temperatureC.map { "\(Int($0.rounded()))°" } ?? "—")
                                .whaleFont(size: 15, weight: .bold, design: .rounded)
                                .foregroundStyle(WhaleTheme.ink)
                            Text(hour.precipitationChance.map { "\(Int($0.rounded()))%" } ?? " ")
                                .whaleFont(size: 13, weight: .medium)
                                .foregroundStyle(WhaleTheme.moon)
                        }
                        .frame(width: 42)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func metricsGrid(_ current: WeatherSnapshot.Current, today: WeatherDaySummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricCell("体感", current.apparentC.map { "\(Int($0.rounded()))°" } ?? "—", "thermometer.medium")
            metricCell("湿度", current.humidity.map { "\(Int($0.rounded()))%" } ?? "—", "humidity.fill")
            metricCell("风速", current.windKph.map { String(format: "%.0f km/h", $0) } ?? "—", "wind")
            metricCell("降水概率", today.precipitationText?.replacingOccurrences(of: "降水 ", with: "") ?? "—", "drop.fill")
            metricCell("紫外线", today.uvIndexText ?? "—", "sun.max.fill")
            metricCell("空气质量", weather?.air.map { "\($0.aqiText) \($0.levelText)" } ?? "—", "aqi.medium")
        }
    }

    private func metricCell(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .whaleFont(size: 13, weight: .semibold)
                Text(label)
                    .whaleFont(size: 13, weight: .medium)
            }
            .foregroundStyle(WhaleTheme.muted)
            Text(value)
                .whaleFont(size: 16, weight: .semibold, design: .rounded)
                .foregroundStyle(WhaleTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(WhaleTheme.soft.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func loadWeatherIfNeeded() async {
        // Cached data always renders first: a missing location permission must
        // not blank the card the user already saw.
        restoreCachedWeatherIfNeeded()
        if weatherCacheIsFresh { return }
        if weatherLoading, weatherLoadIsStale { weatherLoading = false }
        guard !weatherLoading else { return }
        if locationStatus == "granted" {
            await loadWeather(force: false)
        } else if !trimmedManualCity.isEmpty {
            await loadWeather(force: false, city: trimmedManualCity)
        }
    }

    /// Rehydrates the last successful payload so a cold launch renders instantly.
    /// The cache lives in Caches and is safe to delete at any time.
    private func restoreCachedWeatherIfNeeded() {
        guard weatherDays.isEmpty else { return }
        guard let cached = DiscoverDiskCache.load(CachedWeather.self, key: Self.weatherCacheKey) else { return }
        applyWeather(cached.payload, fetchedAt: cached.fetchedAt)
    }

    private func applyWeather(_ data: JSONValue, fetchedAt: Date) {
        let days = WeatherDaySummary.list(from: data)
        guard !days.isEmpty else { return }
        weatherDays = days
        weather = WeatherSnapshot.from(data)
        weatherLocation = data.objectValue?.optionalString("locationName") ?? "当前位置"
        weatherFetchedAt = fetchedAt
        weatherError = nil
    }

    /// Fresh means: fetched less than 8 hours ago and the forecast still starts today.
    private var weatherCacheIsFresh: Bool {
        guard !weatherDays.isEmpty, let fetchedAt = weatherFetchedAt else { return false }
        guard Date().timeIntervalSince(fetchedAt) < Self.weatherRefreshInterval else { return false }
        return weatherDays.first?.date == Self.dayKey(Date())
    }

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private var weatherLoadIsStale: Bool {
        guard let started = weatherStartedAt else { return true }
        return Date().timeIntervalSince(started) > 20
    }

    private func loadWeather(force: Bool, city: String? = nil) async {
        let fallbackCity: String? = locationStatus == "granted" ? nil : trimmedManualCity
        let requested = (city ?? fallbackCity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requested.isEmpty || locationStatus == "granted" else {
            weatherLoading = false
            weatherError = "没有定位权限。输入城市名也能查询真实天气，或在系统设置中开启定位。"
            return
        }
        if weatherLoading {
            guard weatherLoadIsStale else { return }
            weatherLoading = false
        }
        if !force, weatherCacheIsFresh { return }
        weatherLoading = true
        weatherError = nil
        let startedAt = Date()
        weatherStartedAt = startedAt
        let watchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 18_000_000_000)
            guard !Task.isCancelled, weatherLoading, weatherStartedAt == startedAt else { return }
            weatherLoading = false
            weatherStartedAt = nil
            if weatherDays.isEmpty {
                weatherError = "天气查询超时，请点按刷新天气重试。"
            }
        }
        defer {
            watchdog.cancel()
            weatherLoading = false
            weatherStartedAt = nil
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start.addingTimeInterval(518_400)
        do {
            var arguments: [String: JSONValue] = [
                "startAt": .string(ToolDate.iso(start)),
                "endAt": .string(ToolDate.iso(end)),
                "timezone": .string(TimeZone.current.identifier)
            ]
            if !requested.isEmpty { arguments["locationName"] = .string(requested) }
            let data = try await WeatherExecutor().query(arguments: arguments)
            let days = WeatherDaySummary.list(from: data)
            guard !days.isEmpty else {
                weatherError = "天气接口本次没有返回逐日预报，请稍后重试。"
                return
            }
            let fetchedAt = Date()
            applyWeather(data, fetchedAt: fetchedAt)
            DiscoverDiskCache.save(CachedWeather(fetchedAt: fetchedAt, payload: data), key: Self.weatherCacheKey)
        } catch {
            if weatherDays.isEmpty {
                weatherError = error.localizedDescription
            }
        }
    }

    // MARK: - Real calendar

    private var todayCard: some View {
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 7))

        return layout {
            Text("今天 · \(todayLabel)")
                .whaleFont(size: 12, weight: .semibold)
                .foregroundStyle(WhaleTheme.ink)
                .fixedSize(horizontal: true, vertical: false)

            Text("·")
                .font(.system(size: 12))
                .foregroundStyle(WhaleTheme.line)

            todayWeather

            Text("·")
                .font(.system(size: 12))
                .foregroundStyle(WhaleTheme.line)

            Button(action: onOpenTodo) {
                HStack(spacing: 4) {
                    Text(compactAgendaText)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                }
                .whaleFont(size: 12)
                .foregroundStyle(WhaleTheme.muted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !textSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-today-card")
    }

    private var compactAgendaText: String {
        if let event = todayEvents.first(where: { $0.endAt > Date() }) {
            return "\(event.startAt.formatted(date: .omitted, time: .shortened)) \(event.title)"
        }
        if let todo = homeTodos.first(where: { !$0.completed }) {
            return todo.title
        }
        if !calendarGranted {
            return "连接日历查看安排"
        }
        if let error = model.dashboardError, !error.isEmpty {
            return error
        }
        return "暂无安排"
    }

    private func eventRow(_ event: CalendarEventPreview) -> some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 4) {
                Text(event.startAt.formatted(date: .omitted, time: .shortened))
                    .whaleFont(size: 13, weight: .semibold, design: .rounded)
                    .foregroundStyle(WhaleTheme.muted)
                Circle()
                    .fill(WhaleTheme.accent)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .whaleFont(size: 14, weight: .semibold)
                    .foregroundStyle(WhaleTheme.ink)
                    .lineLimit(2)
                Text(event.calendarTitle)
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
            }
            Spacer(minLength: 4)
        }
        .padding(.vertical, 3)
    }

    private var calendarGranted: Bool {
        model.permissionsSnapshot["calendarRead"] == "granted"
    }

    private var todayEvents: [CalendarEventPreview] {
        model.upcomingEvents
            .filter { Calendar.current.isDateInToday($0.startAt) && $0.endAt > Date() }
            .sorted { $0.startAt < $1.startAt }
    }

    private var todayTitle: String {
        if todayEvents.isEmpty { return "今天暂无安排" }
        return "今天还剩 \(todayEvents.count) 件事"
    }

    private var todayStatusText: String {
        if todayEvents.isEmpty { return "无日程" }
        return "\(todayEvents.count) 件"
    }

    private var todayLabel: String {
        Date().formatted(.dateTime.month().day().weekday(.abbreviated))
    }

    private var nextEventText: String {
        guard let next = model.upcomingEvents.sorted(by: { $0.startAt < $1.startAt }).first else {
            return "接下来 7 天也没有安排。"
        }
        return "下一项：\(next.startAt.formatted(.dateTime.month().day().hour().minute())) · \(next.title)"
    }

    // MARK: - Busy

    private var busyCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(WhaleTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("鲸鱼正在处理")
                    .whaleFont(size: 13, weight: .semibold)
                    .foregroundStyle(WhaleTheme.ink)
                Text(model.statusLine)
                    .whaleFont(size: 13)
                    .foregroundStyle(WhaleTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .whaleCard(padding: 14)
    }

    private func send(_ text: String) {
        dismissKeyboard()
        Task { await model.send(text: text) }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
