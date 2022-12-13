//
//  FeedDetailCollectionCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//


//
// ⚠️ Note:this code is obsolete; it is in the process of being replaced by Swift code. ⚠️
//


#import "NewsBlurAppDelegate.h"
#import "FeedDetailCollectionCellObsoleteObjCEdition.h"
#import "DashboardViewController.h"
#import "ABTableViewCell.h"
#import "UIView+TKCategory.h"
#import "UIImageView+AFNetworking.h"
#import "Utilities.h"
#import "PINCache.h"
#import "NewsBlur-Swift.h"

static UIFont *textFont = nil;
static UIFont *indicatorFont = nil;

@class FeedDetailViewController;

@interface FeedDetailCollectionCellObsoleteObjCEdition ()

@property (nonatomic, strong) UIImageView *siteImageView;

@property (nonatomic, strong) UILabel *siteLabel;

@property (nonatomic, strong) UIImageView *previewImageView;

@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, strong) UILabel *contentLabel;

@property (nonatomic, strong) UILabel *authorLabel;

@property (nonatomic, strong) UILabel *dateLabel;

//@property (nonatomic, strong) FeedBarView *feedBarView;

@end

@implementation FeedDetailCollectionCellObsoleteObjCEdition

#define rightMargin 18

+ (void)initialize {
    if (self == [FeedDetailCollectionCellObsoleteObjCEdition class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
        indicatorFont = [UIFont boldSystemFontOfSize:12];
    }
}

- (void)setupViewsIfNeeded {
    if (self.titleLabel != nil) {
        return;
    }
    
    // Clear out half pixel border on top and bottom that the draw code can't touch
    UIView *selectedBackground = [[UIView alloc] init];
    [selectedBackground setBackgroundColor:[UIColor clearColor]];
    self.selectedBackgroundView = selectedBackground;
    
    self.siteImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.siteLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.previewImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.contentLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.authorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.dateLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    
    self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.titleLabel.numberOfLines = 0;
    
    self.contentLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.contentLabel.numberOfLines = 0;
    
    [self.contentView addSubview:self.siteImageView];
    [self.contentView addSubview:self.siteLabel];
    [self.contentView addSubview:self.previewImageView];
    [self.contentView addSubview:self.titleLabel];
    [self.contentView addSubview:self.contentLabel];
    [self.contentView addSubview:self.authorLabel];
    [self.contentView addSubview:self.dateLabel];
    
    self.siteImageView.translatesAutoresizingMaskIntoConstraints = false;
    self.siteLabel.translatesAutoresizingMaskIntoConstraints = false;
    self.previewImageView.translatesAutoresizingMaskIntoConstraints = false;
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = false;
    self.contentLabel.translatesAutoresizingMaskIntoConstraints = false;
    self.authorLabel.translatesAutoresizingMaskIntoConstraints = false;
    self.dateLabel.translatesAutoresizingMaskIntoConstraints = false;
    
    NSLayoutConstraint *imageHeight = [self.previewImageView.heightAnchor constraintEqualToConstant:100];
    
    [NSLayoutConstraint activateConstraints:@[
        imageHeight,
        [self.previewImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [self.previewImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [self.previewImageView.trailingAnchor constraintEqualToAnchor: self.contentView.trailingAnchor]]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.previewImageView.bottomAnchor constant:1],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor: self.contentView.trailingAnchor constant:-10]]];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.contentLabel.topAnchor constraintEqualToAnchor:self.self.titleLabel.bottomAnchor constant:10],
        [self.contentLabel.bottomAnchor constraintEqualToAnchor:self.self.contentView.bottomAnchor constant:-10],
        [self.contentLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:10],
        [self.contentLabel.trailingAnchor constraintEqualToAnchor: self.contentView.trailingAnchor constant:-10]]];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    
    [self setNeedsDisplay];
}

- (NSString *)accessibilityLabel {
    NSMutableString *output = [NSMutableString stringWithString:self.siteTitle ?: @"no site"];
    
    [output appendFormat:@", \"%@\"", self.storyTitle ?: @"no story"];
    
    if (self.storyAuthor.length) {
        [output appendFormat:@", by %@", self.storyAuthor ?: @"no author"];
    }
    
    [output appendFormat:@", at %@", self.storyDate ?: @"no date"];
    [output appendFormat:@". %@", self.storyContent ?: @"no content"];
    
    return output;
}

