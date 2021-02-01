//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
@testable import StreamChatUI
import XCTest

class ChatChannelListVC_SnapshotTests: XCTestCase {
    var view: ChatChannelListItemView!
    var vc: ChatChannelListVC!
    var mockedChannelListController: ChatChannelListController_Mock<NoExtraData>!
    
    override func setUp() {
        super.setUp()
        UIConfig.default.channelList.channelListItemSubviews.avatarView = MockAvatarView.self
        UIConfig.default.currentUser.currentUserViewAvatarView = MockCurrentChatUserAvatarView.self
        vc = ChatChannelListVC()
        mockedChannelListController = ChatChannelListController_Mock.mock()
        vc.controller = mockedChannelListController
    }
    
    func test_populated() {
        mockedChannelListController.simulate(
            channels: [
                .mock(
                    cid: .init(type: .messaging, id: "test_channel1"),
                    name: "Channel 1",
                    lastMessageAt: .init(timeIntervalSince1970: 1_611_951_526_000)
                ),
                .mock(
                    cid: .init(type: .messaging, id: "!members:test_channel2"),
                    name: "Channel 2",
                    lastMessageAt: .init(timeIntervalSince1970: 1_611_951_527_000),
                    members: [.mock(id: "luke", name: "Luke Skywalker", isOnline: true)]
                ),
                .mock(
                    cid: .init(type: .messaging, id: "test_channel3"),
                    name: "Channel 3",
                    lastMessageAt: .init(timeIntervalSince1970: 1_611_951_528_000),
                    unreadCount: ChannelUnreadCount(messages: 4, mentionedMessages: 2),
                    latestMessages: [
                        ChatMessage.mock(
                            id: "1", text: "This is a long message. How the UI will adjust?", author: .mock(id: "Vader2")
                        )
                    ]
                ),
                .mock(
                    cid: .init(type: .messaging, id: "test_channel4"),
                    name: "Channel 4",
                    lastMessageAt: .init(timeIntervalSince1970: 1_611_951_529_000),
                    latestMessages: [
                        ChatMessage.mock(id: "2", text: "Hello", author: .mock(id: "Vader")),
                        ChatMessage.mock(id: "1", text: "Hello2", author: .mock(id: "Vader2"))
                    ]
                )
            ],
            changes: []
        )
        AssertSnapshot(vc, isEmbededInNavigationController: true)
    }
    
    func test_empty() {
        // TODO, no empty states implemented yet.
    }
}
