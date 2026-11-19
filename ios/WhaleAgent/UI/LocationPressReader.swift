import SwiftUI
import UIKit

/// Transparent UIKit gesture surface used where SwiftUI's long-press gesture
/// does not provide the press location.
struct LocationPressReader: UIViewRepresentable {
    let onTap: () -> Void
    let onLongPress: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onLongPress: onLongPress)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isOpaque = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.55
        longPress.allowableMovement = 14
        tap.require(toFail: longPress)
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(longPress)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onLongPress = onLongPress
    }

    final class Coordinator: NSObject {
        var onTap: () -> Void
        var onLongPress: (CGPoint) -> Void

        init(onTap: @escaping () -> Void, onLongPress: @escaping (CGPoint) -> Void) {
            self.onTap = onTap
            self.onLongPress = onLongPress
        }

        @objc func handleTap() {
            onTap()
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began else { return }
            onLongPress(recognizer.location(in: nil))
        }
    }
}

@MainActor
enum PressToastPresenter {
    static func show(_ text: String, at windowPoint: CGPoint) {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else { return }

        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .label
        label.textAlignment = .center
        label.sizeToFit()

        let width = label.bounds.width + 26
        let height = max(label.bounds.height + 18, 38)
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        container.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.96)
        container.layer.cornerRadius = height / 2
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.16
        container.layer.shadowRadius = 10
        container.layer.shadowOffset = CGSize(width: 0, height: 4)
        label.center = CGPoint(x: width / 2, y: height / 2)
        container.addSubview(label)

        let margin: CGFloat = 10
        let halfWidth = width / 2
        let centerX = min(max(windowPoint.x, window.safeAreaInsets.left + margin + halfWidth),
                           window.bounds.width - window.safeAreaInsets.right - margin - halfWidth)
        let proposedY = windowPoint.y - height - 14
        let centerY = min(max(proposedY, window.safeAreaInsets.top + margin + height / 2),
                          window.bounds.height - window.safeAreaInsets.bottom - margin - height / 2)
        container.center = CGPoint(x: centerX, y: centerY)
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        window.addSubview(container)

        UIView.animate(
            withDuration: 0.16,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState]
        ) {
            container.alpha = 1
            container.transform = .identity
        } completion: { _ in
            UIView.animate(
                withDuration: 0.18,
                delay: 1.15,
                options: [.curveEaseIn, .beginFromCurrentState]
            ) {
                container.alpha = 0
                container.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            } completion: { _ in
                container.removeFromSuperview()
            }
        }
    }
}
