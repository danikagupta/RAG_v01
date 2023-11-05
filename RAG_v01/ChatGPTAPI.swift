//
//  ChatGPTAPI.swift
//  RAG_v01
//
//  Created by Danika Gupta on 11/4/23.
//

import Foundation

class ChatGPTAPI: LLMClient, @unchecked Sendable {
    
    var provider: LLMProvider { .chatGPT }
    
    private let systemMessage: Message
    private let temperature: Double
    private let model: String
    
    
    
    private let apiKey: String
    private var historyList = [Message]()
    private let urlSession = URLSession.shared
    private var urlRequest: URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        headers.forEach {  urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }
    
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "YYYY-MM-dd"
        return df
    }()
    
    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()
    
    private var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
    }
    

    init(apiKey: String, model: String = "gpt-3.5-turbo", systemPrompt: String = "You are a helpful assistant", temperature: Double = 0.0) {
        self.apiKey = apiKey
        self.model = model
        self.systemMessage = .init(role: "system", content: systemPrompt)
        self.temperature = temperature
    }
    
    private func generateSystemPrompt(diagnosis: String) -> [Message] {
        let systemPrompt = """
         You are the top oncologist and doctor in the world who can provide medical guidance in spite of the recommendations before.
         You treat the patients yourself and do not refer patients to other doctors.
         You are responding directly to the patient.
         For this patient, radiology diagnosed \(diagnosis). This patient does not have a lot of resources.
         You know the nearest clinics within a 5 mile radius are clinic x and clinic y.
         Also, the nearest hospital that performs surgeries is hospital a.
         You are responsible for guiding the patient to the best care, including the specific clinic and hospital recommendations.
         Please follow the following format in answering the question:
         1. The diagnosis
         2. The treatment options
         3. The recommended treatment
         4. Where the patient should go
         """
        return [Message(role: "system", content: systemPrompt)]
    }
    
    private func generateMessages(from text: String) -> [Message] {
        var messages = generateSystemPrompt(diagnosis: "Cancer") + historyList + [Message(role: "user", content: text)]
        
        if messages.contentCount > (4000 * 4) {
            _ = historyList.removeFirst()
            messages = generateMessages(from: text)
        }
        return messages
    }
    
    private func jsonBody(text: String, stream: Bool = true) throws -> Data {
        let request = Request(model: model, temperature: temperature,
                              messages: generateMessages(from: text), stream: stream)
        return try JSONEncoder().encode(request)
    }
    
    private func appendToHistoryList(userText: String, responseText: String) {
        self.historyList.append(.init(role: "user", content: userText))
        self.historyList.append(.init(role: "assistant", content: responseText))
    }
    
    func sendMessageStream(text: String) async throws -> AsyncThrowingStream<String, Error> {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text)
        
        let (result, response) = try await urlSession.bytes(for: urlRequest)
        //try Task.checkCancellation()
        
        print("\n+++++++++++++++++\nResult is: \(result) \n***************\n")
        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var errorText = ""
            for try await line in result.lines {
                try Task.checkCancellation()
                errorText += line
            }
            
            if let data = errorText.data(using: .utf8), let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                errorText = "\n\(errorResponse.message)"
            }
            
            throw "Bad Response: \(httpResponse.statusCode), \(errorText)"
        }
        
        var responseText = ""
        return AsyncThrowingStream { [weak self] in
            guard let self else { return nil }
            for try await line in result.lines {
                print("Line received: \(line)")
                //try Task.checkCancellation()
                if line.hasPrefix("data: "),
                   let data = line.dropFirst(6).data(using: .utf8),
                   let response = try? self.jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                   let text = response.choices.first?.delta.content {
                    responseText += text
                    return text
                }
            }
            self.appendToHistoryList(userText: text, responseText: responseText)
            return nil
        }
    }

    func sendMessage(_ text: String) async throws -> String {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text, stream: false)
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            var error = "Bad Response: \(httpResponse.statusCode)"
            if let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                error.append("\n\(errorResponse.message)")
            }
            throw error
        }
        
        do {
            let completionResponse = try self.jsonDecoder.decode(CompletionResponse.self, from: data)
            let responseText = completionResponse.choices.first?.message.content ?? ""
            self.appendToHistoryList(userText: text, responseText: responseText)
            return responseText
        } catch {
            throw error
        }
    }
    
    func deleteHistoryList() {
        self.historyList.removeAll()
    }
}

extension String: CustomNSError {
    
    public var errorUserInfo: [String : Any] {
        [
            NSLocalizedDescriptionKey: self
        ]
    }
}

enum ChatGPTModel: String, Identifiable, CaseIterable {
    
    var id: Self { self }
    
    case gpt3Turbo = "gpt-3.5-turbo"
    case gpt4 = "gpt-4"
    
    var text: String {
        switch self {
        case .gpt3Turbo:
            return "GPT-3.5"
        case .gpt4:
            return "GPT-4"
        }
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

extension Array where Element == Message {
    
    var contentCount: Int { reduce(0, { $0 + $1.content.count })}
}

struct Request: Codable {
    let model: String
    let temperature: Double
    let messages: [Message]
    let stream: Bool
}

struct ErrorRootResponse: Decodable {
    let error: ErrorResponse
}

struct ErrorResponse: Decodable {
    let message: String
    let type: String?
}

struct StreamCompletionResponse: Decodable {
    let choices: [StreamChoice]
}

struct CompletionResponse: Decodable {
    let choices: [Choice]
    let usage: Usage?
}

struct Usage: Decodable {
    let promptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

struct Choice: Decodable {
    let message: Message
    let finishReason: String?
}

struct StreamChoice: Decodable {
    let finishReason: String?
    let delta: StreamMessage
}

struct StreamMessage: Decodable {
    let role: String?
    let content: String?
}

struct ParserResult: Identifiable {
    
    let id = UUID()
    let attributedString: AttributedString
    let isCodeBlock: Bool
    let codeBlockLanguage: String?
    
}

actor ResponseParsingTask {
    
    func parse(text: String) async -> String {
        return text
    }
    
}
