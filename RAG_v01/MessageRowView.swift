//
//  MessageRowView.swift
//  RAG_v01
//
//  Created by Danika Gupta on 11/4/23.
//

import SwiftUI

struct MessageRowView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    let message: MessageRow
    let retryCallback: (MessageRow) -> Void
    
    var imageSize: CGSize {
        #if os(iOS) || os(macOS)
        CGSize(width: 25, height: 25)
        #elseif os(watchOS)
        CGSize(width: 20, height: 20)
        #else
        CGSize(width: 80, height: 80)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            messageRow(rowType: message.send, image: message.sendImage, bgColor: colorScheme == .light ? .white : Color(red: 52/255, green: 53/255, blue: 65/255, opacity: 0.5))
            
            if let response = message.response {
                Divider()
                messageRow(rowType: response, image: message.responseImage, bgColor: colorScheme == .light ? .gray.opacity(0.1) : Color(red: 52/255, green: 53/255, blue: 65/255, opacity: 1), responseError: message.responseError, showDotLoading: message.isInteracting)
                Divider()
            }
        }
    }
    
    func messageRow(rowType: String, image: String, bgColor: Color, responseError: String? = nil, showDotLoading: Bool = false) -> some View {
        #if os(watchOS)
        VStack(alignment: .leading, spacing: 8) {
            messageRowContent(rowType: rowType, image: image, responseError: responseError, showDotLoading: showDotLoading)
        }
        
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        #else
        HStack(alignment: .top, spacing: 24) {
            messageRowContent(rowType: rowType, image: image, responseError: responseError, showDotLoading: showDotLoading)
        }
        #if os(tvOS)
        .padding(32)
        #else
        .padding(16)
        #endif
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgColor)
        #endif
    }
    
    @ViewBuilder
    func messageRowContent(rowType: String, image: String, responseError: String? = nil, showDotLoading: Bool = false) -> some View {
        if image.hasPrefix("http"), let url = URL(string: image) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .frame(width: imageSize.width, height: imageSize.height)
            } placeholder: {
                ProgressView()
            }

        } else {
            Image(image)
                .resizable()
                .frame(width: imageSize.width, height: imageSize.height)
        }
        
        VStack(alignment: .leading) {
            Text(rowType)

            
            if showDotLoading {
                DotLoadingView()
                    .frame(width: 60, height: 30)
                
            }
        }
    }
    
    func attributedView(results: [ParserResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(results) { parsed in
                    Text(parsed.attributedString)
            }
        }
    }
    
}

struct MessageRowView_Previews: PreviewProvider {
    
    static let message = MessageRow(
        isInteracting: true, sendImage: "person",
        send: "What is SwiftUI?",
        responseImage: "openai",
        response: "Test message: ChatGPT is working as expected")
    
    static let message2 = MessageRow(
        isInteracting: false, sendImage: "person",
        send: "What is SwiftUI?",
        responseImage: "openai",
        response: "",
        responseError: "Test message 2 : ChatGPT is currently not available")
        
    static var previews: some View {
        NavigationStack {
            ScrollView {
                MessageRowView(message: message, retryCallback: { messageRow in
                    
                })
                    
                MessageRowView(message: message2, retryCallback: { messageRow in
                    
                })
                  
            }
            .previewLayout(.sizeThatFits)
        }
    }
    
}

import SwiftUI

struct AttributedOutput {
    let string: String
    let results: String
}

struct MessageRow: Identifiable {
    
    let id = UUID()
    
    var isInteracting: Bool
    
    let sendImage: String
    var send: String
    var sendText: String {
        send
    }
    
    let responseImage: String
    var response: String?
    var responseText: String? {
        response
    }
    
    var responseError: String?
    
}
