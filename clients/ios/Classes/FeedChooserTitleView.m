//
//  FeedChooserTitleView.m
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-22.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "FeedChooserTitleView.h"
#import "NewsBlurAppDelegate.h"

@interface FeedChooserTitleView ()

@property (nonatomic) UIButton *invisibleHeaderButton;
@property (nonatomic, strong) UIFontDescriptor *fontDescriptor;

@end

@implementation FeedChooserTitleView

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (UIView *subview in self.subviews) {
        [subview removeFromSuperview];
    }
    
    // Create the parent view that will hold header Label
    UIView *customView = [[UIView alloc] initWithFrame:rect];
    
    // Background
    [NewsBlurAppDelegate fillGradient:rect
                           startColor:UIColorFromLightSepiaMediumDarkRGB(0xEAECE5, 0xffffc6, 0x6A6A6A, 0x444444)
                             endColor:UIColorFromLightSepiaMediumDarkRGB(0xDCDFD6, 0xffffc0, 0x666666, 0x333333)];
    
    // Borders
    UIColor *topColor = UIColorFromLightSepiaMediumDarkRGB(0xFDFDFD, 0xFDFDF6, 0x878B8A, 0x474B4A);
    CGContextSetStrokeColor(context, CGColorGetComponents([topColor CGColor]));
    
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 0, 0.25f);
    CGContextAddLineToPoint(context, rect.size.width, 0.25f);
    CGContextStrokePath(context);
    
    // bottom border
    UIColor *bottomColor = UIColorFromLightSepiaMediumDarkRGB(0xB7BBAA, 0xe0e0a6, 0x404040, 0x0D0D0D);
    CGContextSetStrokeColor(context, CGColorGetComponents([bottomColor CGColor]));
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 0, rect.size.height-0.25f);
    CGContextAddLineToPoint(context, rect.size.width, rect.size.height-0.25f);
    CGContextStrokePath(context);
    
    // Folder title
    UIColor *textColor = UIColorFromRGB(0x4C4D4A);
    UIFont *font = [UIFont fontWithDescriptor:self.fontDescriptor size:0.0];
    NSInteger titleOffsetY = ((rect.size.height - font.pointSize) / 2) - 1;
    UIColor *shadowColor = UIColorFromRGB(0xF0F2E9);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 0, [shadowColor CGColor]);
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    [self.title.uppercaseString drawInRect:CGRectMake(36.0, titleOffsetY, rect.size.width - 36 - 36, font.pointSize)
     withAttributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}];
    
    self.invisibleHeaderButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.invisibleHeaderButton.frame = CGRectMake(0, 0, customView.frame.size.width, customView.frame.size.height);
    self.invisibleHeaderButton.alpha = 0.1;
    self.invisibleHeaderButton.tag = self.section;
    self.invisibleHeaderButton.accessibilityLabel = [NSString stringWithFormat:@"%@ folder", self.title];
    self.invisibleHeaderButton.accessibilityTraits = UIAccessibilityTraitNone;
    [self.invisibleHeaderButton addTarget:self.delegate
                              action:@selector(didSelectTitleView:)
                    forControlEvents:UIControlEventTouchUpInside];
    [customView addSubview:self.invisibleHeaderButton];
    
    UIImage *folderImage = [UIImage imageNamed:@"g_icn_folder"];
    CGFloat folderImageViewX = 10.0;
    
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        folderImageViewX = 7.0;
    }
    
    [folderImage drawInRect:CGRectMake(folderImageViewX, 8.0, 20.0, 20.0)];
    
    [self addSubview:customView];
}

- (UIFontDescriptor *)fontDescriptor {
    if (!_fontDescriptor) {
        UIFontDescriptor *captionFontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleCaption1];
        UIFontDescriptor *boldFontDescriptor = [captionFontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
        self.fontDescriptor = [boldFontDescriptor fontDescriptorWithSize:12.0];
    }
    
    return _fontDescriptor;
}

@end
