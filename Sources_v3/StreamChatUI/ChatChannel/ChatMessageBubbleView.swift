//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

open class ChatMessageBubbleView<ExtraData: UIExtraDataTypes>: View, UIConfigProvider {
    struct Layout {
        let text: CGRect?
        let repliedMessage: CGRect?
        /// must be ChatRepliedMessageContentView<ExtraData>.Layout?
        /// but it's circular dependency, swift confused
        let repliesMessageLayout: Any?
        let gallery: CGRect?
        let galleryLayout: ChatMessageImageGallery<ExtraData>.Layout?
        let attachments: [CGRect]
    }

    var layout: Layout? {
        didSet { setNeedsLayout() }
    }

    public var message: _ChatMessageGroupPart<ExtraData>? {
        didSet { updateContent() }
    }

    public let showRepliedMessage: Bool

    // MARK: - Subviews

    public private(set) var attachments: [UIView] = []

    public private(set) lazy var textView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.dataDetectorTypes = .link
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isUserInteractionEnabled = false
        textView.textColor = .black
        return textView
    }()

    public private(set) lazy var imageGallery = uiConfig
        .messageList
        .messageContentSubviews
        .imageGallery
        .init()

    public private(set) lazy var repliedMessageView = showRepliedMessage
        ? uiConfig.messageList.messageContentSubviews.repliedMessageContentView.init()
        : nil

    public private(set) lazy var borderLayer = CAShapeLayer()

    // MARK: - Init

    public required init(showRepliedMessage: Bool) {
        self.showRepliedMessage = showRepliedMessage

        super.init(frame: .zero)
    }

    public required init?(coder: NSCoder) {
        showRepliedMessage = false

        super.init(coder: coder)
    }

    // MARK: - Overrides

    override open func layoutSubviews() {
        super.layoutSubviews()

        borderLayer.frame = layer.bounds

        textView.isHidden = layout?.text == nil
        if let frame = layout?.text {
            textView.frame = frame
        }

        repliedMessageView?.isHidden = layout?.repliedMessage == nil
        if let frame = layout?.repliedMessage {
            repliedMessageView?.frame = frame
        }
        repliedMessageView?.layout = layout?.repliesMessageLayout as? ChatRepliedMessageContentView<ExtraData>.Layout

        imageGallery.isHidden = layout?.gallery == nil
        if let frame = layout?.gallery {
            imageGallery.frame = frame
        }
        imageGallery.layout = layout?.galleryLayout

        if let attachmentFrames = layout?.attachments {
            zip(attachments, attachmentFrames).forEach {
                $0.frame = $1
            }
        }
    }

    override public func defaultAppearance() {
        layer.cornerRadius = 16
        borderLayer.cornerRadius = 16
        borderLayer.borderWidth = 1 / UIScreen.main.scale
    }

    override open func setUpLayout() {
        layer.addSublayer(borderLayer)
        if let reply = repliedMessageView {
            addSubview(reply)
        }
        addSubview(imageGallery)
        addSubview(textView)
    }

    override open func updateContent() {
        repliedMessageView?.message = message?.parentMessage

        textView.text = message?.text

        borderLayer.maskedCorners = corners
        borderLayer.isHidden = message == nil

        borderLayer.borderColor = message?.isSentByCurrentUser == true ?
            UIColor.outgoingMessageBubbleBorder.cgColor :
            UIColor.incomingMessageBubbleBorder.cgColor

        backgroundColor = message?.isSentByCurrentUser == true ? .outgoingMessageBubbleBackground : .incomingMessageBubbleBackground
        layer.maskedCorners = corners

        imageGallery.imageAttachments = message?.attachments
            .filter { $0.type == .image }
            .sorted { $0.imageURL?.absoluteString ?? "" < $1.imageURL?.absoluteString ?? "" } ?? []
        imageGallery.didTapOnAttachment = message?.didTapOnAttachment

        // add attachments subviews
        attachments.forEach { $0.removeFromSuperview() }
        attachments = message?.attachments
            .filter { $0.type != .image }
            .map { _ in
                let view = UIView()
                view.backgroundColor = .purple
                return view
            } ?? []
        attachments.forEach { addSubview($0) }
    }

    // MARK: - Private

    private var corners: CACornerMask {
        var roundedCorners: CACornerMask = [
            .layerMinXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner
        ]

        switch (message?.isLastInGroup, message?.isSentByCurrentUser) {
        case (true, true):
            roundedCorners.remove(.layerMaxXMaxYCorner)
        case (true, false):
            roundedCorners.remove(.layerMinXMaxYCorner)
        default:
            break
        }

        return roundedCorners
    }
}

