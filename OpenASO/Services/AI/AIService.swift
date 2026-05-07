import Foundation

enum AIProvider: String, Codable, Hashable, Sendable {
    case appleFoundationModels
}

struct AIModelID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

extension AIModelID {
    enum Apple {
        static let `default` = AIModelID(rawValue: "default")
    }
}

struct AIModelSelection: Codable, Hashable, Sendable {
    let provider: AIProvider
    let model: AIModelID

    static let defaultAppleFoundationModel = AIModelSelection(
        provider: .appleFoundationModels,
        model: .Apple.default
    )
}

struct AIRequest: Sendable {
    let prompt: String
    let instructions: String?
    let temperature: Double?
    let maximumResponseTokens: Int?

    init(
        prompt: String,
        instructions: String? = nil,
        temperature: Double? = nil,
        maximumResponseTokens: Int? = nil
    ) {
        self.prompt = prompt
        self.instructions = instructions
        self.temperature = temperature
        self.maximumResponseTokens = maximumResponseTokens
    }
}

struct AIResponse: Sendable {
    let text: String
    let provider: AIProvider
    let model: AIModelID
}

enum AIServiceError: LocalizedError, Equatable, Sendable {
    case providerUnavailable(AIProvider)
    case unsupportedModel(provider: AIProvider, model: AIModelID)
    case modelUnavailable(String)
    case emptyResponse
    case malformedResponse(String)

    var errorDescription: String? {
        switch self {
        case .providerUnavailable(let provider):
            return "AI provider \(provider.rawValue) is unavailable."
        case .unsupportedModel(let provider, let model):
            return "Model \(model.rawValue) is not supported by \(provider.rawValue)."
        case .modelUnavailable(let reason):
            return reason
        case .emptyResponse:
            return "The AI provider returned an empty response."
        case .malformedResponse(let message):
            return message
        }
    }
}

protocol AIService: Sendable {
    func respond(to request: AIRequest, using selection: AIModelSelection) async throws -> AIResponse
}

protocol AIProviderService: Sendable {
    var provider: AIProvider { get }

    func respond(to request: AIRequest, model: AIModelID) async throws -> AIResponse
}

final class AIServiceRouter: AIService {
    private let providers: [AIProvider: any AIProviderService]

    init(providers: [any AIProviderService]) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.provider, $0) })
    }

    func respond(to request: AIRequest, using selection: AIModelSelection) async throws -> AIResponse {
        guard let provider = providers[selection.provider] else {
            throw AIServiceError.providerUnavailable(selection.provider)
        }

        return try await provider.respond(to: request, model: selection.model)
    }
}

struct MockAIService: AIService {
    let responseText: @Sendable (AIRequest, AIModelSelection) throws -> String

    init(responseText: @escaping @Sendable (AIRequest, AIModelSelection) throws -> String = { _, _ in "" }) {
        self.responseText = responseText
    }

    func respond(to request: AIRequest, using selection: AIModelSelection) async throws -> AIResponse {
        AIResponse(
            text: try responseText(request, selection),
            provider: selection.provider,
            model: selection.model
        )
    }
}
