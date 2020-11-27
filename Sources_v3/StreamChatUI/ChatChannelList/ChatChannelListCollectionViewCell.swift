//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Foundation
import UIKit

open class ChatChannelListCollectionViewCell<ExtraData: UIExtraDataTypes>: UICollectionViewCell {
    // MARK: - Properties

    var uiConfig: UIConfig<ExtraData> = .default

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView(frame: .zero)
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()

    public private(set) lazy var channelView: ChatChannelListItemView<ExtraData> = {
        let width = UIApplication.shared.keyWindow!.bounds.width
        let view = uiConfig.channelList.channelListItemView.init(uiConfig: uiConfig)
        view.pin(anchors: [.width], to: width)
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.addArrangedSubview(view)
        stackView.addArrangedSubview(deleteView)

        contentView.embed(scrollView)
        contentView.backgroundColor = .yellow
        scrollView.embed(stackView)
        stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: 1.2).isActive = true
        return view
    }()

    public private(set) lazy var deleteView: UIButton = {
        let button = UIButton()
        if #available(iOS 13.0, *) {
            button.setImage(UIImage(systemName: "trash"), for: .normal)
        }
        let width = UIApplication.shared.keyWindow!.bounds.width
        button.addTarget(self, action: #selector(handleCellDelete), for: .touchUpInside)
        // Multiplier for stackview width is 1.2 so it's 1/5 of the screen now.
        button.pin(anchors: [.width], to: width / 5)
        button.backgroundColor = .red
        return button
    }()

    // MARK: - Actions

    @objc func handleCellDelete() {}

    // MARK: - Layout
    
    override open func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let preferredAttributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        
        let targetSize = CGSize(
            width: layoutAttributes.frame.width,
            height: UIView.layoutFittingCompressedSize.height
        )
        
        preferredAttributes.frame.size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        return preferredAttributes
    }
}
