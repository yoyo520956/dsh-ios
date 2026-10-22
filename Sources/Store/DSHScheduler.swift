import Foundation

// 前台调度器：每 30s 检查计划任务，到点（且未在本分钟触发过）→ 回调到点任务
@MainActor
public final class DSHScheduler: ObservableObject {
    @Published public private(set) var lastFiredName: String?
    private var timer: Timer?
    private var firedKeys: Set<String> = []

    public init() { start() }

    public func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    public func tick() {
        let store = DSHStore.shared
        let now = Date()
        let cal = Calendar.current
        let key = String(format: "%02d:%02d", cal.component(.hour, from: now), cal.component(.minute, from: now))
        for task in store.tasks where task.enabled {
            let weekday = cal.component(.weekday, from: now)
            switch task.repeatMode {
            case .daily: break
            case .weekdays: if weekday == 1 || weekday == 7 { continue }
            case .once: break
            }
            guard String(format: "%02d:%02d", task.hour, task.minute) == key else { continue }
            let dedup = "\(task.id)-\(key)-\(cal.component(.day, from: now))"
            guard !firedKeys.contains(dedup) else { continue }
            firedKeys.insert(dedup)
            lastFiredName = task.name
            if let i = store.tasks.firstIndex(where: { $0.id == task.id }) { store.tasks[i].lastFired = now; store.save() }
            // 触发：把待跑 prompt 挂到 store，App 层接到就跑
            _ = store.newSession()
            store.autoRunPrompt = task.prompt
        }
    }
}
