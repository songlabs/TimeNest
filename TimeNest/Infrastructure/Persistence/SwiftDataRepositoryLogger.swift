enum SwiftDataRepositoryLogger {
    static func log(_ operation: String, error: Error) {
        #if DEBUG
        print("[SwiftData] \(operation) failed: \(error)")
        #endif
    }
}
