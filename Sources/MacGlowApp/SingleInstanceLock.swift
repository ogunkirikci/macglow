import Darwin
import Foundation

/// A per-user lock shared by installed copies and development builds. The OS
/// releases it on exit, including crashes; the lock file itself must stay put.
final class SingleInstanceLock {
    private let descriptor: Int32

    static func acquire(at url: URL) throws -> SingleInstanceLock? {
        let descriptor = url.withUnsafeFileSystemRepresentation {
            Darwin.open($0!, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            close(descriptor)
            if code == EWOULDBLOCK { return nil }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        return SingleInstanceLock(descriptor: descriptor)
    }

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    deinit {
        close(descriptor)
    }
}
