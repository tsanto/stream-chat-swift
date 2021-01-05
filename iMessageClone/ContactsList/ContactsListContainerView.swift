//
//  ContactsListContainerView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 05/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI
import StreamChat

struct ContactsListContainerView: View {
    var body: some View {
        let chatClient = ChatClient.shared
        let channelListController = chatClient.channelListController(
            query: ChannelListQuery(filter: .in("members", values: [chatClient.currentUserId]))
        )
        let channelList = channelListController.observableObject
        ContactsListView(channelList: channelList)
    }
}
