import SwiftUI

/// 通用占位视图 - 用于尚未实现的功能页面
struct ListPlaceholderView: View {
    let title: String
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "hammer.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(LocalizedString.placeholderComingSoon.localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ListPlaceholderView(title: "テスト")
}
