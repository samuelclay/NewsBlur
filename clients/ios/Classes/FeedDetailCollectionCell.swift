//
//  FeedDetailCollectionCell.swift
//  NewsBlur
//
//  Created by David Sinclair on 2022-12-08.
//  Copyright © 2022 NewsBlur. All rights reserved.
//

import UIKit

@objc enum FeedDetailTextSize: Int {
    case titleOnly
    case short
    case medium
    case long
}

class FeedDetailCollectionCell: UICollectionViewCell {
    @objc var isGrid = false
    
    @objc var siteTitle = ""
    @objc var siteFavicon: UIImage?
    
    @objc var storyScore = 0
    @objc var isSaved = false
    @objc var isShared = false
    
    @objc var storyTitle = ""
    @objc var storyAuthor = ""
    @objc var storyDate = ""
    @objc var storyContent: String?
    @objc var storyHash = ""
    @objc var storyTimestamp = 0
    
    @objc var feedColorBar: UIColor?
    @objc var feedColorBarTopBorder: UIColor?
    
    @objc var isRead = false
    @objc var isReadAvailable = false
    @objc var isShort = false
    @objc var isRiverOrSocial = false
    @objc var hasAlpha = false
    
    @objc var textSize: FeedDetailTextSize = .medium
    
    var prepared = false
    
    lazy var appDelegate: NewsBlurAppDelegate = {
        return NewsBlurAppDelegate.shared()!
    }()
    
    let containerView = UIView()
    var siteImageView = UIImageView()
    var siteLabel = UILabel()
    var previewImageView = UIImageView()
    var unreadImageView = UIImageView()
    var savedImageView = UIImageView()
    var sharedImageView = UIImageView()
    var titleLabel = UILabel()
    var contentLabel = UILabel()
    var contentGradient = CAGradientLayer()
    var dateAndAuthorLabel = UILabel()
    
    var noPreviewConstraints = [NSLayoutConstraint]()
    var topPreviewConstraints = [NSLayoutConstraint]()
    var leftPreviewConstraints = [NSLayoutConstraint]()
    var rightPreviewConstraints = [NSLayoutConstraint]()
    
    var savedConstraints = [NSLayoutConstraint]()
    var sharedConstraints = [NSLayoutConstraint]()
    
    @objc func setupGestures() {
        //TODO: 🚧 
    }
    
    func setupViewsIfNeeded() {
        if prepared {
            return
        }
        
        prepared = true
        
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 0
        
        contentLabel.lineBreakMode = .byWordWrapping
        contentLabel.numberOfLines = 0
        
        let topViews = [previewImageView, containerView, dateAndAuthorLabel, unreadImageView]
        
        for view in topViews {
            contentView.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.clipsToBounds = true
        }
        
        let subviews = [siteImageView, siteLabel, savedImageView, sharedImageView, titleLabel, contentLabel]
        
        for view in subviews {
            containerView.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.clipsToBounds = true
        }
        
//        contentGradient.colors = [UIColor.white.cgColor, UIColor.clear.cgColor]
//        contentLabel.layer.mask = contentGradient
        
        let imageHeightConstraint = previewImageView.heightAnchor.constraint(equalToConstant: 150)
        imageHeightConstraint.priority = .required - 1
        
        noPreviewConstraints = [
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            previewImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10)
        ]
        
