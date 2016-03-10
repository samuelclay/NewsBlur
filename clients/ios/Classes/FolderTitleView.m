//
//  FolderTitleView.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "FolderTitleView.h"
#import "UnreadCountView.h"

@implementation FolderTitleView

@synthesize appDelegate;
@synthesize section;
@synthesize unreadCount;
@synthesize invisibleHeaderButton;

- (void)setNeedsDisplay {
    [unreadCount setNeedsDisplay];
    
    fontDescriptorSize = nil;
    
    [super setNeedsDisplay];
}

- (void) drawRect:(CGRect)rect {
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (UIView *subview in self.subviews) {
        [subview removeFromSuperview];
    }
    
    NSString *folderName;
    if (section == 0) {
        folderName = @"river_global";
    } else if (section == 1) {
        folderName = @"river_blurblogs";
    } else {
        folderName = [appDelegate.dictFoldersArray objectAtIndex:section];
    }
    NSString *collapseKey = [NSString stringWithFormat:@"folderCollapsed:%@", folderName];
    bool isFolderCollapsed = [userPreferences boolForKey:collapseKey];
    int countWidth = 0;
    NSString *accessibilityCount = @"";
    
    if ([folderName isEqual:@"saved_stories"]) {
        unreadCount = [[UnreadCountView alloc] initWithFrame:CGRectInset(rect, 0, 2)];
        unreadCount.appDelegate = appDelegate;
        unreadCount.opaque = NO;
        unreadCount.psCount = appDelegate.savedStoriesCount;
        unreadCount.blueCount = appDelegate.savedStoriesCount;
        
        [unreadCount calculateOffsets:appDelegate.savedStoriesCount nt:0];
        countWidth = [unreadCount offsetWidth];
        [self addSubview:unreadCount];
        
        accessibilityCount = [NSString stringWithFormat:@", %@ stories", @(appDelegate.savedStoriesCount)];
    } else if (isFolderCollapsed) {
        UnreadCounts *counts = [appDelegate splitUnreadCountForFolder:folderName];
        unreadCount = [[UnreadCountView alloc] initWithFrame:CGRectInset(rect, 0, 2)];
        unreadCount.appDelegate = appDelegate;
        unreadCount.opaque = NO;
        unreadCount.psCount = counts.ps;
        unreadCount.ntCount = counts.nt;
        
        [unreadCount calculateOffsets:counts.ps nt:counts.nt];
        countWidth = [unreadCount offsetWidth];
        [self addSubview:unreadCount];
        
        accessibilityCount = [NSString stringWithFormat:@", collapsed, %@ unread stories", @(counts.nt)];
    } else if (UIAccessibilityIsVoiceOverRunning()) {
        UnreadCounts *counts = [appDelegate splitUnreadCountForFolder:folderName];
        
        accessibilityCount = [NSString stringWithFormat:@", %@ unread stories", @(counts.nt)];
    }
    
    // create the parent view that will hold header Label
    UIView* customView = [[UIView alloc] initWithFrame:rect];

    // Background
    [NewsBlurAppDelegate fillGradient:rect
                           startColor:UIColorFromLightSepiaMediumDarkRGB(0xEAECE5, 0xffffc6, 0x6A6A6A, 0x444444)
                             endColor:UIColorFromLightSepiaMediumDarkRGB(0xDCDFD6, 0xffffc0, 0x666666, 0x333333)];
//    UIColor *backgroundColor = UIColorFromRGB(0xD7DDE6);
//    [backgroundColor set];
//    CGContextFillRect(context, rect);
    
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
    UIFontDescriptor *boldFontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    UIFont *font = [UIFont fontWithDescriptor: boldFontDescriptor size:0.0];
    NSInteger titleOffsetY = ((rect.size.height - font.pointSize) / 2) - 1;
    NSString *folderTitle;
    if (section == 0) {
        folderTitle = [@"Global Shared Stories" uppercaseString];
    } else if (section == 1) {
            folderTitle = [@"All Shared Stories" uppercaseString];
    } else if (section == 2) {
        folderTitle = [@"All Stories" uppercaseString];
    } else if ([folderName isEqual:@"read_stories"]) {
        folderTitle = [@"Read Stories" uppercaseString];
    } else if ([folderName isEqual:@"saved_stories"]) {
        folderTitle = [@"Saved Stories" uppercaseString];
    } else {
        folderTitle = [[appDelegate.dictFoldersArray objectAtIndex:section] uppercaseString];
    }
    UIColor *shadowColor = UIColorFromRGB(0xF0F2E9);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 0, [shadowColor CGColor]);

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    [folderTitle
     drawInRect:CGRectMake(36.0, titleOffsetY, rect.size.width - 36 - 36 - countWidth, font.pointSize)
     withAttributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}];
        
    invisibleHeaderButton = [UIButton buttonWithType:UIButtonTypeCustom];
    invisibleHeaderButton.frame = CGRectMake(0, 0, customView.frame.size.width, customView.frame.size.height);
    invisibleHeaderButton.alpha = .1;
    invisibleHeaderButton.tag = section;
    invisibleHeaderButton.accessibilityLabel = [NSString stringWithFormat:@"%@ folder%@", folderTitle, accessibilityCount];
    invisibleHeaderButton.accessibilityTraits = UIAccessibilityTraitNone;
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController
                              action:@selector(didSelectSectionHeader:)
                    forControlEvents:UIControlEventTouchUpInside];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController
                              action:@selector(sectionTapped:)
                    forControlEvents:UIControlEventTouchDown];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController
                              action:@selector(sectionUntapped:)
                    forControlEvents:UIControlEventTouchUpInside];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController
                              action:@selector(sectionUntappedOutside:)
                    forControlEvents:UIControlEventTouchUpOutside];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController
                              action:@selector(sectionUntappedOutside:)
                    forControlEvents:UIControlEventTouchCancel];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController
                              action:@selector(sectionUntappedOutside:)
                    forControlEvents:UIControlEventTouchDragOutside];
    [customView addSubview:invisibleHeaderButton];
    
    if (!appDelegate.hasNoSites) {
        UIButton *disclosureButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *disclosureImage = [UIImage imageNamed:@"disclosure.png"];
        [disclosureButton setImage:disclosureImage forState:UIControlStateNormal];
        disclosureButton.frame = CGRectMake(customView.frame.size.width - 32, 3, 29, 29);

        // Add collapse button to all folders except Everything
        if (section != 0 && section != 2 && ![folderName isEqual:@"read_stories"]) {
            if (!isFolderCollapsed) {
                UIImage *disclosureImage = [UIImage imageNamed:@"disclosure_down.png"];
                [disclosureButton setImage:disclosureImage forState:UIControlStateNormal];
//                disclosureButton.transform = CGAffineTransformMakeRotation(M_PI_2);
            }
            
            disclosureButton.tag = section;
            [disclosureButton addTarget:appDelegate.feedsViewController action:@selector(didCollapseFolder:) forControlEvents:UIControlEventTouchUpInside];

            UIImage *disclosureBorder = [UIImage imageNamed:@"disclosure_border"];
            if ([[[ThemeManager themeManager] theme] isEqualToString:ThemeStyleSepia]) {
                disclosureBorder = [UIImage imageNamed:@"disclosure_border_sepia"];
            } else if ([[[ThemeManager themeManager] theme] isEqualToString:ThemeStyleMedium]) {
                disclosureBorder = [UIImage imageNamed:@"disclosure_border_medium"];
            } else if ([[[ThemeManager themeManager] theme] isEqualToString:ThemeStyleDark]) {
                disclosureBorder = [UIImage imageNamed:@"disclosure_border_dark"];
            }
            [disclosureBorder drawInRect:CGRectMake(customView.frame.size.width - 32, 3, 29, 29)];
        } else {
            // Everything/Saved folder doesn't get a button
            [disclosureButton setUserInteractionEnabled:NO];
        }
        [customView addSubview:disclosureButton];
    }
    
    UIImage *folderImage;
    int folderImageViewX = 10;
    BOOL allowLongPress = NO;
    int width = 20;
    int height = 20;
    
    if (section == 0) {
        folderImage = [UIImage imageNamed:@"ak-icon-global.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 8;
        }
    } else if (section == 1) {
        folderImage = [UIImage imageNamed:@"ak-icon-blurblogs.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 8;
        }
    } else if (section == 2) {
        folderImage = [UIImage imageNamed:@"ak-icon-allstories.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
        allowLongPress = YES;
    } else if ([folderName isEqual:@"saved_stories"]) {
        folderImage = [UIImage imageNamed:@"clock.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else if ([folderName isEqual:@"read_stories"]) {
        folderImage = [UIImage imageNamed:@"g_icn_folder_read.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else {
        if (isFolderCollapsed) {
            folderImage = [UIImage imageNamed:@"g_icn_folder_rss"];
        } else {
            folderImage = [UIImage imageNamed:@"g_icn_folder"];
        }
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        } else {
            folderImageViewX = 7;
        }
        allowLongPress = YES;
    }
    [folderImage drawInRect:CGRectMake(folderImageViewX, 8, width, height)];
    
    [customView setAutoresizingMask:UIViewAutoresizingNone];
    
    if (isFolderCollapsed) {
        [self insertSubview:customView belowSubview:unreadCount];
    } else {
        [self addSubview:customView];
    }

    if (allowLongPress) {
        UILongPressGestureRecognizer *longpress = [[UILongPressGestureRecognizer alloc]
                                                   initWithTarget:self action:@selector(handleLongPress:)];
        longpress.minimumPressDuration = 1.0;
        longpress.delegate = self;
        [self addGestureRecognizer:longpress];
    }
}

- (UIFontDescriptor *)fontDescriptorUsingPreferredSize:(NSString *)textStyle {
    if (fontDescriptorSize) return fontDescriptorSize;

    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle: textStyle];
    fontDescriptorSize = [fontDescriptor fontDescriptorWithSymbolicTraits: UIFontDescriptorTraitBold];

    if (![userPreferences boolForKey:@"use_system_font_size"]) {
        if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xs"]) {
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:10.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"small"]) {
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:11.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"medium"]) {
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:12.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"large"]) {
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:15.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xl"]) {
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:17.0f];
        }
    }
    
    return fontDescriptorSize;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) return;
    if (section < 2) return;
    
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSString *longPressTitle = [preferences stringForKey:@"long_press_feed_title"];
    NSString *folderTitle = [appDelegate.dictFoldersArray objectAtIndex:section];
    NSArray *feedIds = [self.appDelegate feedIdsForFolderTitle:folderTitle];
    NSString *collectionTitle = [folderTitle isEqual:@"everything"] ? @"everything" : @"entire folder";
    
    if ([longPressTitle isEqualToString:@"mark_read_choose_days"]) {
        [self.appDelegate showMarkReadMenuWithFeedIds:feedIds collectionTitle:collectionTitle sourceView:self sourceRect:self.bounds completionHandler:^(BOOL marked){
            [appDelegate.feedsViewController sectionUntappedOutside:invisibleHeaderButton];
        }];
    } else if ([longPressTitle isEqualToString:@"mark_read_immediate"]) {
        [appDelegate.feedsViewController markFeedsRead:feedIds cutoffDays:0];
    }
}

@end
