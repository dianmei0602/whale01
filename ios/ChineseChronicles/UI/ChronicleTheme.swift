import SwiftUI

enum ChronicleTheme {
    static let paper = Color(hex: "#F3EBDD")
    static let paperDeep = Color(hex: "#E5D8C3")
    static let card = Color(hex: "#FFF9EE")
    static let ink = Color(hex: "#26231F")
    static let secondaryInk = Color(hex: "#6F665A")
    static let faintInk = Color(hex: "#9A8F7D")
    static let cinnabar = Color(hex: "#A53F31")
    static let bronze = Color(hex: "#6D765E")
    static let gold = Color(hex: "#A98548")
    static let hairline = Color(hex: "#D7C8B0")

    static let display = Font.custom("Songti SC", size: 38, relativeTo: .largeTitle)
        .weight(.semibold)
    static let title = Font.custom("Songti SC", size: 25, relativeTo: .title2)
        .weight(.semibold)
    static let section = Font.custom("Songti SC", size: 20, relativeTo: .headline)
        .weight(.semibold)
    static let bodySerif = Font.custom("Songti SC", size: 16, relativeTo: .body)
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch cleaned.count {
        case 8:
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        default:
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

struct PaperBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        ChronicleTheme.paper,
                        ChronicleTheme.paperDeep.opacity(0.66),
                        ChronicleTheme.paper
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                ForEach(0..<22, id: \.self) { index in
                    Rectangle()
                        .fill(ChronicleTheme.ink.opacity(index.isMultiple(of: 3) ? 0.022 : 0.012))
                        .frame(height: 0.6)
                        .offset(y: CGFloat(index) * max(geometry.size.height / 22, 18))
                }

                Circle()
                    .fill(ChronicleTheme.gold.opacity(0.08))
                    .frame(width: geometry.size.width * 0.92)
                    .blur(radius: 44)
                    .offset(
                        x: geometry.size.width * 0.42,
                        y: -geometry.size.height * 0.36
                    )
            }
        }
        .ignoresSafeArea()
    }
}

struct ChronicleChip: View {
    let text: String
    var tint: Color = ChronicleTheme.secondaryInk

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.1), in: Capsule())
            .overlay {
                Capsule().stroke(tint.opacity(0.16), lineWidth: 0.8)
            }
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow)
                .font(.caption2.weight(.bold))
                .tracking(2)
                .foregroundStyle(ChronicleTheme.cinnabar)
            Text(title)
                .font(ChronicleTheme.title)
                .foregroundStyle(ChronicleTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DynastyCard: View {
    let dynasty: ChronicleDynasty
    let eventCount: Int

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: dynasty.accent))
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(dynasty.name)
                        .font(ChronicleTheme.title)
                        .foregroundStyle(ChronicleTheme.ink)
                    Text(dynasty.periodLabel)
                        .font(.caption)
                        .foregroundStyle(ChronicleTheme.secondaryInk)
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ChronicleTheme.faintInk)
                }

                Text(dynasty.subtitle)
                    .font(ChronicleTheme.bodySerif)
                    .foregroundStyle(ChronicleTheme.secondaryInk)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    ChronicleChip(
                        text: dynasty.role.label,
                        tint: Color(hex: dynasty.accent)
                    )
                    if eventCount > 0 {
                        ChronicleChip(text: "\(eventCount) 件大事")
                    }
                }
            }
        }
        .padding(18)
        .background(ChronicleTheme.card.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(ChronicleTheme.hairline.opacity(0.72), lineWidth: 0.8)
        }
    }
}

struct EventRow: View {
    let event: ChronicleEvent
    let dynastyName: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 5) {
                Circle()
                    .fill(ChronicleTheme.cinnabar)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(ChronicleTheme.cinnabar.opacity(0.22))
                    .frame(width: 1, height: 42)
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.date.display)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(ChronicleTheme.cinnabar)
                    Text(dynastyName)
                        .font(.caption)
                        .foregroundStyle(ChronicleTheme.secondaryInk)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ChronicleTheme.faintInk)
                }
                Text(event.title)
                    .font(ChronicleTheme.section)
                    .foregroundStyle(ChronicleTheme.ink)
                Text(event.summary)
                    .font(.subheadline)
                    .foregroundStyle(ChronicleTheme.secondaryInk)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(16)
        .background(ChronicleTheme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(ChronicleTheme.hairline.opacity(0.55), lineWidth: 0.7)
        }
    }
}

struct SourceBadge: View {
    let source: ChronicleSource

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(source.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ChronicleTheme.ink)
                Spacer()
                ChronicleChip(
                    text: source.kind.label,
                    tint: source.kind == .primary ? ChronicleTheme.bronze : ChronicleTheme.gold
                )
            }
            Text(source.author)
                .font(.caption)
                .foregroundStyle(ChronicleTheme.secondaryInk)
            Text(source.citation)
                .font(ChronicleTheme.bodySerif)
                .foregroundStyle(ChronicleTheme.secondaryInk)
            Text(source.note)
                .font(.caption)
                .foregroundStyle(ChronicleTheme.faintInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .background(ChronicleTheme.card.opacity(0.72), in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(ChronicleTheme.hairline.opacity(0.65), lineWidth: 0.7)
        }
    }
}