- (void)setupGestures {
    NSString *unreadIcon;
    if (self.storyScore == -1) {
        unreadIcon = @"indicator-hidden";
    } else if (self.storyScore == 1) {
        unreadIcon = @"indicator-focus";
    } else {
        unreadIcon = @"indicator-unread";
    }
    
    UIColor *shareColor = self.isSaved ?
                            UIColorFromRGB(0xF69E89) :
                            UIColorFromRGB(0xA4D97B);
    UIColor *readColor = self.isRead ?
                            UIColorFromRGB(0xBED49F) :
                            UIColorFromRGB(0xFFFFD2);
    
    if (!self.isReadAvailable) {
        unreadIcon = nil;
        readColor = nil;
    }
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
//    [self.swipableCell setDelegate:(FeedDetailViewController <MCSwipeTableViewCellDelegate> *)self.appDelegate.feedDetailViewController];
//
//    [self.swipableCell setFirstStateIconName:@"saved-stories"
//                     firstColor:shareColor
//            secondStateIconName:nil
//                    secondColor:nil
//                  thirdIconName:unreadIcon
//                     thirdColor:readColor
//                 fourthIconName:nil
//                    fourthColor:nil];
//
//    self.swipableCell.mode = MCSwipeTableViewCellModeSwitch;
//    self.swipableCell.shouldAnimatesIcons = NO;
}


- (UIFontDescriptor *)fontDescriptorUsingPreferredSize:(NSString *)textStyle {
    UIFontDescriptor *fontDescriptor = self.appDelegate.fontDescriptorTitleSize;

    if (fontDescriptor) return fontDescriptor;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:textStyle];
    if (![userPreferences boolForKey:@"use_system_font_size"]) {
        if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xs"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:11.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"small"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:13.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"medium"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:14.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"large"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:16.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xl"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:18.0f];
        }
    }
    
    return fontDescriptor;
}

