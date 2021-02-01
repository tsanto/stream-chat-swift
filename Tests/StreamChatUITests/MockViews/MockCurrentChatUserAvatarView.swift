//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

@testable import StreamChatUI
import XCTest

class MockCurrentChatUserAvatarView: CurrentChatUserAvatarView {
    override func updateContent() {
        super.updateContent()
        avatarView.imageView.image = UIImage(named: "pattern2", in: .streamChatUI)
    }
}
