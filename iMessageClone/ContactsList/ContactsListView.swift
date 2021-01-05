//
//  ContactsListView.swift
//  iMessageClone
//
//  Created by Nuno Vieira on 05/01/2021.
//  Copyright © 2021 Stream.io Inc. All rights reserved.
//

import SwiftUI
import StreamChat

struct ContactsListView: View {
    @ObservedObject var channelList: ChatChannelListController.ObservableObject
    
    init() {
        let chatClient = ChatClient.shared
        let channelListController = chatClient.channelListController(
            query: ChannelListQuery(filter: .in("members", values: [chatClient.currentUserId]))
        )
        channelList = channelListController.observableObject
    }
    
    var body: some View {
        List(channelList.channels, id: \.self) { channel in
            let latestMessage = channel.latestMessages.last
            ContactsListCell(
                details: ContactsListCell.Details(
                    name: channel.name ?? "",
                    msg: latestMessage?.text ?? "",
                    date: "latestMessage!.createdAt",
                    imageUrl: latestMessage?.author.imageURL
                )
            )
        }
        .navigationTitle("Messages")
        .onAppear {
            channelList.controller.synchronize()
        }
    }
}

struct ContactsListCell : View {
    var details: Details
    
    var body: some View {
        HStack(spacing: 12){
            RemoteImage(withURL: details.imageUrl)
                .frame(width: 55, height: 55)
                .cornerRadius(50)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(details.name).bold()
                    Spacer()
                    Text(details.date)
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding()
                }.frame(height: 30)
                
                Text(details.msg)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer(minLength: 0)
        }.padding(.vertical)
    }
}

extension ContactsListCell {
    struct Details {
        var name: String
        var msg: String
        var date: String
        var imageUrl: URL?
    }
}

struct ContactsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContactsListView()
        }
    }
}

struct ContactsListCellView_Previews: PreviewProvider {
    static var previews: some View {
        ContactsListCell(
            details: .init(
                name: "Nuno Vieira",
                msg: "Hello friend!",
                date: "23 days ago",
                imageUrl: URL(string: "")
            )
        ).previewLayout(.sizeThatFits)
    }
}