- (void)updateConfigurationUsingState:(UICellConfigurationState *)state {
    [self setupViewsIfNeeded];
    
    self.isReadAvailable = YES;
    
    CGRect contentFrame = self.contentView.frame;
    BOOL isHighlighted = self.highlighted || self.selected;
    CGFloat riverPadding = -10;
    CGFloat riverPreview = 4;
    
    if (self.isRiverOrSocial) {
        riverPadding = 20;
        riverPreview = 6;
    }
    
//    CGContextRef context = UIGraphicsGetCurrentContext();
    
    NSString *preview = [[NSUserDefaults standardUserDefaults] stringForKey:@"story_list_preview_images_size"];
    BOOL isPreviewShown = ![preview isEqualToString:@"none"];
    BOOL isSmall = [preview isEqualToString:@"small"] || [preview isEqualToString:@"small_left"] || [preview isEqualToString:@"small_right"];
    BOOL isLeft = [preview isEqualToString:@"small_left"] || [preview isEqualToString:@"large_left"];
    NSString *spacing = [[NSUserDefaults standardUserDefaults] objectForKey:@"feed_list_spacing"];
    BOOL isComfortable = ![spacing isEqualToString:@"compact"];
    
    CGRect rect = CGRectInset(contentFrame, 12, 12);
    CGFloat comfortMargin = isComfortable ? 10 : 0;
    
    riverPadding += comfortMargin;
    riverPreview += comfortMargin;
    
    CGFloat previewHorizMargin = isSmall ? 14 : 0;
    CGFloat previewVertMargin = isSmall ? 46 : 0;
    CGFloat imageWidth = isSmall ? 60 : 80;
    CGFloat imageHeight = contentFrame.size.height - previewVertMargin;
    CGFloat leftOffset = isLeft ? imageWidth : 0;
    CGFloat leftMargin = leftOffset + 34;
    CGFloat topMargin = isSmall ? riverPreview : 0;
    
    if (isLeft) {
        leftMargin += previewHorizMargin;
        rect.origin.x += (leftOffset + previewHorizMargin);
        rect.size.width -= (leftOffset + previewHorizMargin);
    } else {
        rect.size.width -= previewHorizMargin;
    }
    
    if (isHighlighted) {
        leftMargin += 2;
    }
    
    rect.size.width -= 18; // Scrollbar padding
    CGRect dateRect = rect;
    
    self.backgroundColor = isHighlighted ?
                      UIColorFromLightSepiaMediumDarkRGB(0xFFFDEF, 0xEEECCD, 0x303A40, 0x303030) : UIColorFromLightSepiaMediumDarkRGB(0xF4F4F4, 0xFFFDEF, 0x4F4F4F, 0x101010);
    
    if (self.storyHash && isPreviewShown) {
        CGRect imageFrame = CGRectMake(contentFrame.size.width - imageWidth - previewHorizMargin, topMargin,
                                       imageWidth, imageHeight);
        
        if (isLeft) {
            imageFrame.origin.x = previewHorizMargin + 2;
            
            if (isHighlighted) {
                imageFrame.origin.x += 2;
            }
        } else {
            if (isHighlighted) {
                imageFrame.origin.x -= 2;
            }
        }
        
        UIImage *cachedImage = (UIImage *)self.appDelegate.cachedStoryImages[self.storyHash];
        
        if (cachedImage && ![cachedImage isKindOfClass:[NSNull class]]) {
            //            NSLog(@"Found cached image: %@", self.storyTitle);
//            CGContextRef context = UIGraphicsGetCurrentContext();
//            CGContextSaveGState(context);
            
//            if (isSmall) {
//                [[UIBezierPath bezierPathWithRoundedRect:imageFrame cornerRadius:8] addClip];
//            }
            
            CGFloat alpha = 1.0f;
            if (isHighlighted) {
                alpha = self.isRead ? 0.5f : 0.85f;
            } else if (self.isRead) {
                alpha = 0.34f;
            }
            
            CGFloat aspect = cachedImage.size.width / cachedImage.size.height;
            CGRect drawingFrame;
            
            if (imageFrame.size.width / aspect > imageFrame.size.height) {
                CGFloat height = imageFrame.size.width / aspect;
                
                drawingFrame = CGRectMake(imageFrame.origin.x, imageFrame.origin.y + ((imageFrame.size.height - height) / 2), imageFrame.size.width, height);
            } else {
                CGFloat width = imageFrame.size.height * aspect;
                
                drawingFrame = CGRectMake(imageFrame.origin.x + ((imageFrame.size.width - width) / 2), imageFrame.origin.y, width, imageFrame.size.height);
            }
            
//            CGContextClipToRect(context, imageFrame);
//
//            [cachedImage drawInRect:drawingFrame blendMode:0 alpha:alpha];
            
            self.previewImageView.image = cachedImage;
            
            if (!isLeft) {
                rect.size.width -= imageFrame.size.width;
            }
            
//            CGContextRestoreGState(context);
            
            BOOL isRoomForDateBelowImage = CGRectGetMaxY(imageFrame) < contentFrame.size.height - 10;
            
            if (!isSmall && !isRoomForDateBelowImage) {
                dateRect = rect;
            }
        }
    }
    
    CGFloat feedOffset = isLeft ? 23 : 0;
    UIColor *textColor;
    UIFont *font;
    UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    paragraphStyle.lineHeightMultiple = 0.95f;
    
    if (self.isRiverOrSocial) {
        if (self.isRead) {
            font = [UIFont fontWithName:@"WhitneySSm-Book" size:fontDescriptor.pointSize];
            textColor = UIColorFromLightSepiaMediumDarkRGB(0x808080, 0x808080, 0xB0B0B0, 0x707070);
        } else {
            UIFontDescriptor *boldFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits: UIFontDescriptorTraitBold];
            font = [UIFont fontWithName:@"WhitneySSm-Medium" size:boldFontDescriptor.pointSize];
            textColor = UIColorFromLightSepiaMediumDarkRGB(0x606060, 0x606060, 0xD0D0D0, 0x909090);
        }
        if (isHighlighted) {
            textColor = UIColorFromLightSepiaMediumDarkRGB(0x686868, 0x686868, 0xA0A0A0, 0x808080);
        }
        
        NSInteger siteTitleY = (20 + comfortMargin - font.pointSize/2)/2;
//        [self.siteTitle drawInRect:CGRectMake(leftMargin - feedOffset + 24, siteTitleY, rect.size.width - 20, 20)
//                    withAttributes:@{NSFontAttributeName: font,
//                                     NSForegroundColorAttributeName: textColor,
//                                     NSParagraphStyleAttributeName: paragraphStyle}];
        
        // site favicon
        if (self.isRead && !self.hasAlpha) {
            if (self.isRiverOrSocial) {
                //                    self.siteFavicon = [self.swipableCell imageByApplyingAlpha:self.siteFavicon withAlpha:0.25];
            }
            self.hasAlpha = YES;
        }
        
        UIImage *siteIcon = [Utilities roundCorneredImage:self.siteFavicon radius:4 convertToSize:CGSizeMake(16, 16)];
//        [siteIcon drawInRect:CGRectMake(leftMargin - feedOffset, siteTitleY, 16.0, 16.0)];
    }
    
    // story title
    UIFontDescriptor *boldFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits: UIFontDescriptorTraitBold];
    font = [UIFont fontWithName:@"WhitneySSm-Medium" size:boldFontDescriptor.pointSize + 1];
    if (self.isRead) {
        textColor = UIColorFromLightSepiaMediumDarkRGB(0x585858, 0x585858, 0x989898, 0x888888);
    } else {
        textColor = UIColorFromLightSepiaMediumDarkRGB(0x111111, 0x333333, 0xD0D0D0, 0xCCCCCC);
    }
    if (isHighlighted) {
        textColor = UIColorFromLightDarkRGB(0x686868, 0xA0A0A0);
    }
    CGFloat boundingRows = self.isShort ? 1.5 : 4;