extension ChatMessageBubbleView {
    class LayoutProvider: ConfiguredLayoutProvider<ExtraData> {
        private struct Wrap: Hashable {
            let text: String
            let width: CGFloat
        }

        let textView: UITextView = ChatMessageBubbleView(showRepliedMessage: false).textView
        private var textCache: [Wrap: CGSize] = [:]
        let gallerySizer = ChatMessageImageGallery<ExtraData>.LayoutProvider()

        /// reply sizer depends on bubble sizer, circle dependency
        /// but bubble inside reply don't need reply sizer so it should be fine as long as you not access it unless needed
        lazy var replySizer = ChatRepliedMessageContentView<ExtraData>.LayoutProvider(parent: self)

        func heightForView(with data: _ChatMessageGroupPart<ExtraData>, limitedBy width: CGFloat) -> CGFloat {
            sizeForView(with: data, limitedBy: width).height
        }

        func sizeForView(with data: _ChatMessageGroupPart<ExtraData>, limitedBy width: CGFloat) -> CGSize {
            let margins = uiConfig.messageList.defaultMargins
            let workWidth = width - 2 * margins

            var spacings = margins

            var replySize: CGSize = .zero
            if data.parentMessageState != nil {
                replySize = replySizer.sizeForView(with: data.parentMessage, limitedBy: workWidth)
                spacings += margins
            }

            var gallerySize: CGSize = .zero
            let images: Array = data.attachments.filter { $0.type == .image }
            if !images.isEmpty {
                gallerySize = gallerySizer.sizeForView(with: images, limitedBy: workWidth)
                spacings += margins
            }

            // put attachments here
            var attachmentsSize: CGSize = .zero
            for attachment in data.attachments where attachment.type != .image {
                attachmentsSize.width = workWidth
                attachmentsSize.height += 50
                spacings += margins
            }

            var textSize: CGSize = .zero
            if !data.text.isEmpty {
                textSize = sizeForText(data.message.text, in: workWidth)
                spacings += margins
            }

            let width = 2 * margins + max(replySize.width, textSize.width, gallerySize.width, attachmentsSize.width)
            let height = spacings + replySize.height + textSize.height + gallerySize.height + attachmentsSize.height
            return CGSize(width: max(width, 32), height: max(height, 32))
        }

        func layoutForView(
            with data: _ChatMessageGroupPart<ExtraData>,
            of size: CGSize
        ) -> Layout {
            let margins = uiConfig.messageList.defaultMargins
            let workWidth = size.width - 2 * margins
            var offsetY = margins

            var replyFrame: CGRect?
            var replyLayout: ChatRepliedMessageContentView<ExtraData>.Layout?
            if data.parentMessageState != nil {
                let replySize = replySizer.sizeForView(with: data.parentMessage, limitedBy: workWidth)
                replyLayout = replySizer.layoutForView(with: data.parentMessage, of: replySize)
                replyFrame = CGRect(origin: CGPoint(x: margins, y: offsetY), size: replySize)
                offsetY += replySize.height
                offsetY += margins
            }

            var galleryFrame: CGRect?
            var galleryLayout: ChatMessageImageGallery<ExtraData>.Layout?
            let images: Array = data.attachments.filter { $0.type == .image }
            if !images.isEmpty {
                let gallerySize = gallerySizer.sizeForView(with: images, limitedBy: workWidth)
                galleryFrame = CGRect(origin: CGPoint(x: margins, y: offsetY), size: gallerySize)
                galleryLayout = gallerySizer.layoutForView(with: images, of: gallerySize)
                offsetY += gallerySize.height
                offsetY += margins
            }

            // put attachments here
            var attachments: [CGRect] = []
            for attachment in data.attachments where attachment.type != .image {
                attachments.append(CGRect(x: margins, y: offsetY, width: workWidth, height: 50))
                offsetY += 50
                offsetY += margins
            }

            let textSize = sizeForText(data.message.text, in: workWidth)
            var textFrame: CGRect?
            if !data.text.isEmpty {
                textFrame = CGRect(origin: CGPoint(x: margins, y: offsetY), size: textSize)
                offsetY += textSize.height
                offsetY += margins
            }

            return Layout(
                text: textFrame,
                repliedMessage: replyFrame,
                repliesMessageLayout: replyLayout,
                gallery: galleryFrame,
                galleryLayout: galleryLayout,
                attachments: attachments
            )
        }

        func sizeForText(_ text: String, in width: CGFloat) -> CGSize {
            let wrap = Wrap(text: text, width: width)
            if let cached = textCache[wrap] {
                return cached
            }
            textView.text = text
            let size = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            textCache[wrap] = size
            return size
        }
    }
}
