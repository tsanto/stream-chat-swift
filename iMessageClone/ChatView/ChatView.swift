//
//  ChatView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 06/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI

struct ChatView: View {
    
    @State private var typingMessage: String = ""
    @State private var dummyData: [Message] = [
        Message(content: "Hello Friend", user: .init(name: "Yoda")),
        Message(content: "Hello!", user: .init(name: "Nuno", isCurrentUser: true)),
        Message(content: "Hello2!", user: .init(name: "Nuno", isCurrentUser: true))
    ]
    
    let channelName: String
    
    var body: some View {
        VStack {
            ScrollView {
                LazyVStack {
                    ForEach(dummyData, id: \.self) { msg in
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
        let newMessage = Message(
            content: typingMessage,
            user: .init(name: "Nuno", isCurrentUser: true)
        )
        dummyData.append(newMessage)
        typingMessage = ""
    }
}


struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView(channelName: "Order 66")
        }
    }
}
