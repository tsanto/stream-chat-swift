//
//  ChatView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 06/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI
import StreamChat

struct ChatContainerView: View {
    @ObservedObject var chatController: ChatChannelController.ObservableObject
    
    var body: some View {
        let messages = chatController.messages.map { message -> Message in
            return Message(
                id: message.id,
                content: message.text,
                user: User(
                    name: message.author.name ?? "",
                    avatarUrl: message.author.imageURL,
                    isCurrentUser: message.author.id == ChatClient.shared.currentUserId
                )
            )
        }
        ChatView(channelName: chatController.channel?.name ?? "", messages: messages)
    }
}

struct ChatView: View {
    
    @State private var typingMessage: String = ""
    
    let channelName: String
    var messages: [Message]
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    ForEach(messages, id: \.self) { msg in
                        MessageView(message: msg)
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
        print("Send Message")
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
            ChatView(channelName: "Order 66", messages: dummyData)
        }
    }
}
