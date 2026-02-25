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
    
    [UIColorFromLightSepiaMediumDarkRGB(0xF7F8F5, 0xF3E2CB, 0x48484A, 0x38383A) set];
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
    UIColor *backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xEAECE6, 0xEBDDCC, 0x3A3A3C, 0x2C2C2E);
    UIColor *textColor = UIColorFromLightSepiaMediumDarkRGB(0x4C4D4A, 0x5C4A3D, 0xE0E0E0, 0xE8E8E8);
    UIFontDescriptor *boldFontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    UIFont *font = [UIFont fontWithName:@"WhitneySSm-Medium" size:boldFontDescriptor.pointSize];
    NSInteger titleOffsetY = ((rect.size.height - font.pointSize) / 2) - 1;
    NSString *folderTitle;
    if (section == NewsBlurTopSectionDashboard) {
        folderTitle = @"NewsBlur Dashboard";
    } else if (section == NewsBlurTopSectionInfrequentSiteStories) {
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
    } else if ([folderName isEqual:@"try_feed"]) {
        folderTitle = @"Trying Feed";
    } else {
        folderTitle = folderDisplayName;
        backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xF0F2ED, 0xF3E2CB, 0x414143, 0x323234);
    }

    [backgroundColor set];
    CGContextFillRect(context, rect);

    UIColor *shadowColor = UIColorFromLightSepiaMediumDarkRGB(0xF0F2E9, 0xEBDDCC, 0x2C2C2E, 0x1C1C1E);
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
    invisibleHeaderButton.alpha = .2;
    invisibleHeaderButton.backgroundColor = self.selectionColor;
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

        // Add collapse-all button for All Site Stories
        if (section == NewsBlurTopSectionAllStories) {
            BOOL anyExpanded = [appDelegate.feedsViewController anyFolderExpanded];
            UIImage *disclosureImage = anyExpanded ?
                [UIImage imageNamed:@"disclosure_down.png"] :
                [UIImage imageNamed:@"disclosure.png"];
            [disclosureButton setImage:disclosureImage forState:UIControlStateNormal];

            disclosureButton.tag = section;
            [disclosureButton addTarget:appDelegate.feedsViewController action:@selector(didToggleAllFolders:) forControlEvents:UIControlEventTouchUpInside];

            UIImage *disclosureBorder = [UIImage imageNamed:@"disclosure_border"];
            if ([[[ThemeManager themeManager] effectiveTheme] isEqualToString:ThemeStyleSepia]) {
                disclosureBorder = [UIImage imageNamed:@"disclosure_border_sepia"];
            } else if ([[[ThemeManager themeManager] effectiveTheme] isEqualToString:ThemeStyleMedium]) {
                disclosureBorder = [UIImage imageNamed:@"disclosure_border_medium"];
            } else if ([[[ThemeManager themeManager] effectiveTheme] isEqualToString:ThemeStyleDark]) {
                disclosureBorder = [UIImage imageNamed:@"disclosure_border_dark"];
            }
            [disclosureBorder drawInRect:CGRectMake(rect.origin.x + customView.frame.size.width - 32, CGRectGetMidY(rect)-disclosureHeight/2 - 1, disclosureHeight, disclosureHeight)];
        // Add collapse button to regular folders
        } else if (section != NewsBlurTopSectionDashboard && section != NewsBlurTopSectionInfrequentSiteStories && ![folderName isEqual:@"read_stories"] && ![folderName isEqual:@"interactions"] && ![folderName isEqual:@"river_global"] && ![folderName isEqual:@"widget_stories"] && ![folderName isEqual:@"try_feed"]) {
            if (!isFolderCollapsed) {
                UIImage *disclosureImage = [UIImage imageNamed:@"disclosure_down.png"];
                [disclosureButton setImage:disclosureImage forState:UIControlStateNormal];
            }

            disclosureButton.tag = section;
            [disclosureButton addTarget:appDelegate.feedsViewController action:@selector(didCollapseFolder:) forControlEvents:UIControlEventTouchUpInside];

            UIImage *disclosureBorder = [UIImage imageNamed:@"disclosure_border"];
            if ([[[ThemeManager themeManager] effectiveTheme] isEqualToString:ThemeStyleSepia]) {
                disclosureBorder = [UIImage imageNamed:@"disclosure_border_sepia"];
            } else if ([[[ThemeManager themeManager] effectiveTheme] isEqualToString:ThemeStyleMedium]) {
                disclosureBorder = [UIImage imageNamed:@"disclosure_border_medium"];
            } else if ([[[ThemeManager themeManager] effectiveTheme] isEqualToString:ThemeStyleDark]) {
                disclosureBorder = [UIImage imageNamed:@"disclosure_border_dark"];
            }
            [disclosureBorder drawInRect:CGRectMake(rect.origin.x + customView.frame.size.width - 32, CGRectGetMidY(rect)-disclosureHeight/2 - 1, disclosureHeight, disclosureHeight)];
        } else {
            // Dashboard/Infrequent/other special sections don't get a button
            [disclosureButton setUserInteractionEnabled:NO];
        }
        [customView addSubview:disclosureButton];
    }
    
    UIImage *folderImage;
    int folderImageViewX = 10;
    BOOL allowLongPress = NO;
    BOOL hasCustomIcon = NO;
    int width = 20;
    int height = 20;

    if (section == NewsBlurTopSectionDashboard) {
        folderImage = [UIImage imageNamed:@"saved-stories"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
        allowLongPress = YES;
    } else if (section == NewsBlurTopSectionInfrequentSiteStories) {
        folderImage = [UIImage imageNamed:@"ak-icon-infrequent.png"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
        allowLongPress = YES;
    } else if (section == NewsBlurTopSectionAllStories) {
        folderImage = [UIImage imageNamed:@"all-stories"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
        allowLongPress = NO;
    } else if ([folderName isEqual:@"river_global"]) {
        folderImage = [UIImage imageNamed:@"global-shares"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 8;
        }
    } else if ([folderName isEqual:@"river_blurblogs"]) {
        folderImage = [UIImage imageNamed:@"all-shares"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 8;
        }
    } else if ([folderName isEqual:@"saved_searches"]) {
        folderImage = [UIImage imageNamed:@"search"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else if ([folderName isEqual:@"saved_stories"]) {
        folderImage = [UIImage imageNamed:@"saved-stories"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else if ([folderName isEqual:@"read_stories"]) {
        folderImage = [UIImage imageNamed:@"indicator-unread"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else if ([folderName isEqual:@"widget_stories"]) {
        folderImage = [UIImage imageNamed:@"g_icn_folder_widget.png"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else if ([folderName isEqual:@"try_feed"]) {
        folderImage = [UIImage imageNamed:@"discover"];
        if (!appDelegate.isPhone) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else {
        // Check for custom folder icon first
        NSDictionary *customIcon = appDelegate.dictFolderIcons[folderName];
        if (customIcon && ![customIcon[@"icon_type"] isEqualToString:@"none"]) {
            UIImage *customImage = [CustomIconRenderer renderIcon:customIcon size:CGSizeMake(width, height)];
            if (customImage) {
                folderImage = customImage;
                hasCustomIcon = YES;
            }
        }

        // Fall back to default folder icon if no custom icon
        if (!folderImage) {
            if (isFolderCollapsed) {
                folderImage = [UIImage imageNamed:@"folder-closed"];
            } else {
                folderImage = [UIImage imageNamed:@"folder-open"];
            }
        }
        if (!appDelegate.isPhone) {
        } else {
            folderImageViewX = 7;
        }
        allowLongPress = YES;
    }

    // Only tint default icons, not custom icons (custom icons already have their color applied)
    if (!hasCustomIcon) {
        folderImage = [folderImage imageWithTintColor:UIColorFromLightDarkRGB(0x95968F, 0x95968F)];
    }
    
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
