//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Nuke
import StreamChat
import UIKit

open class ChatMessageImageGallery<ExtraData: UIExtraDataTypes>: View, UIConfigProvider {
    struct Layout {
        let preview1: CGRect?
        let preview2: CGRect?
        let preview3: CGRect?
        let moreOverlay: CGRect?
    }

    var layout: Layout? {
        didSet { setNeedsLayout() }
    }

    public var didTapOnAttachment: ((_ChatMessageAttachment<ExtraData>) -> Void)? {
        didSet { updateContent() }
    }

    public var imageAttachments: [_ChatMessageAttachment<ExtraData>] = [] {
        didSet { updateContent() }
    }

    // MARK: - Subviews

    public private(set) lazy var preview1 = createImagePreview()
    public private(set) lazy var preview2 = createImagePreview()
    public private(set) lazy var preview3 = createImagePreview()
    private var previews: [ImagePreview] { [preview1, preview2, preview3] }

    public private(set) lazy var moreImagesOverlay: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .largeTitle)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        return label
    }()

    // MARK: - Overrides

    override open func setUpLayout() {
        addSubview(preview1)
        addSubview(preview2)
        addSubview(preview3)
        addSubview(moreImagesOverlay)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        preview1.isHidden = layout?.preview1 == nil
        if let frame = layout?.preview1 {
            preview1.frame = frame
        }

        preview2.isHidden = layout?.preview2 == nil
        if let frame = layout?.preview2 {
            preview2.frame = frame
        }

        preview3.isHidden = layout?.preview3 == nil
        if let frame = layout?.preview3 {
            preview3.frame = frame
        }

        moreImagesOverlay.isHidden = layout?.moreOverlay == nil
        if let frame = layout?.moreOverlay {
            moreImagesOverlay.frame = frame
        }
    }

    override open func defaultAppearance() {
        moreImagesOverlay.textColor = .white
        moreImagesOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
    }

    override open func updateContent() {
        for (index, itemPreview) in previews.enumerated() {
            let attachment = imageAttachments[safe: index]

            itemPreview.isHidden = attachment == nil
            itemPreview.previewURL = attachment?.imagePreviewURL ?? attachment?.imageURL
            itemPreview.didTap = attachment.flatMap { image in
                { [weak self] in
                    self?.didTapOnAttachment?(image)
                }
            }
        }

        moreImagesOverlay.text = "+\(imageAttachments.count - 3)"
    }

    // MARK: - Private

    private func createImagePreview() -> ImagePreview {
        uiConfig
            .messageList
            .messageContentSubviews
            .imageGalleryItem
            .init()
    }
}

extension ChatMessageImageGallery {
    open class ImagePreview: View {
        public var previewURL: URL? {
            didSet { updateContent() }
        }

        public var didTap: (() -> Void)?

        private var imageTask: ImageTask? {
            didSet { oldValue?.cancel() }
        }

        // MARK: - Subviews

        public private(set) lazy var imageView: UIImageView = {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.layer.masksToBounds = true
            return imageView.withoutAutoresizingMaskConstraints
        }()

        public private(set) lazy var activityIndicator: UIActivityIndicatorView = {
            let indicator = UIActivityIndicatorView()
            indicator.hidesWhenStopped = true
            indicator.style = .gray
            return indicator.withoutAutoresizingMaskConstraints
        }()

        // MARK: - Overrides

        override open func layoutSubviews() {
            super.layoutSubviews()

            imageView.frame = bounds
            activityIndicator.frame = bounds
        }

        override open func setUpAppearance() {
            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapHandler(_:)))
            addGestureRecognizer(tapRecognizer)
        }

        override open func setUpLayout() {
            addSubview(imageView)
            addSubview(activityIndicator)
        }

        override open func updateContent() {
            if let url = previewURL {
                activityIndicator.startAnimating()
                imageTask = loadImage(with: url, options: .shared, into: imageView, completion: { [weak self] _ in
                    self?.activityIndicator.stopAnimating()
                    self?.imageTask = nil
                })
            } else {
                activityIndicator.stopAnimating()
                imageView.image = nil
                imageTask = nil
            }

            setNeedsLayout()
        }

        // MARK: - Actions

        @objc open func tapHandler(_ recognizer: UITapGestureRecognizer) {
            didTap?()
        }

        // MARK: - Init & Deinit

        deinit {
            imageTask = nil
        }
    }
}

extension ChatMessageImageGallery {
    class LayoutProvider: ConfiguredLayoutProvider<ExtraData> {
        func heightForView(with data: [_ChatMessageAttachment<ExtraData>], limitedBy width: CGFloat) -> CGFloat {
            sizeForView(with: data, limitedBy: width).height
        }

        func sizeForView(with data: [_ChatMessageAttachment<ExtraData>], limitedBy width: CGFloat) -> CGSize {
            CGSize(width: width, height: width)
        }

        func layoutForView(
            with data: [_ChatMessageAttachment<ExtraData>],
            of size: CGSize
        ) -> Layout {
            if data.count == 1 {
                return Layout(
                    preview1: CGRect(origin: .zero, size: size),
                    preview2: nil,
                    preview3: nil,
                    moreOverlay: nil
                )
            }
            if data.count == 2 {
                return Layout(
                    preview1: CGRect(x: 0, y: 0, width: size.width / 2, height: size.height),
                    preview2: CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height),
                    preview3: nil,
                    moreOverlay: nil
                )
            }
            return Layout(
                preview1: CGRect(x: 0, y: 0, width: size.width / 2, height: size.height),
                preview2: CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height / 2),
                preview3: CGRect(x: size.width / 2, y: size.height / 2, width: size.width / 2, height: size.height / 2),
                moreOverlay: CGRect(x: size.width / 2, y: size.height / 2, width: size.width / 2, height: size.height / 2)
            )
        }
    }
}
