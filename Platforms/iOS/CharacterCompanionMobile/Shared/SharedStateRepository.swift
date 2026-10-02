import Foundation

enum SharedStateError: Error {
    case appGroupUnavailable(String)
    case coordinationFailed(Error)
}

extension SharedStateError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable(let identifier):
            return "App Group \(identifier) 尚未配置，App、Widget 与实时活动暂时无法共享状态。"
        case .coordinationFailed(let error):
            return "共享状态写入失败：\(error.localizedDescription)"
        }
    }
}

struct SharedStateRepository: Sendable {
    static let appGroupIdentifier = "group.local.codex.yuwenzhou.companion.mobile"
    static let shared = SharedStateRepository()

    let rootURL: URL
    private let stateURL: URL
    private let appGroupIsAvailable: Bool

    init(rootURL: URL? = nil) {
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
        let resolvedRoot = rootURL
            ?? groupURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("YuWenzhouCompanionMobile-UnavailableAppGroup", isDirectory: true)
        self.rootURL = resolvedRoot
        self.stateURL = resolvedRoot.appendingPathComponent("companion-state-v1.json")
        self.appGroupIsAvailable = rootURL != nil || groupURL != nil
    }

    func load(now: Date = Date()) -> CompanionState {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var loadedState: CompanionState?

        coordinator.coordinate(readingItemAt: stateURL, options: .withoutChanges, error: &coordinationError) { coordinatedURL in
            guard let data = try? Data(contentsOf: coordinatedURL) else { return }
            loadedState = try? JSONDecoder.companion.decode(CompanionState.self, from: data)
        }

        guard var state = loadedState else {
            return .initial(now: now)
        }
        state.normalize(at: now)
        return state
    }

    @discardableResult
    func mutate(now: Date = Date(), _ body: (inout CompanionState) throws -> Void) throws -> CompanionState {
        guard appGroupIsAvailable else {
            throw SharedStateError.appGroupUnavailable(Self.appGroupIdentifier)
        }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<CompanionState, Error>?

        coordinator.coordinate(writingItemAt: stateURL, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            do {
                var state: CompanionState
                if let data = try? Data(contentsOf: coordinatedURL),
                   let decoded = try? JSONDecoder.companion.decode(CompanionState.self, from: data) {
                    state = decoded
                } else {
                    state = .initial(now: now)
                }
                state.normalize(at: now)
                try body(&state)
                state.updatedAt = now
                let data = try JSONEncoder.companion.encode(state)
                try data.write(to: coordinatedURL, options: .atomic)
                result = .success(state)
            } catch {
                result = .failure(error)
            }
        }

        if let coordinationError { throw SharedStateError.coordinationFailed(coordinationError) }
        return try result?.get() ?? .initial(now: now)
    }

    @discardableResult
    func ensureInitialized(now: Date = Date()) throws -> CompanionState {
        try mutate(now: now) { _ in }
    }
}

private extension JSONEncoder {
    static var companion: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var companion: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
