import SwiftUI

struct SettingsView: View {
    @State private var displayLanguage: DisplayLanguage = .system
    @State private var holidayRegion: HolidayRegion = .japan
    @State private var weekStart: WeekStartPolicy = .system
    
    var body: some View {
        Form {
            Section {
                Picker("显示语言", selection: $displayLanguage) {
                    Text("系统默认").tag(DisplayLanguage.system)
                    Text("简体中文").tag(DisplayLanguage.zhHans)
                    Text("日本語").tag(DisplayLanguage.ja)
                    Text("한국어").tag(DisplayLanguage.ko)
                    Text("English").tag(DisplayLanguage.enUS)
                }
            } header: {
                Text("语言")
            }
            
            Section {
                Picker("节假日地区", selection: $holidayRegion) {
                    Text("日本").tag(HolidayRegion.japan)
                    Text("中国").tag(HolidayRegion.china)
                    Text("韩国").tag(HolidayRegion.korea)
                    Text("美国").tag(HolidayRegion.unitedStates)
                }
            } header: {
                Text("节假日")
            }
            
            Section {
                Picker("一周开始", selection: $weekStart) {
                    Text("系统默认").tag(WeekStartPolicy.system)
                    Text("周日").tag(WeekStartPolicy.sunday)
                    Text("周一").tag(WeekStartPolicy.monday)
                }
            } header: {
                Text("日历")
            }
        }
        .navigationTitle("设置")
    }
}