        topPreviewConstraints = [
            imageHeightConstraint,
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: containerView.topAnchor, constant: -10)
        ]
        
        leftPreviewConstraints = [
            previewImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            previewImageView.widthAnchor.constraint(equalToConstant: 80),
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: -10),
            previewImageView.trailingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: -10),
            previewImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor)
        ]
        
        rightPreviewConstraints = [
            previewImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80),
            previewImageView.widthAnchor.constraint(equalToConstant: 80),
            previewImageView.leadingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 10),
            previewImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor)
        ]
        
        sharedConstraints = [
            sharedImageView.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            sharedImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            sharedImageView.trailingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: -6),
            sharedImageView.widthAnchor.constraint(equalToConstant: 16),
            sharedImageView.heightAnchor.constraint(equalToConstant: 16)
        ]
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 30),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -10)])
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)])
        
        NSLayoutConstraint.activate([
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            contentLabel.bottomAnchor.constraint(greaterThanOrEqualTo: containerView.bottomAnchor),
            contentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)])
        
        NSLayoutConstraint.activate([
            unreadImageView.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            unreadImageView.trailingAnchor.constraint(equalTo: sharedImageView.leadingAnchor, constant: -6),
            unreadImageView.widthAnchor.constraint(equalToConstant: 16),
            unreadImageView.heightAnchor.constraint(equalToConstant: 16)])
        
        NSLayoutConstraint.activate([
            dateAndAuthorLabel.topAnchor.constraint(greaterThanOrEqualTo: containerView.bottomAnchor, constant: 10),
            dateAndAuthorLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            dateAndAuthorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            dateAndAuthorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)])
        
        //TODO: 🚧 feed bar, site image & title, saved indicator
    }
    
    override func updateConfiguration(using state: UICellConfigurationState) {
        setupViewsIfNeeded()
        
        let preview = UserDefaults.standard.string(forKey: "story_list_preview_images_size")
        let wantImage = isGrid || preview != "none"
        let isLeft = preview == "small_left" || preview == "large_left"
        let previewImage = wantImage ? previewImage : nil
        
        if !wantImage || previewImage == nil {
            NSLayoutConstraint.activate(noPreviewConstraints)
            NSLayoutConstraint.deactivate(leftPreviewConstraints)
            NSLayoutConstraint.deactivate(rightPreviewConstraints)
            NSLayoutConstraint.deactivate(topPreviewConstraints)
        } else if isGrid {
            NSLayoutConstraint.deactivate(noPreviewConstraints)
            NSLayoutConstraint.deactivate(leftPreviewConstraints)
            NSLayoutConstraint.deactivate(rightPreviewConstraints)
            NSLayoutConstraint.activate(topPreviewConstraints)
        } else if isLeft {
            NSLayoutConstraint.deactivate(noPreviewConstraints)
            NSLayoutConstraint.deactivate(topPreviewConstraints)
            NSLayoutConstraint.activate(leftPreviewConstraints)
            NSLayoutConstraint.deactivate(rightPreviewConstraints)
        } else {
            NSLayoutConstraint.deactivate(noPreviewConstraints)
            NSLayoutConstraint.deactivate(topPreviewConstraints)
            NSLayoutConstraint.deactivate(leftPreviewConstraints)
            NSLayoutConstraint.activate(rightPreviewConstraints)
        }
        
        if isShared {
            NSLayoutConstraint.activate(sharedConstraints)
        } else {
            NSLayoutConstraint.deactivate(sharedConstraints)
        }
        
        let author = storyAuthor.isEmpty ? "" : " by \(storyAuthor)"
        let content = storyContent ?? "no content"
        
        accessibilityLabel = "\(siteTitle), \"\(storyTitle)\"\(author), at \(storyDate). \(content)"
        
        layer.cornerRadius = isGrid ? 4 : 0
        backgroundColor = isGrid ? ThemeManager.color(fromRGB: [0xFDFCFA, 0xFFFDEF, 0x4F4F4F, 0x292B2C]) :
                    isHighlighted ? ThemeManager.color(fromRGB: [0xFFFDEF, 0xEEECCD, 0x303A40, 0x303030]) :
                    ThemeManager.color(fromRGB: [0xF4F4F4, 0xFFFDEF, 0x4F4F4F, 0x101010])
        
        updateSiteTitle()
        updatePreview(image: previewImage)
        updateStoryTitle()
        updateStoryContent()
        updateIndicators()
        updateStoryDateAndAuthor()
        
        //TODO: 🚧 feed bar as a custom image
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        contentGradient.frame = contentLabel.bounds // CGRect(x: 0, y: rect.maxY - 10, width: rect.width, height: 10)
    }
    
    func updateSiteTitle() {
        //TODO: 🚧
    }
    
    var previewImage: UIImage? {
        guard let image = appDelegate.cachedImage(forStoryHash: storyHash), image.isKind(of: UIImage.self) else {
            return nil
        }
        
        return image
    }
    
    func updatePreview(image: UIImage?) {
        
        if isHighlighted {
            previewImageView.alpha = isRead ? 0.5 : 0.85
        } else {
            previewImageView.alpha = isRead ? 0.34 : 1
        }
        
        previewImageView.contentMode = .scaleAspectFill
        previewImageView.image = image
    }
    
    func updateStoryTitle() {
        titleLabel.font = UIFont(name: "WhitneySSm-Medium", size:boldFontDescriptor.pointSize + 1)
        
        if (isHighlighted) {
            titleLabel.textColor = ThemeManager.color(fromRGB: [0x686868, 0xA0A0A0])
        } else if isRead {
            titleLabel.textColor = ThemeManager.color(fromRGB: [0x585858, 0x585858, 0x989898, 0x888888])
        } else {
            titleLabel.textColor = ThemeManager.color(fromRGB: [0x111111, 0x333333, 0xD0D0D0, 0xCCCCCC])
        }
        
        titleLabel.text = storyTitle
    }
    
    func updateStoryContent() {
        contentLabel.font = UIFont(name: "WhitneySSm-Book", size:boldFontDescriptor.pointSize - 1)
        
        if (isHighlighted && isRead) {
            contentLabel.textColor = ThemeManager.color(fromRGB: [0xB8B8B8, 0xB8B8B8, 0xA0A0A0, 0x707070])
        } else if isHighlighted {
            contentLabel.textColor = ThemeManager.color(fromRGB: [0x888785, 0x686868, 0xA9A9A9, 0x989898])
        } else if isRead {
            contentLabel.textColor = ThemeManager.color(fromRGB: [0xB8B8B8, 0xB8B8B8, 0xA0A0A0, 0x707070])
        } else {
            contentLabel.textColor = ThemeManager.color(fromRGB: [0x404040, 0x404040, 0xC0C0C0, 0xB0B0B0])
        }
        
        contentLabel.text = storyContent
    }
    
    func updateIndicators() {
        let unreadIcon: UIImage?
        
        switch storyScore {
        case -1:
            unreadIcon = UIImage(named: "indicator-hidden")
        case 1:
            unreadIcon = UIImage(named: "indicator-focus")
        default:
            unreadIcon = UIImage(named: "indicator-unread")
        }
        
        unreadImageView.image = unreadIcon
        
        sharedImageView.image = isShared ? UIImage(named: "menu_icn_share") : nil
    }
    
    func updateStoryDateAndAuthor() {
        dateAndAuthorLabel.font = UIFont(name: "WhitneySSm-Medium", size:11)
        dateAndAuthorLabel.textColor = contentLabel.textColor
        
        let date = Utilities.formatShortDate(fromTimestamp: storyTimestamp) ?? ""
        
        dateAndAuthorLabel.text = storyAuthor.isEmpty ? date : "\(date) · \(storyAuthor)"
    }
    
    var fontDescriptor: UIFontDescriptor {
        return fontDescriptor(for: .caption1)
    }
    
    var boldFontDescriptor: UIFontDescriptor {
        return fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor
    }
    
    func fontDescriptor(for textStyle: UIFont.TextStyle) -> UIFontDescriptor {
        if let fontDescriptor = appDelegate.fontDescriptorTitleSize {
            return fontDescriptor
        }
        
        var fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: textStyle)
        
        if !UserDefaults.standard.bool(forKey: "use_system_font_size") {
            switch UserDefaults.standard.string(forKey: "feed_list_font_size") {
            case "xs":
                fontDescriptor = fontDescriptor.withSize(11)
            case "small":
                fontDescriptor = fontDescriptor.withSize(13)
            case "large":
                fontDescriptor = fontDescriptor.withSize(16)
            case "xl":
                fontDescriptor = fontDescriptor.withSize(18)
            default:
                fontDescriptor = fontDescriptor.withSize(14)
            }
        }
        
        appDelegate.fontDescriptorTitleSize = fontDescriptor
        
        return fontDescriptor
    }
    
    
    
    override var isHighlighted: Bool {
        get {
            return super.isHighlighted || isSelected
        }
        set {
            super.isHighlighted = newValue
            
            setNeedsDisplay()
        }
    }
}
