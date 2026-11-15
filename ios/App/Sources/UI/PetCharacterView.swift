import SwiftUI

/// New round-head Nomi.
///
/// The rendered character comes from `Resources/NomiAnimations`. This wrapper
/// keeps the App call sites stable while adding expression-aware Lottie
/// playback, pause-on-offscreen behavior and a poster fallback for Reduce Motion.
struct PetCharacterView: View {
    var action: PetMotionAction = .idle
    var followFace: Double = 0
    var size: CGFloat = 150
    var eyeOpen: Double = 1
    var eyeScale: Double = 1
    var eyeTint: Color = EyePalette.default
    var showShadow: Bool = true
    var headTilt: Double = 0
    var blinkSpeed: Double = 1.0
    var isPaused: Bool = false
    var expression: PetExpression = .calm
    var trigger: Int = 0

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animationState: NomiAnimationState {
        if expression != .calm {
            return expression.animationState
        }

        switch action {
        case .hop: return .happy
        case .nod: return .thinking
        case .jump, .run: return .excited
        case .sit: return .sleepy
        case .idle, .walk: return .idle
        }
    }

    private var paused: Bool {
        isPaused || scenePhase != .active
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if showShadow {
                Ellipse()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: size * 0.54, height: size * 0.09)
                    .blur(radius: size * 0.035)
                    .offset(y: size * 0.03)
            }

            Group {
                if reduceMotion || !NomiAnimationAssets.hasAnimation(animationState) {
                    Image(animationState.posterName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                } else {
                    NomiLottiePlayer(
                        state: animationState,
                        paused: paused,
                        size: size,
                        trigger: trigger
                    )
                }
            }
            .frame(width: size, height: size)
            .clipped()
        }
        .frame(width: size, height: size * 1.04)
        .rotationEffect(.degrees(headTilt + followFace * 4.2), anchor: .center)
        .offset(x: CGFloat(followFace) * size * 0.025)
        .animation(.easeOut(duration: 0.20), value: headTilt)
        .animation(.easeOut(duration: 0.16), value: followFace)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nomi")
    }
}
