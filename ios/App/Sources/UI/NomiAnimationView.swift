import Lottie
import SwiftUI

enum NomiAnimationState: String, CaseIterable {
    case idle
    case happy
    case laughing
    case thinking
    case surprised
    case excited
    case angry
    case sad
    case crying
    case scared
    case confused
    case sleepy
    case love

    var loops: Bool {
        self == .idle
    }

    var posterName: String {
        "nomi_\(rawValue)"
    }
}

enum NomiAnimationAssets {
    static func hasAnimation(_ state: NomiAnimationState) -> Bool {
        Bundle.main.url(forResource: state.rawValue, withExtension: "json") != nil
    }
}

extension PetExpression {
    var animationState: NomiAnimationState {
        switch self {
        case .calm: return .idle
        case .happy: return .happy
        case .laugh: return .laughing
        case .curious: return .thinking
        case .angry: return .angry
        case .sad: return .sad
        case .cry: return .crying
        case .doze: return .sleepy
        case .sigh: return .sad
        case .think: return .thinking
        case .startle: return .surprised
        case .bored: return .confused
        case .excited: return .excited
        case .running: return .excited
        }
    }
}

/// Native Lottie surface for the new round-head Nomi.
///
/// Only one animation player exists per visible character. The player pauses
/// when the page is off-screen or the app is backgrounded, and the caller swaps
/// to a static poster when Reduce Motion is enabled.
struct NomiLottiePlayer: UIViewRepresentable {
    let state: NomiAnimationState
    var paused: Bool
    var size: CGFloat
    var trigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: LottieAnimationView,
        context: Context
    ) -> CGSize? {
        CGSize(width: size, height: size)
    }

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView()
        let target = CGSize(width: size, height: size)
        view.frame = CGRect(origin: .zero, size: target)
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.layer.masksToBounds = true
        view.maskAnimationToBounds = true
        view.backgroundBehavior = .pauseAndRestore
        view.shouldRasterizeWhenIdle = true
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        load(state, into: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ view: LottieAnimationView, context: Context) {
        let target = CGSize(width: size, height: size)
        if view.bounds.size != target {
            view.frame = CGRect(origin: .zero, size: target)
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        if context.coordinator.state != state || context.coordinator.trigger != trigger {
            load(state, into: view, coordinator: context.coordinator)
        }

        if paused {
            if view.isAnimationPlaying {
                view.pause()
            }
            context.coordinator.wasPaused = true
        } else if context.coordinator.wasPaused {
            context.coordinator.wasPaused = false
            if state.loops || view.currentProgress < 0.999 {
                view.play()
            }
        }
    }

    private func load(
        _ state: NomiAnimationState,
        into view: LottieAnimationView,
        coordinator: Coordinator
    ) {
        view.stop()
        view.animation = LottieAnimation.named(state.rawValue)
        view.loopMode = state.loops ? .loop : .playOnce
        coordinator.state = state
        coordinator.trigger = trigger
        if paused {
            coordinator.wasPaused = true
        } else {
            play(view, atBeginning: true)
        }
    }

    private func play(_ view: LottieAnimationView, atBeginning: Bool) {
        guard view.animation != nil else { return }
        if atBeginning {
            view.currentProgress = 0
        }
        view.play()
    }

    final class Coordinator {
        var state: NomiAnimationState?
        var wasPaused = false
        var trigger = 0
    }
}