//    if (!self.isShort && (self.textSize == FeedDetailTextSizeMedium || self.textSize == FeedDetailTextSizeLong)) {
//        boundingRows = MIN(((contentFrame.size.height - 24) / font.pointSize) - 2, 4);
//    }
    CGSize theSize = [self.storyTitle
                      boundingRectWithSize:CGSizeMake(rect.size.width, font.pointSize * boundingRows)
                      options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
                      attributes:@{NSFontAttributeName: font,
                                   NSParagraphStyleAttributeName: paragraphStyle}
                      context:nil].size;
    int storyTitleY = 14 + riverPadding;
    if (self.isShort) {
        storyTitleY = 14 + riverPadding - (theSize.height/font.pointSize*2);
    }
    int storyTitleX = leftMargin;
    if (self.isSaved) {
        UIImage *savedIcon = [UIImage imageNamed:@"saved-stories"];
//        [savedIcon drawInRect:CGRectMake(storyTitleX, storyTitleY - 1, 16, 16) blendMode:0 alpha:1];
        storyTitleX += 22;
    }
    if (self.isShared) {
        UIImage *savedIcon = [UIImage imageNamed:@"menu_icn_share"];
//        [savedIcon drawInRect:CGRectMake(storyTitleX, storyTitleY - 1, 16, 16) blendMode:0 alpha:1];
        storyTitleX += 22;
    }
    CGRect storyTitleFrame = CGRectMake(storyTitleX, storyTitleY,
                                        rect.size.width - storyTitleX + leftMargin, theSize.height);
