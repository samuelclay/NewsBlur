//
//  FolderTitleView.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "NewsBlurAppDelegate.h"
#import "FolderTitleView.h"
#import "UnreadCountView.h"
#import "NewsBlur-Swift.h"

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
    
    [UIColorFromRGB(0xF7F8F5) set];
    CGContextFillRect(context, rect);
    
    NSString *folderName = appDelegate.dictFoldersArray[section];
    NSString *collapseKey = [NSString stringWithFormat:@"folderCollapsed:%@", folderName];
    BOOL isFolderCollapsed = [userPreferences boolForKey:collapseKey];
    BOOL isSavedStoriesFeed = self.appDelegate.isSavedStoriesIntelligenceMode;
    NSInteger countWidth = 0;
    NSString *accessibilityCount = @"";
    NSArray *folderComponents = [folderName componentsSeparatedByString:@" ▸ "];
    NSString *folderDisplayName = folderComponents.lastObject;
    
    CGFloat indentationOffset = (folderComponents.count - 1) * 28;
    rect.origin.x += indentationOffset;
    rect.size.width -= indentationOffset;
    
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
    } else if ([folderName isEqual:@"saved_searches"]) {
        NSInteger count = appDelegate.savedSearchesCount;
        unreadCount = [[UnreadCountView alloc] initWithFrame:CGRectInset(rect, 0, 2)];
        unreadCount.appDelegate = appDelegate;
        unreadCount.opaque = NO;
        unreadCount.psCount = count;
        unreadCount.blueCount = count;
        
        [unreadCount calculateOffsets:count nt:0];
        countWidth = [unreadCount offsetWidth];
        [self addSubview:unreadCount];
        
        accessibilityCount = [NSString stringWithFormat:@", %@ searches", @(count)];
    } else if (isFolderCollapsed && !isSavedStoriesFeed) {
        UnreadCounts *counts = [appDelegate splitUnreadCountForFolder:folderName];
        unreadCount = [[UnreadCountView alloc] initWithFrame:CGRectMake(rect.origin.x, 0, CGRectGetWidth(rect), CGRectGetHeight(rect))];
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
    
    // Folder title
    UIColor *backgroundColor = UIColorFromRGB(0xEAECE6);
    UIColor *textColor = UIColorFromRGB(0x4C4D4A);
    UIFontDescriptor *boldFontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    UIFont *font = [UIFont fontWithName:@"WhitneySSm-Medium" size:boldFontDescriptor.pointSize];
    NSInteger titleOffsetY = ((rect.size.height - font.pointSize) / 2) - 1;
    NSString *folderTitle;
    if (section == NewsBlurTopSectionInfrequentSiteStories) {
        folderTitle = @"Infrequent Site Stories";
    } else if (section == NewsBlurTopSectionAllStories) {
        folderTitle = @"All Site Stories";
    } else if ([folderName isEqual:@"widget_stories"]) {
        folderTitle = @"Widget Site Stories";
    } else if ([folderName isEqual:@"read_stories"]) {
        folderTitle = @"Read Stories";
    } else if ([folderName isEqual:@"river_global"]) {
        folderTitle = @"Global Shared Stories";
    } else if ([folderName isEqual:@"river_blurblogs"]) {
        folderTitle = @"All Shared Stories";
    } else if ([folderName isEqual:@"saved_stories"]) {
        folderTitle = @"Saved Stories";
    } else if ([folderName isEqual:@"saved_searches"]) {
        folderTitle = @"Saved Searches";
    } else {
        folderTitle = folderDisplayName;
        backgroundColor = UIColorFromRGB(0xF7F8F5);
    }
    
    [backgroundColor set];
    CGContextFillRect(context, rect);
    
    UIColor *shadowColor = UIColorFromRGB(0xF0F2E9);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 0, [shadowColor CGColor]);

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    [folderTitle
     drawInRect:CGRectMake(rect.origin.x + 36.0, titleOffsetY, rect.size.width - 36 - 36 - countWidth, font.pointSize + 5)
     withAttributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}];
        
    invisibleHeaderButton = [UIButton buttonWithType:UIButtonTypeCustom];
    invisibleHeaderButton.frame = CGRectMake(rect.origin.x, 0, customView.frame.size.width, customView.frame.size.height);
    invisibleHeaderButton.layer.cornerRadius = 10;
    invisibleHeaderButton.clipsToBounds = YES;
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
        NSInteger disclosureHeight = 29;
        UIButton *disclosureButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *disclosureImage = [UIImage imageNamed:@"disclosure.png"];
        [disclosureButton setImage:disclosureImage forState:UIControlStateNormal];
        disclosureButton.frame = CGRectMake(customView.frame.size.width - 32, CGRectGetMidY(rect)-disclosureHeight/2-1, disclosureHeight, disclosureHeight);

        // Add collapse button to all folders except Everything
        if (section != NewsBlurTopSectionInfrequentSiteStories && section != NewsBlurTopSectionAllStories && ![folderName isEqual:@"read_stories"] && ![folderName isEqual:@"river_global"] && ![folderName isEqual:@"widget_stories"]) {
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
            [disclosureBorder drawInRect:CGRectMake(rect.origin.x + customView.frame.size.width - 32, CGRectGetMidY(rect)-disclosureHeight/2 - 1, disclosureHeight, disclosureHeight)];
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
    
    if (section == NewsBlurTopSectionInfrequentSiteStories) {
        folderImage = [UIImage imageNamed:@"ak-icon-infrequent.png"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
        allowLongPress = YES;
    } else if (section == NewsBlurTopSectionAllStories) {
        folderImage = [UIImage imageNamed:@"all-stories"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
        allowLongPress = NO;
    } else if ([folderName isEqual:@"river_global"]) {
        folderImage = [UIImage imageNamed:@"global-shares"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 8;
        }
    } else if ([folderName isEqual:@"river_blurblogs"]) {
        folderImage = [UIImage imageNamed:@"all-shares"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 8;
        }
    } else if ([folderName isEqual:@"saved_searches"]) {
        folderImage = [UIImage imageNamed:@"search"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else if ([folderName isEqual:@"saved_stories"]) {
        folderImage = [UIImage imageNamed:@"saved-stories"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else if ([folderName isEqual:@"read_stories"]) {
        folderImage = [UIImage imageNamed:@"indicator-unread"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else if ([folderName isEqual:@"widget_stories"]) {
        folderImage = [UIImage imageNamed:@"g_icn_folder_widget.png"];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else {
        if (isFolderCollapsed) {
            folderImage = [UIImage imageNamed:@"folder-closed"];
        } else {
            folderImage = [UIImage imageNamed:@"folder-open"];
        }
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        } else {
            folderImageViewX = 7;
        }
        allowLongPress = YES;
    }
    
    folderImage = [folderImage imageWithTintColor:UIColorFromLightDarkRGB(0x95968F, 0x95968F)];
    
    [folderImage drawInRect:CGRectMake(rect.origin.x + folderImageViewX, CGRectGetMidY(rect)-height/2, width, height)];
    
    [customView setAutoresizingMask:UIViewAutoresizingNone];
    
    if (isFolderCollapsed && !isSavedStoriesFeed) {
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
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:11.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"small"]) {
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:13.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"medium"]) {
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:14.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"large"]) {
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:17.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xl"]) {
            fontDescriptorSize = [fontDescriptorSize fontDescriptorWithSize:19.0f];
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
            [self.appDelegate.folderCountCache removeObjectForKey:folderTitle];
            [self.appDelegate.feedsViewController sectionUntappedOutside:self.invisibleHeaderButton];
            [self.appDelegate.feedsViewController.feedTitlesTable reloadData];
        }];
    } else if ([longPressTitle isEqualToString:@"mark_read_immediate"]) {
        [self.appDelegate.folderCountCache removeObjectForKey:folderTitle];
        [self.appDelegate.feedsViewController markFeedsRead:feedIds cutoffDays:0];
        [self.appDelegate.feedsViewController.feedTitlesTable reloadData];
    }
}

@end
