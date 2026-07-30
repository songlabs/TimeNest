struct TraditionalCalendarDisplay: Hashable {
    let lunarText: String?
    let rokuyoText: String?
    let solarTermText: String?

    static let empty = TraditionalCalendarDisplay(
        lunarText: nil,
        rokuyoText: nil,
        solarTermText: nil
    )

    var isEmpty: Bool {
        lunarText == nil && rokuyoText == nil && solarTermText == nil
    }
}
