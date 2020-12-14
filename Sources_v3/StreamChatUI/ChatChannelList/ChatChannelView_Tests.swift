//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import SnapshotTesting
import StreamChat
@testable import StreamChatUI
import XCTest

class ChatChannelView_Tests: XCTestCase {
    var view: ChatChannelListItemView<DefaultExtraData>!
    
    override func setUp() {
        super.setUp()
        view = ChatChannelListItemView(channel: nil, uiConfig: .default)
    }
    
    func test_defaultAppearance() {
        view.channelAndUserId = (channel: ChatChannel.mock(
            cid: .init(type: .messaging, id: "test_channel")
        ), currentUserId: nil)
                
        AssertSnapshot(view, explicitWidth: 500)
    }
}

func AssertSnapshot(
    _ view: UIView,
    _ name: String? = nil,
    explicitWidth width: CGFloat? = nil,
    explicitHeight height: CGFloat? = nil,
    traits: [UITraitCollection] = UITraitCollection.fullMatrix,
    record: Bool = false,
    line: UInt = #line,
    file: StaticString = #file,
    function: String = #function
) {
    view.translatesAutoresizingMaskIntoConstraints = false

    if let width = width {
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
    }

    if let height = height {
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
    }
    
    traits.forEach { traits in
        assertSnapshot(
            matching: view,
            as: .image(traits: traits),
            named: traits.snapshotName,
            file: file,
            testName: function,
            line: line
        )
    }
    
    view.tintColor = .red
    
    assertSnapshot(
        matching: view,
        as: .image(traits: .scale),
        named: "redTint",
        file: file,
        testName: function,
        line: line
    )
}

extension UITraitCollection {
    static let scale: UITraitCollection = UITraitCollection(displayScale: 1)
    
    static var fullMatrix: [UITraitCollection] = {
        let scale: UITraitCollection = UITraitCollection(displayScale: 1)
        
        let contentSize: [UITraitCollection] = [
            UITraitCollection(preferredContentSizeCategory: .small).named("S"),
            UITraitCollection(preferredContentSizeCategory: .large),
            UITraitCollection(preferredContentSizeCategory: .extraLarge).named("XL")
        ]
        
        return contentSize.map {
            let traits = [$0, scale]
            return UITraitCollection(traitsFrom: traits).named(traits.snapshotName)
        }
    }()
}

extension Array where Element == UITraitCollection {
    var snapshotName: String? {
        let name = compactMap(\.snapshotName)
            .sorted()
            .joined(separator: "_")
        
        return name.isEmpty ? nil : name
    }
}

private extension UITraitCollection {
    private static var _snapshotNameKey: UInt8 = 0
    
    var snapshotName: String? {
        get { objc_getAssociatedObject(self, &Self._snapshotNameKey) as? String }
        set { objc_setAssociatedObject(self, &Self._snapshotNameKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

extension UITraitCollection {
    func named(_ name: String?) -> Self {
        snapshotName = name
        return self
    }
}
