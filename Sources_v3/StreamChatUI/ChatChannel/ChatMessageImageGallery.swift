//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Nuke
import StreamChat
import UIKit

open class ChatMessageImageGallery<ExtraData: UIExtraDataTypes>: View, UIConfigProvider {
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
        return label.withoutAutoresizingMaskConstraints
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

        if imageAttachments.count == 1 {
            preview1.frame = bounds
        } else if imageAttachments.count == 2 {
            preview1.frame = CGRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height)
            preview2.frame = CGRect(x: preview1.frame.maxX, y: 0, width: bounds.width / 2, height: bounds.height)
        } else {
            preview1.frame = CGRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height)
            preview2.frame = CGRect(x: preview1.frame.maxX, y: 0, width: bounds.width / 2, height: bounds.height / 2)
            preview3.frame = CGRect(
                x: preview2.frame.minX,
                y: preview2.frame.maxY,
                width: bounds.width / 2,
                height: bounds.height / 2
            )
        }

        moreImagesOverlay.frame = preview3.frame
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
        moreImagesOverlay.isHidden = imageAttachments.count < 4

        setNeedsLayout()
    }

    // MARK: - Private

    private func createImagePreview() -> ImagePreview {
        uiConfig
            .messageList
            .messageContentSubviews
            .imageGalleryItem
            .init()
            .withoutAutoresizingMaskConstraints
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
