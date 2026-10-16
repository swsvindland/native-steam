import Foundation

/// Startup milestones for benchmarking. Set `NATIVE_STEAM_TRACE=1` to print
/// "trace <label> <ms since process start>" lines to stderr.
public enum LaunchTrace {
    private static let enabled = ProcessInfo.processInfo.environment["NATIVE_STEAM_TRACE"] != nil
    nonisolated(unsafe) private static var seen = Set<String>()

    /// Wall-clock time the kernel started this process.
    private static let processStart: Date = {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return Date() }
        let tv = info.kp_proc.p_starttime
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000)
    }()

    /// Records `label` once.
    public static func mark(_ label: String) {
        guard enabled, !seen.contains(label) else { return }
        seen.insert(label)
        let ms = Date().timeIntervalSince(processStart) * 1000
        FileHandle.standardError.write(Data(String(format: "trace %@ %.1f\n", label, ms).utf8))
    }
}
