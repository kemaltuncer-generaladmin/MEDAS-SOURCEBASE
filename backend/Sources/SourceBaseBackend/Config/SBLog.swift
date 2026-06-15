import OSLog

public enum SBLog {
    public static let auth = Logger(subsystem: "tr.com.medasi.sourcebase", category: "auth")
    public static let drive = Logger(subsystem: "tr.com.medasi.sourcebase", category: "drive")
    public static let store = Logger(subsystem: "tr.com.medasi.sourcebase", category: "store")
}
