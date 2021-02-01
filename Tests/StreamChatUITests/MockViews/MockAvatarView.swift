//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

@testable import StreamChatUI
import XCTest

class MockAvatarView: ChatChannelAvatarView {
    override func updateContent() {
        super.updateContent()
        imageView.image = UIImage(named: "pattern1", in: .streamChatUI)
    }
}
