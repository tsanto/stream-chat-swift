//
//  ChatContainerView.swift
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
        ChatView(
            channelName: chatController.channel?.name ?? "",
            messages: messages.reversed(),
            newMessageAction: sendNewMessage(_:)
        )
    }
    
    func sendNewMessage(_ message: String) {
        chatController.controller.createNewMessage(text: message)
    }
}
