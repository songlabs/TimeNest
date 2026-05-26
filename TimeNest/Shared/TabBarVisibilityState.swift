import SwiftUI

/// 控制全局底部 TabBar 显示状态
@MainActor
class TabBarVisibilityState: ObservableObject {
    static let shared = TabBarVisibilityState()

    @Published var isHidden: Bool = false
    private var hideCount: Int = 0

    private init() {}

    /// 隐藏 TabBar
    /// - 幂等：如果已经隐藏，重复调用不会增加计数
    func hide() {
        if hideCount == 0 {
            hideCount = 1
            isHidden = true
        } else {
            // 已经隐藏，增加嵌套计数
            hideCount += 1
        }
    }

    /// 显示 TabBar
    /// - 只有当所有 hide() 都对应 show() 时才真正显示
    func show() {
        if hideCount > 0 {
            hideCount -= 1
            if hideCount == 0 {
                isHidden = false
            }
        }
    }

    /// 重置状态（用于异常情况恢复）
    func reset() {
        hideCount = 0
        isHidden = false
    }
}
