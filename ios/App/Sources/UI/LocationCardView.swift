import SwiftUI
import UIKit
import MapKit
import Foundation

/// 聊天里的位置卡：地址 + 精度 + 打开高德。
struct LocationCardView: View {
    let fix: LocationFix
    @Environment(\.openURL) private var openURL

    private let cyan = CardPalette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            mapBlock
            addressBlock
            statRow
            actions
        }
        .padding(14)
        .background(CardPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CardPalette.line, lineWidth: 1)
        )
        .padding(.leading, 8)
    }

    // MARK: - 头

    private var header: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(cyan.opacity(0.14))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "location.fill")
                        .font(.nomiScaled(size: 14))
                        .foregroundColor(cyan)
                )

            Text("位置")
                .font(.nomiScaled(size: 17, weight: .semibold))
                .foregroundColor(CardPalette.ink)

            Spacer()

            Text("GPS · LOCK")
                .font(.nomiScaled(size: 11, weight: .medium))
                .foregroundColor(CardPalette.subtle)
                .tracking(0.6)
        }
        .padding(.bottom, 12)
    }

    // MARK: - 地图块（不加载真实地图，画一个示意图）

    private var mapBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.05, green: 0.09, blue: 0.13))

            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 26
                    var x: CGFloat = 0
                    while x < geo.size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y < geo.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += step
                    }
                }
                .stroke(cyan.opacity(0.07), lineWidth: 1)
            }

            // 中心定位点
            ZStack {
                Circle()
                    .fill(cyan.opacity(0.16))
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(cyan.opacity(0.35), lineWidth: 1)
                    .frame(width: 44, height: 44)
                Image(systemName: "mappin.circle.fill")
                    .font(.nomiScaled(size: 23))
                    .foregroundColor(cyan)
            }
        }
        .frame(height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 5) {
                Circle().fill(cyan).frame(width: 5, height: 5)
                Text("刚刚更新")
                    .font(.nomiScaled(size: 11))
                    .foregroundColor(CardPalette.ink.opacity(0.8))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.35))
            .clipShape(Capsule())
            .padding(8)
        }
        .padding(.bottom, 11)
    }

    // MARK: - 地址

    private var addressBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fix.fullAddress)
                .font(.nomiScaled(size: 17, weight: .semibold))
                .foregroundColor(CardPalette.ink)
                .lineLimit(2)

            if let place = fix.placeName, !place.isEmpty, place != fix.fullAddress {
                Text(place)
                    .font(.nomiScaled(size: 13))
                    .foregroundColor(CardPalette.subtle)
                    .lineLimit(1)
            }
        }
    }

    private var statRow: some View {
        HStack(spacing: 14) {
            stat("ACC", "±\(Int(fix.horizontalAccuracy.rounded()))M")
            stat("GPS", "LOCK")
            stat("LAT", String(format: "%.4f", fix.latitude))
            stat("LON", String(format: "%.4f", fix.longitude))
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.nomiScaled(size: 10, weight: .medium))
                .foregroundColor(CardPalette.subtle)
                .tracking(0.5)
            Text(value)
                .font(.nomiScaled(size: 11.5, weight: .semibold))
                .foregroundColor(CardPalette.ink.opacity(0.85))
        }
    }

    // MARK: - 按钮

    private var actions: some View {
        HStack(spacing: 9) {
            actionButton(title: "附近推荐", symbol: "location.north.line") {
                openAmap(keyword: "美食")
            }
            actionButton(title: "共享位置", symbol: "square.and.arrow.up") {
                share()
            }
        }
        .padding(.top, 11)
    }

    private func actionButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.nomiScaled(size: 14))
                Text(title)
                    .font(.nomiScaled(size: 14.5, weight: .medium))
            }
            .foregroundColor(CardPalette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(CardPalette.raised)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CardPalette.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 打开高德

    /// 默认走高德；没装就退回苹果地图
    private func openAmap(keyword: String?) {
        let lat = fix.latitude
        let lon = fix.longitude

        var amapString: String
        if let keyword = keyword,
           let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            amapString = "amapuri://poi?sourceApplication=nomi&lat=\(lat)&lon=\(lon)&keywords=\(encoded)"
        } else {
            amapString = "iosamap://viewMap?sourceApplication=nomi&lat=\(lat)&lon=\(lon)&dev=0"
        }

        if let url = URL(string: amapString), canOpen(url) {
            openURL(url)
            return
        }

        // 高德没装：苹果地图
        if let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)&q=\(keyword ?? "当前位置")") {
            openURL(url)
        }
    }

    private func canOpen(_ url: URL) -> Bool {
        UIApplication.shared.canOpenURL(url)
    }

    private func share() {
        let text = "\(fix.fullAddress)\n\(fix.coordinateText)\nhttps://maps.apple.com/?ll=\(fix.latitude),\(fix.longitude)"

        let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.keyWindow?.rootViewController
        else { return }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(controller, animated: true)
    }
}
