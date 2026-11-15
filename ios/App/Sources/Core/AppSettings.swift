import Foundation

/// 可改的设置。存在 UserDefaults，不含任何密钥。
///
/// 自己实现解码：用 `decodeIfPresent` + 默认值。
/// 否则每加一个新字段，老用户存的 JSON 就缺这个 key，
/// 解码直接失败 → 所有设置被重置（这个坑之前踩过一次）。
struct AppSettings: Codable, Equatable {
    var cityName: String = "上海"
    var latitude: Double = 31.23
    var longitude: Double = 121.47
    var bedtimeHour: Int = 23
    var bedtimeMinute: Int = 0
    /// 用户有没有手动改过城市。改过就不再主动要定位。
    var cityWasSetByUser: Bool = false
    /// 前置摄像头跟随人脸。默认关——耗电且涉及隐私。
    var followFace: Bool = false
    /// 它说不说话。默认关——系统合成音不加处理很难听，让人主动开。
    var voiceEnabled: Bool = false
    /// 外观：跟随系统 / 浅色 / 深色
    var appearance: AppearanceMode = .dark
    /// 下雨前提醒
    var rainAlertEnabled: Bool = false
    /// 到点提醒睡觉
    var bedtimeAlertEnabled: Bool = false
    /// 每天早上报一下今天
    var morningBriefingEnabled: Bool = false
    var morningHour: Int = 7
    var morningMinute: Int = 0
    /// 会议前 10 分钟
    var meetingAlertEnabled: Bool = false
    /// 久坐提醒
    var standUpEnabled: Bool = false
    /// 关注的其他城市（问「北京天气」时用）
    var watchedCities: [WatchedCity] = []
    /// 每天想走多少步
    var stepGoal: Int = 8000
    /// 它怎么称呼你（空 = 不叫名字）
    var nickname: String = ""
    /// 用户主动填写的个人介绍，只保存在本机并用于个性化对话
    var profileNote: String = ""
    /// 起床时间，配合早报/作息判断
    var wakeHour: Int = 7
    var wakeMinute: Int = 0
    /// 锁屏时也让它受重力（用后台音频维持 App 运行，费电，默认关）
    var lockGravityEnabled: Bool = false

    var bedtime: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = bedtimeHour
        components.minute = bedtimeMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    var bedtimeText: String {
        String(format: "%02d:%02d", bedtimeHour, bedtimeMinute)
    }

    // MARK: - 兼容解码

    private enum CodingKeys: String, CodingKey {
        case cityName, latitude, longitude
        case bedtimeHour, bedtimeMinute
        case cityWasSetByUser, followFace, voiceEnabled, appearance
        case rainAlertEnabled, bedtimeAlertEnabled
        case morningBriefingEnabled, morningHour, morningMinute
        case meetingAlertEnabled, standUpEnabled
        case watchedCities
        case stepGoal
        case lockGravityEnabled
        case nickname, profileNote, wakeHour, wakeMinute
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings()

        cityName = (try? c.decodeIfPresent(String.self, forKey: .cityName)) ?? fallback.cityName
        latitude = (try? c.decodeIfPresent(Double.self, forKey: .latitude)) ?? fallback.latitude
        longitude = (try? c.decodeIfPresent(Double.self, forKey: .longitude)) ?? fallback.longitude
        bedtimeHour = (try? c.decodeIfPresent(Int.self, forKey: .bedtimeHour)) ?? fallback.bedtimeHour
        bedtimeMinute = (try? c.decodeIfPresent(Int.self, forKey: .bedtimeMinute)) ?? fallback.bedtimeMinute
        cityWasSetByUser = (try? c.decodeIfPresent(Bool.self, forKey: .cityWasSetByUser)) ?? fallback.cityWasSetByUser
        followFace = (try? c.decodeIfPresent(Bool.self, forKey: .followFace)) ?? fallback.followFace

        voiceEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .voiceEnabled)) ?? fallback.voiceEnabled
        appearance = (try? c.decodeIfPresent(AppearanceMode.self, forKey: .appearance)) ?? fallback.appearance
        rainAlertEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .rainAlertEnabled)) ?? fallback.rainAlertEnabled
        bedtimeAlertEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .bedtimeAlertEnabled)) ?? fallback.bedtimeAlertEnabled
        morningBriefingEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .morningBriefingEnabled)) ?? fallback.morningBriefingEnabled
        morningHour = (try? c.decodeIfPresent(Int.self, forKey: .morningHour)) ?? fallback.morningHour
        morningMinute = (try? c.decodeIfPresent(Int.self, forKey: .morningMinute)) ?? fallback.morningMinute
        meetingAlertEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .meetingAlertEnabled)) ?? fallback.meetingAlertEnabled
        standUpEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .standUpEnabled)) ?? fallback.standUpEnabled
        watchedCities = (try? c.decodeIfPresent([WatchedCity].self, forKey: .watchedCities)) ?? fallback.watchedCities
        stepGoal = (try? c.decodeIfPresent(Int.self, forKey: .stepGoal)) ?? fallback.stepGoal
        lockGravityEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .lockGravityEnabled)) ?? fallback.lockGravityEnabled
        nickname = (try? c.decodeIfPresent(String.self, forKey: .nickname)) ?? fallback.nickname
        profileNote = (try? c.decodeIfPresent(String.self, forKey: .profileNote)) ?? fallback.profileNote
        wakeHour = (try? c.decodeIfPresent(Int.self, forKey: .wakeHour)) ?? fallback.wakeHour
        wakeMinute = (try? c.decodeIfPresent(Int.self, forKey: .wakeMinute)) ?? fallback.wakeMinute
    }
}

enum AppSettingsStore {
    private static let key = "jinri.settings"
    /// 一次性迁移标记：老版本默认开着声音，这里强制关掉一次
    private static let voiceMigrationKey = "jinri.voiceOff.v2"
    /// 鲸鱼 UI v9 首次启动进入深海主题，之后尊重用户选择
    private static let whaleThemeMigrationKey = "jinri.whaleTheme.v9"

    static func load() -> AppSettings {
        var value = AppSettings()
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            value = decoded
        }

        // 老版本默认 true，用户被吓过一次；这里只迁移一次，之后尊重用户的选择
        if !UserDefaults.standard.bool(forKey: voiceMigrationKey) {
            value.voiceEnabled = false
            save(value)
            UserDefaults.standard.set(true, forKey: voiceMigrationKey)
        }

        if !UserDefaults.standard.bool(forKey: whaleThemeMigrationKey) {
            value.appearance = .dark
            save(value)
            UserDefaults.standard.set(true, forKey: whaleThemeMigrationKey)
        }

        return value
    }

    static func save(_ value: AppSettings) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
