//
//  ChatView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 06/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI
import StreamChat

struct ChatView: View {
    
    @State private var typingMessage: String = ""
    
    let channelName: String
    var messages: [Message]
    let newMessageAction: (String) -> Void
    
    var body: some View {
        VStack {
            ScrollView {
                ScrollViewReader { scrollView in
                    LazyVStack {
                        ForEach(messages, id: \.id) { msg in
                            MessageView(message: msg).id(msg.id)
                        }
                        .onChange(of: messages) { messages in
                            withAnimation(.easeInOut(duration: 0.250)) {
                                scrollView.scrollTo(messages.last?.id)
                            }
                        }
                    }
                }
            }
            MessageComposerView(
                typingMessage: $typingMessage,
                action: sendMessage
            )
        }.navigationTitle(channelName)
    }
    
    func sendMessage() {
        guard !typingMessage.isEmpty else { return }
        newMessageAction(typingMessage)
        typingMessage = ""
    }
}


struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            let dummyData: [Message] = [
                Message(id: "1", content: "Hello Friend", user: .init(name: "Yoda")),
                Message(id: "2", content: "Hello!", user: .init(name: "Nuno", isCurrentUser: true)),
                Message(id: "3", content: "Hello2!", user: .init(name: "Nuno", isCurrentUser: true))
            ]
            ChatView(channelName: "Order 66", messages: dummyData, newMessageAction: { _ in })
        }
    }
}
