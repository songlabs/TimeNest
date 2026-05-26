import SwiftUI

/// 控制全局底部 TabBar 显示状态
@MainActor
class TabBarVisibilityState: ObservableObject {
    static let shared = TabBarVisibilityState()
    
    @Published var isHidden: Bool = false
    
    private init() {}
}
