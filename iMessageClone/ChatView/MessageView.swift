//
//  MessageView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 06/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI

struct Message: Hashable {
    var id: String
    var content: String
    var user: User
}

struct User: Hashable {
    var name: String
    var avatarUrl: URL?
    var isCurrentUser: Bool = false
}

struct MessageView : View {
    var message: Message
    var body: some View {
        HStack(alignment: .bottom, spacing: 15) {
            if !message.user.isCurrentUser {
                RemoteImage(message.user.avatarUrl)
                    .frame(width: 40, height: 40, alignment: .center)
                    .cornerRadius(20)
            } else {
                Spacer()
            }
            ContentMessageView(
                contentMessage: message.content,
                isCurrentUser: message.user.isCurrentUser
            )
            if !message.user.isCurrentUser {
                Spacer()
            }
        }
        .padding(.trailing, /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
        .padding(.leading, /*@START_MENU_TOKEN@*/10/*@END_MENU_TOKEN@*/)
    }
}

struct ContentMessageView: View {
    var contentMessage: String
    var isCurrentUser: Bool
    
    var body: some View {
        Text(contentMessage)
            .padding(10)
            .foregroundColor(isCurrentUser ? Color.white : Color.black)
            .background(isCurrentUser ? Color.blue : Color(
                UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)
            ))
            .cornerRadius(10)
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        MessageView(
            message: Message(
                id: "123",
                content: "There are a lot of premium iOS templates on iosapptemplates.com",
                user: .init(name: "Nuno", avatarUrl: nil)
            )
        ).previewLayout(.sizeThatFits)
    }
}

struct ContentMessageView_Previews: PreviewProvider {
    static var previews: some View {
        ContentMessageView(
            contentMessage: "Hi, I am your friend",
            isCurrentUser: false
        ).previewLayout(.sizeThatFits)
    }
}
