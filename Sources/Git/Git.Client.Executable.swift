public import Git_Standard

#if canImport(Darwin)
    private import Darwin
#elseif canImport(Glibc)
    private import Glibc
#elseif canImport(Musl)
    private import Musl
#elseif canImport(WinSDK)
    private import WinSDK
#endif

extension Git.Client {

    public static var installed: Swift.String {
        for directory in searchDirectories() {
            for name in executableNames {
                let candidate = "\(directory)\(separator)\(name)"
                if isExecutable(candidate) { return candidate }
            }
        }
        return conventionalPath
    }

    #if os(Windows)
        static let executableNames = ["git.exe"]
    #else
        static let executableNames = ["git"]
    #endif

    #if os(Windows)
        static let conventionalPath = #"C:\Program Files\Git\cmd\git.exe"#
    #else
        static let conventionalPath = "/usr/bin/git"
    #endif

    #if os(Windows)
        static let separator: Swift.String = #"\"#
    #else
        static let separator: Swift.String = "/"
    #endif

    #if os(Windows)
        static let pathListSeparator: Swift.Character = ";"
    #else
        static let pathListSeparator: Swift.Character = ":"
    #endif

    static func searchDirectories() -> [Swift.String] {
        guard let path = environmentValue("PATH") else { return [] }
        return
            path
            .split(separator: pathListSeparator, omittingEmptySubsequences: true)
            .map(Swift.String.init)
    }

    static func isExecutable(_ path: Swift.String) -> Swift.Bool {
        #if os(Windows)
            return path.withCString(encodedAs: UTF16.self) { wide in
                let attributes = unsafe GetFileAttributesW(wide)
                guard attributes != DWORD.max else { return false }
                return attributes & DWORD(FILE_ATTRIBUTE_DIRECTORY) == 0
            }
        #else
            return path.withCString { unsafe access($0, X_OK) == 0 }
        #endif
    }

    static func environmentValue(_ name: Swift.String) -> Swift.String? {
        #if os(Windows)
            return name.withCString(encodedAs: UTF16.self) { wide -> Swift.String? in

                let capacity = unsafe GetEnvironmentVariableW(wide, nil, 0)
                guard capacity > 0 else { return nil }
                var buffer = [WCHAR](repeating: 0, count: Swift.Int(capacity))
                let written = unsafe GetEnvironmentVariableW(wide, &buffer, capacity)
                guard written > 0, written < capacity else { return nil }
                return Swift.String(decoding: buffer[..<Swift.Int(written)], as: UTF16.self)
            }
        #else
            guard let value = unsafe getenv(name) else { return nil }
            return unsafe Swift.String(cString: value)
        #endif
    }
}
