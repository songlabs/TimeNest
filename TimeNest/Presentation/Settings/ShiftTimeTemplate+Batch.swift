import Foundation

extension ShiftTimeTemplate {
    var batchSnapshot: ShiftBatchTemplateSnapshot {
        ShiftBatchTemplateSnapshot(
            id: id,
            displayName: displayName,
            note: note,
            colorHex: colorHex,
            startTime: startTime,
            endTime: endTime,
            enabled: enabled
        )
    }
}
