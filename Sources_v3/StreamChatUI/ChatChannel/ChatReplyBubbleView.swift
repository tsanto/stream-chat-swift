//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

open class ChatReplyBubbleView<ExtraData: ExtraDataTypes>: View, UIConfigProvider {
    // MARK: - Properties
    
    public var avatarViewWidth: CGFloat = 24
    public var attachmentPreviewWidth: CGFloat = 34
    
    public var message: _ChatMessage<ExtraData>? {
        didSet {
            updateContentIfNeeded()
        }
    }
    
    lazy var textViewHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 12).priority()
    
    // MARK: - Subviews
    
    public private(set) lazy var container = ContainerStackView()
        .withoutAutoresizingMaskConstraints
    
    public private(set) lazy var authorAvatarView = uiConfig
        .messageComposer
        .replyBubbleAvatarView.init()
        .withoutAutoresizingMaskConstraints
    
    public private(set) lazy var attachmentPreview = UIImageView()
        .withoutAutoresizingMaskConstraints

    public private(set) lazy var textView = UITextView()
        .withoutAutoresizingMaskConstraints
    
    // MARK: - Public
    
    override open func setUp() {
        super.setUp()
        
        textView.isEditable = false
        textView.dataDetectorTypes = .link
        textView.isScrollEnabled = false
        textView.adjustsFontForContentSizeCategory = true
        textView.isUserInteractionEnabled = false
    }
    
    override open func defaultAppearance() {
        textView.textContainer.maximumNumberOfLines = 6
        textView.textContainer.lineBreakMode = .byTruncatingTail
        textView.textContainer.lineFragmentPadding = .zero
        
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .footnote)
        textView.textContainerInset = .zero

        authorAvatarView.contentMode = .scaleAspectFit
        
        attachmentPreview.layer.cornerRadius = attachmentPreviewWidth / 4
        attachmentPreview.layer.masksToBounds = true
        
        container.centerStackView.layer.cornerRadius = 16
        container.centerStackView.layer.borderWidth = 1
        container.centerStackView.layer.borderColor = uiConfig.colorPalette.messageComposerBorder.cgColor
        container.centerStackView.layer.masksToBounds = true
    }
    
    override open func setUpLayout() {
        embed(container)
        
        preservesSuperviewLayoutMargins = true
        
        container.preservesSuperviewLayoutMargins = true
        container.isLayoutMarginsRelativeArrangement = true
        
        container.leftStackView.isHidden = false
        container.leftStackView.addArrangedSubview(authorAvatarView)
        authorAvatarView.widthAnchor.constraint(equalToConstant: avatarViewWidth).priority().isActive = true
        authorAvatarView.heightAnchor.constraint(equalToConstant: avatarViewWidth).priority().isActive = true
        
        container.centerContainerStackView.spacing = UIStackView.spacingUseSystem
        container.centerContainerStackView.alignment = .bottom
        
        container.centerStackView.isLayoutMarginsRelativeArrangement = true
        container.centerStackView.layoutMargins = layoutMargins
        
        container.centerStackView.isHidden = false
        container.centerStackView.spacing = UIStackView.spacingUseSystem
        container.centerStackView.alignment = .top
        container.centerStackView.addArrangedSubview(attachmentPreview)

        attachmentPreview.widthAnchor.constraint(equalToConstant: attachmentPreviewWidth).priority().isActive = true
        attachmentPreview.heightAnchor.constraint(equalToConstant: attachmentPreviewWidth).priority().isActive = true

        container.centerStackView.addArrangedSubview(textView)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textViewHeightConstraint.isActive = true
        
        container.centerStackView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner
        ]
    }
    
    override open func updateContent() {
        guard let message = message else { return }
        
        let placeholder = UIImage(named: "pattern1", in: .streamChatUI)
        if let imageURL = message.author.imageURL {
            authorAvatarView.imageView.setImage(from: imageURL, placeholder: placeholder)
        } else {
            authorAvatarView.imageView.image = placeholder
        }
        
        textView.text = message.text
        
        updateAttachmentPreview(for: message)
        
      //  setNeedsLayout()
        
        textViewHeightConstraint.constant = textView.calculatedTextHeight()
    }
    
    // MARK: - Helpers
    
    func updateAttachmentPreview(for message: _ChatMessage<ExtraData>) {
        // TODO: Take last attachment when they'll be ordered.
        guard let attachment = message.attachments.first else {
            attachmentPreview.image = nil
            attachmentPreview.isHidden = true
            return
        }
        
        switch attachment.type {
        case .file:
            // TODO: Question for designers.
            // I'm not sure if it will be possible to provide specific icon for all file formats
            // so probably we should stick to some generic like other apps do.
            print("set file icon")
            attachmentPreview.isHidden = false
            attachmentPreview.contentMode = .scaleAspectFit
        default:
            if let previewURL = attachment.imagePreviewURL ?? attachment.imageURL {
                attachmentPreview.setImage(from: previewURL)
                attachmentPreview.isHidden = false
                attachmentPreview.contentMode = .scaleAspectFill
                // TODO: When we will have attachment examples we will set smth
                // different for different types.
                if message.text.isEmpty, attachment.type == .image {
                    textView.text = "Photo"
                }
            } else {
                attachmentPreview.image = nil
                attachmentPreview.isHidden = true
            }
        }
    }
}

extension NSLayoutConstraint {
    func priority(_ priority: Float = 998) -> NSLayoutConstraint {
        let constraint = self
        constraint.priority = .init(priority)
        return constraint
    }
}

extension UIStackView {
    var embeded: UIView {
        let view = UIView()
        view.addSubview(self)
        
        let bottomConstraint = bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
        bottomConstraint.priority = .init(998)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
            topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
            bottomConstraint
        ])
        
        return view
    }
}

func testEmbeded(sv: UIStackView) -> UIView {
    let view = UIView()
    view.addSubview(sv)
    
    let bottomConstraint = sv.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 0)
    bottomConstraint.priority = .init(998)
    NSLayoutConstraint.activate([
        sv.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
        sv.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 0),
        sv.topAnchor.constraint(equalTo: view.topAnchor, constant: 0),
        bottomConstraint
    ])
    
    return view
}
