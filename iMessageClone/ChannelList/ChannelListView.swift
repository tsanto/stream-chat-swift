//
//  ContactsListView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 05/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI
import StreamChat

struct ChannelListView: View {
    @ObservedObject var channelList: ChatChannelListController.ObservableObject
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()
    
    init(channelList: ChatChannelListController.ObservableObject) {
        self.channelList = channelList
    }
    
    var body: some View {
        List(channelList.channels, id: \.name) { channel in
            let latestMessage = channel.latestMessages.first
            let name = channel.name ?? ""
            let msg = latestMessage?.text ?? ""
            let imageUrl = latestMessage?.author.imageURL
            let date = latestMessage?.createdAt ?? Date()
            let dateFormatted = dateFormatter.string(from: date)
            let channelItem = ChannelListItem(
                name: name,
                msg: msg,
                date: dateFormatted,
                imageUrl: imageUrl
            )
            let chatController = channelList.controller.client
                .channelController(for: channel.cid)
                .observableObject
            NavigationLink(destination: ChatContainerView(chatController: chatController)) {
                ChannelListCell(
                    item: channelItem
                )
            }
        }
        .navigationTitle("Messages")
        .onAppear {
            channelList.controller.synchronize()
        }
    }
}

struct ChannelListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            let chatClient = ChatClient.shared
            let channelListController = chatClient.channelListController(
                query: ChannelListQuery(filter: .in("members", values: [chatClient.currentUserId]))
            )
            let channelList = channelListController.observableObject
            ChannelListView(channelList: channelList)
        }
    }
}
