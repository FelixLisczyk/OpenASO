import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelsAIService: AIProviderService {
    let provider = AIProvider.appleFoundationModels

    static var isDefaultModelAvailable: Bool {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else {
            return false
        }

        return isDefaultModelAvailableOnCurrentOS
        #else
        return false
        #endif
    }

    func respond(to request: AIRequest, model: AIModelID) async throws -> AIResponse {
        guard model == .Apple.default else {
            throw AIServiceError.unsupportedModel(provider: provider, model: model)
        }

        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else {
            throw AIServiceError.modelUnavailable("Apple Foundation Models require macOS 26.0 or later.")
        }

        return try await respondWithFoundationModels(to: request, model: model)
        #else
        throw AIServiceError.modelUnavailable("Apple Foundation Models are not available in this toolchain.")
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private static var isDefaultModelAvailableOnCurrentOS: Bool {
        let languageModel = SystemLanguageModel.default
        switch languageModel.availability {
        case .available:
            return true
        case .unavailable:
            return false
        }
    }

    @available(macOS 26.0, *)
    private func respondWithFoundationModels(to request: AIRequest, model: AIModelID) async throws -> AIResponse {
        let languageModel = SystemLanguageModel.default
        switch languageModel.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw AIServiceError.modelUnavailable("Apple Foundation Models are unavailable: \(String(describing: reason)).")
        }

        let session = LanguageModelSession(
            model: languageModel,
            instructions: request.instructions ?? ""
        )
        let options = GenerationOptions(
            temperature: request.temperature,
            maximumResponseTokens: request.maximumResponseTokens
        )
        let response = try await session.respond(to: request.prompt, options: options)
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw AIServiceError.emptyResponse
        }

        return AIResponse(text: text, provider: provider, model: model)
    }
    #endif
}
