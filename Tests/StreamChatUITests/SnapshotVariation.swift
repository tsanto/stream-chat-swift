//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

@testable import StreamChatUI
import XCTest

enum SnapshotVariation: String, Hashable, CaseIterable {
    case small
    case medium
    case large
    case extraLarge
    case extraExtraExtraLarge
    case light
    case dark
    
    var trait: UITraitCollection {
        switch self {
        case .small: return UITraitCollection(preferredContentSizeCategory: .small)
        case .medium: return UITraitCollection(preferredContentSizeCategory: .medium)
        case .large: return UITraitCollection(preferredContentSizeCategory: .large)
        case .extraLarge: return UITraitCollection(preferredContentSizeCategory: .extraLarge)
        case .extraExtraExtraLarge: return UITraitCollection(preferredContentSizeCategory: .extraExtraExtraLarge)
        case .light: return UITraitCollection(userInterfaceStyle: .light)
        case .dark: return UITraitCollection(userInterfaceStyle: .dark)
        }
    }
}