//    [self.storyTitle drawWithRect:storyTitleFrame
//                          options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
//                       attributes:@{NSFontAttributeName: font,
//                                    NSForegroundColorAttributeName: textColor,
//                                    NSParagraphStyleAttributeName: paragraphStyle}
//                          context:nil];
    
    self.titleLabel.text = self.storyTitle;
    self.titleLabel.textColor = textColor;
    self.titleLabel.font = font;
    
    //    CGContextStrokeRect(context, storyTitleFrame);
    
    if (self.isRead) {
        textColor = UIColorFromLightSepiaMediumDarkRGB(0xB8B8B8, 0xB8B8B8, 0xA0A0A0, 0x707070);
        font = [UIFont fontWithName:@"WhitneySSm-Book" size:fontDescriptor.pointSize - 1];
    } else {
        textColor = UIColorFromLightSepiaMediumDarkRGB(0x404040, 0x404040, 0xC0C0C0, 0xB0B0B0);
        font = [UIFont fontWithName:@"WhitneySSm-Book" size:fontDescriptor.pointSize - 1];
    }
    if (isHighlighted) {
        if (self.isRead) {
            textColor = UIColorFromLightSepiaMediumDarkRGB(0xB8B8B8, 0xB8B8B8, 0xA0A0A0, 0x707070);
        } else {
            textColor = UIColorFromLightSepiaMediumDarkRGB(0x888785, 0x686868, 0xA9A9A9, 0x989898);
        }
    }
    
    if (self.storyContent) {
        CGFloat bottomOfTitle = storyTitleY + theSize.height;
        int storyContentWidth = rect.size.width;
        CGFloat boundingRows = self.isShort ? 1.5 : 3;
        
//        if (!self.isShort && (self.textSize == FeedDetailTextSizeMedium || self.textSize == FeedDetailTextSizeLong)) {
//            boundingRows = (contentFrame.size.height - 30 - comfortMargin - CGRectGetMaxY(storyTitleFrame)) / font.pointSize;
//        }
        
        CGSize contentSize = [self.storyContent
                              boundingRectWithSize:CGSizeMake(storyContentWidth, font.pointSize * boundingRows)
                              options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
                              attributes:@{NSFontAttributeName: font,
                                           NSParagraphStyleAttributeName: paragraphStyle}
                              context:nil].size;
        CGFloat textRows = contentSize.height / font.pointSize;
        int storyContentY = contentFrame.size.height - 16 - comfortMargin - 4 - ((font.pointSize * textRows + font.lineHeight) + contentSize.height) / 2;
        if (self.isShort) {
            storyContentY = contentFrame.size.height - 10 - comfortMargin - 4 - ((font.pointSize + font.lineHeight) + contentSize.height)/2;
        }
        
        if (storyContentY - bottomOfTitle > 20) {
            storyContentY -= font.pointSize;
            contentSize.height += font.lineHeight;
        }
        
//        [self.storyContent
//         drawWithRect:CGRectMake(storyTitleX, storyContentY,
//                                 rect.size.width - storyTitleX + leftMargin, contentSize.height)
//         options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
//         attributes:@{NSFontAttributeName: font,
//                      NSForegroundColorAttributeName: textColor,
//                      NSParagraphStyleAttributeName: paragraphStyle}
//         context:nil];
        
        //        CGContextStrokeRect(context, CGRectMake(storyTitleX, storyContentY,
        //                                                rect.size.width - storyTitleX + leftMargin, contentSize.height));
        
        self.contentLabel.text = self.storyContent;
        self.contentLabel.textColor = textColor;
        self.contentLabel.font = font;
//        self.contentLabel.numberOfLines = self.textSize == FeedDetailTextSizeShort ? 2 : self.textSize == FeedDetailTextSizeMedium ? 4 : 0;
    }
    
    // story date
    int storyAuthorDateY = contentFrame.size.height - 18 - comfortMargin;
    
    if (self.isRead) {
        font = [UIFont fontWithName:@"WhitneySSm-Medium" size:11];
    } else {
        font = [UIFont fontWithName:@"WhitneySSm-Medium" size:11];
    }
    // Story author and date
    NSString *date = [Utilities formatShortDateFromTimestamp:self.storyTimestamp];
    NSString *author = self.storyAuthor.length > 0 ? [NSString stringWithFormat:@" · %@", self.storyAuthor] : @"";
    paragraphStyle.alignment = NSTextAlignmentLeft;
//    [[NSString stringWithFormat:@"%@%@", date, author]
//     drawInRect:CGRectMake(leftMargin, storyAuthorDateY, dateRect.size.width - 12, 15.0)
//     withAttributes:@{NSFontAttributeName: font,
//                      NSForegroundColorAttributeName: textColor,
//                      NSParagraphStyleAttributeName: paragraphStyle}];
    
    // feed bar
