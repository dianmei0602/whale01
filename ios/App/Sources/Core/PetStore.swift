import Foundation

/// 只存三样东西：它的状态、上次活跃的日期。
/// 不上云、不做迁移、坏了就当新的。
struct PetStore {
    private let stateKey = "jinri.pet.state"
    private let dayKey = "jinri.pet.lastDay"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PetState {
        guard let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(PetState.self, from: data)
        else {
            return PetState()
        }
        return state
    }

    func save(_ state: PetState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }

    func lastActiveDay() -> String? {
        defaults.string(forKey: dayKey)
    }

    func markActive(_ day: String) {
        defaults.set(day, forKey: dayKey)
    }
}