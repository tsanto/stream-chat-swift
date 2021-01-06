//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import UIKit

///
/// Reference:
/// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html
///
extension UITextView {
    func calculatedTextHeight2() -> CGFloat {
        // Height is not calculated correctly with empty text
        let string: String = text.isEmpty ? " " : text
        let customTextStorage = NSTextStorage(string: string)
        let width = frame.width - textContainerInset.right - textContainerInset.left
        let customTextContainer = NSTextContainer(size: .init(width: width, height: CGFloat.greatestFiniteMagnitude))
        let customLayoutManager = NSLayoutManager()
        
        customLayoutManager.addTextContainer(customTextContainer)
        
        customTextStorage.addLayoutManager(customLayoutManager)
        customTextStorage.addAttribute(.font, value: font!, range: .init(0..<customTextStorage.length))
        
        customTextContainer.lineFragmentPadding = textContainer.lineFragmentPadding
        customTextContainer.maximumNumberOfLines = textContainer.maximumNumberOfLines
        customTextContainer.lineBreakMode = textContainer.lineBreakMode
        
        customLayoutManager.glyphRange(for: customTextContainer)
        
        return customLayoutManager.usedRect(for: customLayoutManager.textContainers.first!).size.height
    }
    
    func simulatedContainers(for string: String) -> (NSLayoutManager, NSTextContainer, NSTextStorage) {
        let customTextStorage = NSTextStorage(string: string)
        let width = frame.width - textContainerInset.right - textContainerInset.left
        let customTextContainer = NSTextContainer(size: .init(width: width, height: CGFloat.greatestFiniteMagnitude))
        let customLayoutManager = NSLayoutManager()

        customLayoutManager.addTextContainer(customTextContainer)
        
        customTextStorage.addLayoutManager(customLayoutManager)
        customTextStorage.addAttribute(.font, value: font!, range: .init(0..<customTextStorage.length))
        
        customTextContainer.lineFragmentPadding = textContainer.lineFragmentPadding
        customTextContainer.maximumNumberOfLines = textContainer.maximumNumberOfLines
        customTextContainer.lineBreakMode = textContainer.lineBreakMode
        
        customLayoutManager.glyphRange(for: customTextContainer)
        
        return (customLayoutManager, customTextContainer, customTextStorage)
    }
    
    func calculatedTextHeight() -> CGFloat {
        // Height is not calculated correctly with empty text
        let string: String = text.isEmpty ? " " : text
        // If I replace it with _ it will be deallocated
        // let (layoutManager, textContainer, textStorage) = simulatedContainers(for: string)
        let simulated = simulatedContainers(for: string)
        
        return simulated.0.usedRect(for: simulated.1).size.height
    }
    
    func heightFor(numberOfLines: Int) -> CGFloat {
        let string = Array(repeating: "A", count: 1000).joined()
        let (layoutManager, textContainer, _) = simulatedContainers(for: string)

        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.lineBreakMode = .byTruncatingTail
                
        return layoutManager.usedRect(for: textContainer).size.height
    }
    
    func numberOfLines() -> Int {
        let (layoutManager, _, _) = simulatedContainers(for: text)
        
        var lineRange: NSRange = .init()
        var index = 0
        var numberOfLines = 0
                
        while index < layoutManager.numberOfGlyphs {
            layoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
            index = NSMaxRange(lineRange)
            numberOfLines += 1
        }
        
        return numberOfLines
    }
}