//    CGFloat feedBarOffset = isHighlighted ? 2 : 0;
//    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBarTopBorder CGColor]));
//    if (self.isRead) {
//        CGContextSetAlpha(context, 0.15);
//    }
//    CGContextSetLineWidth(context, 4.0f);
//    CGContextBeginPath(context);
//    CGContextMoveToPoint(context, 2.0f + feedBarOffset, 0);
//    CGContextAddLineToPoint(context, 2.0f + feedBarOffset, self.frame.size.height);
//    CGContextStrokePath(context);
//
//    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBar CGColor]));
//    CGContextBeginPath(context);
//    CGContextMoveToPoint(context, 6.0f + feedBarOffset, 0);
//    CGContextAddLineToPoint(context, 6.0 + feedBarOffset, self.frame.size.height);
//    CGContextStrokePath(context);
    
    // reset for borders
//    UIColor *white = UIColorFromRGB(0xffffff);
//    CGContextSetAlpha(context, 1.0);
//    if (isHighlighted) {
//        // top border
//        CGContextSetStrokeColor(context, CGColorGetComponents([white CGColor]));
//
//        CGContextSetLineWidth(context, 1.0f);
//        CGContextBeginPath(context);
//        CGContextMoveToPoint(context, 0, 0.5f);
//        CGContextAddLineToPoint(context, self.bounds.size.width, 0.5f);
//        CGContextStrokePath(context);
//
//        CGFloat lineWidth = 0.5f;
//        CGContextSetLineWidth(context, lineWidth);
//        UIColor *blue = UIColorFromRGB(0xDFDDCF);
//
//        CGContextSetStrokeColor(context, CGColorGetComponents([blue CGColor]));
//
//        CGContextBeginPath(context);
//        CGContextMoveToPoint(context, 0, 1.0f + 0.5f*lineWidth);
//        CGContextAddLineToPoint(context, self.bounds.size.width, 1.0f + 0.5f*lineWidth);
//        CGContextStrokePath(context);
//
//        // bottom border
//        CGContextBeginPath(context);
//        CGContextMoveToPoint(context, 0, self.bounds.size.height - .5f*lineWidth);
//        CGContextAddLineToPoint(context, self.bounds.size.width, self.bounds.size.height - .5f*lineWidth);
//        CGContextStrokePath(context);
//
//        // Rounded frame
//        UIColor *borderColor = UIColorFromLightDarkRGB(0xeeeeee, 0x0);
//        CGContextSaveGState(context);
//        CGContextSetLineWidth(context, 7);
//        CGContextSetStrokeColorWithColor(context, borderColor.CGColor);
//        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:contentFrame cornerRadius:8];
//        CGContextAddPath(context, path.CGPath);
//        CGContextDrawPath(context, kCGPathStroke);
//        CGContextRestoreGState(context);
//    } else {
//        // top border
//        CGContextSetLineWidth(context, 1.0f);
//
//        CGContextSetStrokeColor(context, CGColorGetComponents([white CGColor]));
//
//        CGContextBeginPath(context);
//        CGContextMoveToPoint(context, 0.0f, 0.5f);
//        CGContextAddLineToPoint(context, self.bounds.size.width, 0.5f);
//        CGContextStrokePath(context);
//    }
//
//    // story indicator
//    CGFloat storyIndicatorX = isLeft ? rect.origin.x + 2 : 15;
//    CGFloat storyIndicatorY = storyTitleFrame.origin.y + (fontDescriptor.pointSize / 2);
//
//    UIImage *unreadIcon;
//    CGFloat size = 12;
//    if (self.storyScore == -1) {
//        unreadIcon = [UIImage imageNamed:@"indicator-hidden"];
//    } else if (self.storyScore == 1) {
//        unreadIcon = [UIImage imageNamed:@"indicator-focus"];
//    } else {
//        unreadIcon = [UIImage imageNamed:@"indicator-unread"];
//        size = 10;
//    }
//
//    [unreadIcon drawInRect:CGRectMake(storyIndicatorX, storyIndicatorY - (size / 2) + 1, size, size) blendMode:0 alpha:(self.isRead ? .15 : 1)];
}

@end
