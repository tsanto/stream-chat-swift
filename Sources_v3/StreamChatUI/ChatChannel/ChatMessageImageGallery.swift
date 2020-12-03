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

    private var preview1Constraints: [NSLayoutConstraint] = []
    private var preview2Constraints: [NSLayoutConstraint] = []
    private var preview3Constraints: [NSLayoutConstraint] = []

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

        preview1.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        preview1.topAnchor.constraint(equalTo: topAnchor).isActive = true
        preview1.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        preview2.leadingAnchor.constraint(equalTo: preview1.trailingAnchor).isActive = true
        preview2.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        preview2.topAnchor.constraint(equalTo: topAnchor).isActive = true

        preview3.leadingAnchor.constraint(equalTo: preview1.trailingAnchor).isActive = true
        preview3.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true
        preview3.topAnchor.constraint(equalTo: preview2.bottomAnchor).isActive = true
        preview3.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true

        moreImagesOverlay.leadingAnchor.constraint(equalTo: preview3.leadingAnchor).isActive = true
        moreImagesOverlay.trailingAnchor.constraint(equalTo: preview3.trailingAnchor).isActive = true
        moreImagesOverlay.topAnchor.constraint(equalTo: preview3.topAnchor).isActive = true
        moreImagesOverlay.bottomAnchor.constraint(equalTo: preview3.bottomAnchor).isActive = true

        preview1Constraints = [
            preview1.trailingAnchor.constraint(equalTo: trailingAnchor)
        ]
        preview2Constraints = [
            preview1.widthAnchor.constraint(equalTo: preview2.widthAnchor),
            preview2.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        preview3Constraints = [
            preview1.widthAnchor.constraint(equalTo: preview2.widthAnchor),
            preview2.heightAnchor.constraint(equalTo: preview3.heightAnchor)
        ]
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

        activateNecessaryConstraints()
    }

    // MARK: - Private

    private func activateNecessaryConstraints() {
        let constraintsToDeactivate: [NSLayoutConstraint]
        let constraintsToActivate: [NSLayoutConstraint]

        if imageAttachments.count == 1 {
            constraintsToActivate = preview1Constraints
            constraintsToDeactivate = preview2Constraints + preview3Constraints
        } else if imageAttachments.count == 2 {
            constraintsToActivate = preview2Constraints
            constraintsToDeactivate = preview1Constraints + preview3Constraints
        } else {
            constraintsToActivate = preview3Constraints
            constraintsToDeactivate = preview1Constraints + preview2Constraints
        }

        constraintsToDeactivate.forEach { $0.isActive = false }
        constraintsToActivate.forEach { $0.isActive = true }
    }

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
