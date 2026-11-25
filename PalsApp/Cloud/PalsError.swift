import CloudKit
import os

/// Something that went wrong talking to iCloud, in words a person can act on. The raw error
/// goes to the log (Console.app, subsystem = the app's bundle ID, category "cloud"), never
/// on screen.
struct PalsError: Error, Identifiable, Equatable {
    enum Kind: Equatable {
        /// No connection. Changes wait and go up once you're back online.
        case offline
        /// Not signed in to iCloud on this device.
        case signedOut
        /// iCloud is busy or rate-limiting us. Worth retrying after a pause.
        case busy
        /// The circle (or record) isn't there.
        case notFound
        /// Pals' iCloud database can't take this yet (e.g. the schema isn't deployed).
        case notReady
        /// The app's iCloud storage is full.
        case full
        /// Only the person who made something can change it.
        case permission
        case unknown
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String
    /// How long iCloud asked us to wait before trying again.
    var retryAfter: TimeInterval?

    /// Goes away on its own if we wait and try again.
    var isTransient: Bool { kind == .offline || kind == .busy }

    static func == (a: PalsError, b: PalsError) -> Bool { a.id == b.id }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Pals", category: "cloud")

    init(kind: Kind, title: String, message: String, retryAfter: TimeInterval? = nil) {
        self.kind = kind
        self.title = title
        self.message = message
        self.retryAfter = retryAfter
    }

    /// The friendly version of any error, or `nil` for a cancelled task (nothing to tell anyone).
    static func from(_ error: Error) -> PalsError? {
        if let error = error as? PalsError { return error }
        if error is CancellationError { return nil }
        log.error("iCloud error: \(String(describing: error))")

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .timedOut:
                return .offline
            default:
                return .unknown
            }
        }
        guard let error = error as? CKError else { return .unknown }

        switch error.code {
        case .partialFailure:
            // Report the first record that failed.
            guard let first = error.partialErrorsByItemID?.values.first else { return .unknown }
            return from(first)
        case .operationCancelled:
            return nil
        case .networkUnavailable, .networkFailure:
            return .offline
        case .notAuthenticated:
            return PalsError(kind: .signedOut, title: "Sign in to iCloud",
                             message: "Open Settings and sign in to iCloud to use real circles.")
        case .serviceUnavailable, .requestRateLimited, .zoneBusy, .serverResponseLost:
            return PalsError(kind: .busy, title: "iCloud is busy",
                             message: "Trying again in a moment.",
                             retryAfter: error.retryAfterSeconds)
        case .unknownItem:
            return PalsError(kind: .notFound, title: "Not found",
                             message: "That circle doesn't exist anymore.")
        case .quotaExceeded:
            return PalsError(kind: .full, title: "Pals is full",
                             message: "Pals' iCloud storage is full right now. Try again later.")
        case .permissionFailure:
            return PalsError(kind: .permission, title: "Can't change that",
                             message: "Only the person who made it can change it.")
        case .invalidArguments, .serverRejectedRequest, .badContainer, .badDatabase,
             .missingEntitlement, .incompatibleVersion:
            // Usually the CloudKit schema (Production missing a type, field or index).
            return PalsError(kind: .notReady, title: "Pals can't sync right now",
                             message: "Pals' iCloud database isn't ready for this yet. Try again later, or update the app.")
        default:
            return .unknown
        }
    }

    static var offline: PalsError {
        PalsError(kind: .offline, title: "You're offline",
                  message: "Your changes will sync when you're back online.")
    }

    static var unknown: PalsError {
        PalsError(kind: .unknown, title: "Couldn't sync",
                  message: "Something went wrong with iCloud. Try again.")
    }
}
