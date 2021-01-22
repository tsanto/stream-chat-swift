//
//  ContentView.swift
//  SwiftUI_Demo
//
//  Created by Dominik Bucher on 22.01.2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI
import StreamChat

struct ContentView: View {
    var body: some View {
        Chat(
            client: ChatClient(
                config: ChatClientConfig(apiKey: APIKey(Configuration.apiKey)),
                tokenProvider: .anonymous
            )
        )
    }
}
/// Shows the list of channels when the current user is a member
struct Chat: View {
    @StateObject var channelList: ChatChannelListController.ObservableObject

    init(client: ChatClient) {
        channelList = client.channelListController(query: .init(filter: .containMembers(userIds: ["UserId"]))).observableObject
    }

    var body: some View {
        List {
            ForEach(channelList.channels) { channel in
                Text(channel.name)
            }

        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
