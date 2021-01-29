//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

public typealias ChatChannelVC = _ChatChannelVC<NoExtraData>

open class _ChatChannelVC<ExtraData: ExtraDataTypes>: _ChatVC<ExtraData> {
    // MARK: - Properties

    public private(set) lazy var router = uiConfig.navigation.channelDetailRouter.init(rootViewController: self)
    public var controller: _LazyChatChannelController<ExtraData>!
    
    // MARK: - Life Cycle
    
    override open func setUp() {
        super.setUp()

        controller.setDelegate(self)
        controller.synchronize()
    }

    override func makeNavbarListener(
        _ handler: @escaping (ChatChannelNavigationBarListener<ExtraData>.NavbarData) -> Void
    ) -> ChatChannelNavigationBarListener<ExtraData>? {
        nil
//        guard let channel = channelController.channel else { return nil }
//        let namer = uiConfig.messageList.channelNamer.init()
//        let navbarListener = ChatChannelNavigationBarListener.make(for: channel.cid, in: channelController.client, using: namer)
//        navbarListener.onDataChange = handler
//        return navbarListener
    }

    override public func defaultAppearance() {
        super.defaultAppearance()

        return

//        guard let channel = channelController.channel else { return }
//
//        let avatar = _ChatChannelAvatarView<ExtraData>()
//        avatar.translatesAutoresizingMaskIntoConstraints = false
//        avatar.heightAnchor.pin(equalToConstant: 32).isActive = true
//        avatar.channelAndUserId = (channel, channelController.client.currentUserId)
//        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: avatar)
//        navigationItem.largeTitleDisplayMode = .never
    }

    // MARK: - ChatMessageListVCDataSource

    override public func numberOfMessagesInChatMessageListVC(_ vc: _ChatMessageListVC<ExtraData>) -> Int {
        controller.numberOfItems
    }

    override public func chatMessageListVC(_ vc: _ChatMessageListVC<ExtraData>, messageAt index: Int) -> _ChatMessage<ExtraData> {
        controller.item(at: index)!
    }

    override public func loadMoreMessagesForChatMessageListVC(_ vc: _ChatMessageListVC<ExtraData>) {
        controller.loadNextMessages()
//        channelController.loadNextMessages()
    }

    override public func chatMessageListVC(
        _ vc: _ChatMessageListVC<ExtraData>,
        replyMessageFor message: _ChatMessage<ExtraData>,
        at index: Int
    ) -> _ChatMessage<ExtraData>? {
        message.quotedMessageId.flatMap { controller.dataStore.message(id: $0) }
    }

    override public func chatMessageListVC(
        _ vc: _ChatMessageListVC<ExtraData>,
        controllerFor message: _ChatMessage<ExtraData>
    ) -> _ChatMessageController<ExtraData> {
        controller.client.messageController(
            cid: controller.cid!,
            messageId: message.id
        )
    }

    // MARK: - ChatMessageListVCDelegate

    override public func chatMessageListVC(
        _ vc: _ChatMessageListVC<ExtraData>,
        didTapOnRepliesFor message: _ChatMessage<ExtraData>
    ) {
//        router.showThreadDetail(for: message, within: channelController)
    }
}

// MARK: - _ChatChannelControllerDelegate

extension _ChatChannelVC: _LazyChatChannelControllerDelegate {
    public func lazyChannelController(
        _ channelController: _LazyChatChannelController<ExtraData>,
        didUpdateMessages changes: [ErasedChange]
    ) {
        messageList.updateMessages(with: changes)
    }
}
