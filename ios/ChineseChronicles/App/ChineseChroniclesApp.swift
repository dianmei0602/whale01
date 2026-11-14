import SwiftUI

@main
struct ChineseChroniclesApp: App {
    private enum Bootstrap {
        case ready(ChronicleRepository)
        case failed(String)
    }

    private let bootstrap: Bootstrap

    init() {
        do {
            bootstrap = .ready(try ChronicleRepository.bundled())
        } catch {
            bootstrap = .failed(error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case .ready(let repository):
                RootView(repository: repository)
            case .failed(let message):
                DataFailureView(message: message)
            }
        }
    }
}

private struct DataFailureView: View {
    let message: String

    var body: some View {
        ZStack {
            PaperBackdrop()
            VStack(spacing: 16) {
                Image(systemName: "book.closed")
                    .font(.system(size: 38))
                    .foregroundStyle(ChronicleTheme.cinnabar)
                Text("资料未能载入")
                    .font(ChronicleTheme.title)
                    .foregroundStyle(ChronicleTheme.ink)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(ChronicleTheme.secondaryInk)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
        .accessibilityIdentifier("data-load-failed")
    }
}
