//
//  ViewModel.swift
//  RAG_v01
//
//  Created by Danika Gupta on 11/4/23.
//

import SwiftUI

class ViewModel: ObservableObject {
    
    @Published var isInteracting = false
    @Published var messages: [MessageRow] = []
    @Published var inputMessage: String = ""
    var task: Task<Void, Never>?
    
    
    private var api: LLMClient
    
    var title: String {
        "Helpful Chat"
    }

    
    init(api: LLMClient, enableSpeech: Bool = false) {
        self.api = api
    }
    
    func updateClient() {
        self.messages = []
    }
    
    @MainActor
    func sendTapped() async {
        self.task = Task {
            let text = inputMessage
            inputMessage = ""
            await sendAttributedWithoutStream(text: text)
        }
    }
    
    @MainActor
    func clearMessages() {
        api.deleteHistoryList()
        withAnimation { [weak self] in
            self?.messages = []
        }
    }
    
    @MainActor
    func retry(message: MessageRow) async {
        self.task = Task {
            guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
                return
            }
            self.messages.remove(at: index)
            await sendAttributedWithoutStream(text: message.sendText)
        }
    }
    
    func cancelStreamingResponse() {
        self.task?.cancel()
        self.task = nil
    }
    
    @MainActor
    private func sendAttributedWithoutStream(text: String) async {
        isInteracting = true
        var messageRow = MessageRow(
            isInteracting: true,
            sendImage: "person",
            send: text,
            responseImage: "openai",
            response: "",
            responseError: nil)
        
        self.messages.append(messageRow)
        
        do {
            let responseText = try await api.sendMessage(text)
            try Task.checkCancellation()
            
            let parsingTask = ResponseParsingTask()
            let output = await parsingTask.parse(text: responseText)
            try Task.checkCancellation()
            
            messageRow.response = output
            
        } catch {
            messageRow.responseError = error.localizedDescription
        }
        
        messageRow.isInteracting = false
        self.messages[self.messages.count - 1] = messageRow
        isInteracting = false
    }
    
    @MainActor
    private func sendWithoutStream(text: String) async {
        isInteracting = true
        var messageRow = MessageRow(
            isInteracting: true,
            sendImage: "person",
            send: text,
            responseImage: "openai",
            response: "",
            responseError: nil)
        
        self.messages.append(messageRow)
        
        do {
            let responseText = try await api.sendMessage(text)
            try Task.checkCancellation()
            messageRow.response = responseText
        } catch {
            messageRow.responseError = error.localizedDescription
        }
        
        messageRow.isInteracting = false
        self.messages[self.messages.count - 1] = messageRow
        isInteracting = false
    }
    

    
}
