import SwiftUI
import Foundation

/// 聊天里的天气卡：大字温度 + 明细 + 温度趋势 + 三天。
struct WeatherCardView: View {
    let weather: Weather
    let city: String
    let pm25: Double?
    var onTap: () -> Void

    private let cyan = CardPalette.accent

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                header
                mainBlock
                placeRow
                trend
                divider
                threeDays
            }
            .padding(14)
            .background(
                ZStack {
                    CardPalette.surface
                    LinearGradient(
                        colors: [cyan.opacity(0.10), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.leading, 8)
    }

    // MARK: - 头

    private var header: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(cyan.opacity(0.14))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: WeatherCode.symbol(weather.weatherCode))
                        .font(.nomiScaled(size: 16, weight: .medium))
                        .foregroundColor(cyan)
                )

            Text("天气")
                .font(.nomiScaled(size: 17, weight: .semibold))
                .foregroundColor(CardPalette.ink)

            Spacer()

            Text("3-DAY · LIVE")
                .font(.nomiScaled(size: 11, weight: .medium))
                .foregroundColor(CardPalette.subtle)
                .tracking(0.6)
        }
        .padding(.bottom, 12)
    }

    // MARK: - 主块

    private var mainBlock: some View {
        HStack(alignment: .top, spacing: 16) {
            HStack(alignment: .top, spacing: 2) {
                Text("\(Int(weather.currentTemperature.rounded()))")
                    .font(.nomiScaled(size: 53.5, weight: .bold))
                    .foregroundColor(CardPalette.ink)
                    .tracking(-2)
                Text("°")
                    .font(.nomiScaled(size: 25.5, weight: .medium))
                    .foregroundColor(cyan)
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(WeatherCode.text(weather.weatherCode))
                    .font(.nomiScaled(size: 17.5, weight: .semibold))
                    .foregroundColor(CardPalette.ink)
                    .padding(.top, 8)

                Text("最高 \(Int(weather.todayMax.rounded()))° · 最低 \(Int(weather.todayMin.rounded()))°")
                    .font(.nomiScaled(size: 13.5))
                    .foregroundColor(CardPalette.subtle)

                Text(detailLine)
                    .font(.nomiScaled(size: 13))
                    .foregroundColor(CardPalette.subtle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("穿衣：" + clothingLine)
                    .font(.nomiScaled(size: 12.5))
                    .foregroundColor(CardPalette.subtle)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }

            Spacer(minLength: 0)
        }
    }

    /// 穿衣建议：最高最低温 + 未来 6 小时雨雪 + 风
    private var clothingLine: String {
        let now = Date()
        let rainChance = weather.hours
            .filter { $0.time > now && $0.time.timeIntervalSince(now) < 6 * 3600 }
            .map { $0.precipitationProbability }
            .max() ?? 0

        return ClothingAdvice.advice(maxTemp: weather.todayMax,
                                     minTemp: weather.todayMin,
                                     weatherCode: weather.weatherCode,
                                     rainChance: rainChance,
                                     windKmh: weather.windSpeed)
    }

    private var detailLine: String {
        var parts: [String] = []
        parts.append("体感 \(Int(weather.feelsLike.rounded()))°")
        parts.append("湿度 \(Int(weather.humidity.rounded()))%")
        if let pm = pm25 {
            parts.append("PM2.5 \(Int(pm.rounded()))")
        }
        if let today = weather.days.first {
            let delta = today.max - today.min
            parts.append("温差 \(Int(delta.rounded()))°")
        }
        return parts.joined(separator: " · ")
    }

    private var placeRow: some View {
        HStack(spacing: 5) {
            Image(systemName: "mappin.and.ellipse")
                .font(.nomiScaled(size: 11.5))
            Text(city)
                .font(.nomiScaled(size: 13.5))
            Text("·")
                .font(.nomiScaled(size: 13.5))
            Text("\(WeatherCode.windDirection(weather.windDirection)) \(WeatherCode.windLevel(weather.windSpeed))")
                .font(.nomiScaled(size: 13.5))
            Spacer(minLength: 0)
        }
        .foregroundColor(CardPalette.subtle)
        .padding(.top, 12)
    }

    // MARK: - 温度趋势

    private var trend: some View {
        GeometryReader { geo in
            let values = weather.days.prefix(3).map { $0.max }
            let maxValue = (values.max() ?? 1) + 1
            let minValue = (values.min() ?? 0) - 1
            let span = max(1, maxValue - minValue)

            Path { path in
                for (index, value) in values.enumerated() {
                    let x = geo.size.width * (CGFloat(index) + 0.5) / CGFloat(max(1, values.count))
                    let y = geo.size.height * (1 - (value - minValue) / span)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(colors: [cyan.opacity(0.2), cyan],
                               startPoint: .leading,
                               endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: 34)
        .padding(.top, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(CardPalette.line)
            .frame(height: 1)
            .padding(.top, 4)
    }

    // MARK: - 三天

    private var threeDays: some View {
        HStack(spacing: 0) {
            ForEach(Array(weather.days.prefix(3).enumerated()), id: \.offset) { index, day in
                VStack(spacing: 5) {
                    Image(systemName: WeatherCode.symbol(day.code))
                        .font(.nomiScaled(size: 18.5))
                        .foregroundColor(cyan.opacity(0.85))

                    Text(dayLabel(index: index, day: day))
                        .font(.nomiScaled(size: 13.5, weight: index == 0 ? .semibold : .regular))
                        .foregroundColor(index == 0 ? CardPalette.ink : CardPalette.subtle)

                    HStack(spacing: 4) {
                        Text("\(Int(day.max.rounded()))°")
                            .foregroundColor(CardPalette.ink.opacity(0.9))
                        Text("\(Int(day.min.rounded()))°")
                            .foregroundColor(CardPalette.subtle)
                    }
                    .font(.nomiScaled(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
    }

    private func dayLabel(index: Int, day: WeatherDay) -> String {
        if index == 0 { return "今天" }
        if index == 1 { return "明天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter.string(from: day.date)
    }
}
