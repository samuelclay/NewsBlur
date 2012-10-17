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

@implementation FolderTitleView

@synthesize appDelegate;
@synthesize section;
@synthesize unreadCount;

- (void)setNeedsDisplay {
    [unreadCount setNeedsDisplay];
    
    [super setNeedsDisplay];
}

- (void) drawRect:(CGRect)rect {
    
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (UIView *subview in self.subviews) {
        [subview removeFromSuperview];
    }
    
    NSString *folderName;
    if (section == 0) {
        folderName = @"river_blurblogs";
    } else {
        folderName = [appDelegate.dictFoldersArray objectAtIndex:section];
    }
    NSString *collapseKey = [NSString stringWithFormat:@"folderCollapsed:%@", folderName];
    bool isFolderCollapsed = [userPreferences boolForKey:collapseKey];
    int countWidth = 0;
    
    if (isFolderCollapsed) {
        UnreadCounts *counts = [appDelegate splitUnreadCountForFolder:folderName];
        unreadCount = [[UnreadCountView alloc] initWithFrame:rect];
        unreadCount.appDelegate = appDelegate;
        unreadCount.opaque = NO;
        unreadCount.psCount = counts.ps;
        unreadCount.ntCount = counts.nt;
        
        [unreadCount calculateOffsets:counts.ps nt:counts.nt];
        countWidth = [unreadCount offsetWidth];
        [self addSubview:unreadCount];
    } else if (folderName == @"saved_stories") {
        unreadCount = [[UnreadCountView alloc] initWithFrame:rect];
        unreadCount.appDelegate = appDelegate;
        unreadCount.opaque = NO;
        unreadCount.psCount = appDelegate.savedStoriesCount;
        unreadCount.blueCount = appDelegate.savedStoriesCount;
        
        [unreadCount calculateOffsets:appDelegate.savedStoriesCount nt:0];
        countWidth = [unreadCount offsetWidth];
        [self addSubview:unreadCount];
    }
    
    // create the parent view that will hold header Label
    UIView* customView = [[UIView alloc] initWithFrame:rect];

    // Background
    UIColor *backgroundColor = UIColorFromRGB(0xD7DDE6);
    [backgroundColor set];
    CGContextFillRect(context, rect);
    
    // Borders
    UIColor *topColor = UIColorFromRGB(0xE7EDF6);
    CGContextSetStrokeColor(context, CGColorGetComponents([topColor CGColor]));
    
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 0, 0.5f);
    CGContextAddLineToPoint(context, rect.size.width, 0.5f);
    CGContextStrokePath(context);
    
    // bottom border
    UIColor *bottomColor = UIColorFromRGB(0xB7BDC6);
    CGContextSetStrokeColor(context, CGColorGetComponents([bottomColor CGColor]));
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 0, rect.size.height - .5f);
    CGContextAddLineToPoint(context, rect.size.width, rect.size.height - .5f);
    CGContextStrokePath(context);
    
    // Folder title
    UIColor *textColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    [textColor set];
    UIFont *font = [UIFont boldSystemFontOfSize:11];
    NSString *folderTitle;
    if (section == 0) {
        folderTitle = [@"All Blurblog Stories" uppercaseString];
    } else if (section == 1) {
        folderTitle = [@"All Stories" uppercaseString];
    } else if (folderName == @"saved_stories") {
        folderTitle = [@"Saved Stories" uppercaseString];
    } else {
        folderTitle = [[appDelegate.dictFoldersArray objectAtIndex:section] uppercaseString];
    }
    UIColor *shadowColor = UIColorFromRGB(0xE7EDF6);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 0, [shadowColor CGColor]);
    
    [folderTitle
     drawInRect:CGRectMake(36.0, 7, rect.size.width - 36 - 36 - countWidth, 14)
     withFont:font
     lineBreakMode:UILineBreakModeTailTruncation
     alignment:UITextAlignmentLeft];
        
    UIButton *invisibleHeaderButton = [UIButton buttonWithType:UIButtonTypeCustom];
    invisibleHeaderButton.frame = CGRectMake(0, 0, customView.frame.size.width, customView.frame.size.height);
    invisibleHeaderButton.alpha = .1;
    invisibleHeaderButton.tag = section;
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController action:@selector(didSelectSectionHeader:) forControlEvents:UIControlEventTouchUpInside];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController action:@selector(sectionTapped:) forControlEvents:UIControlEventTouchDown];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController action:@selector(sectionUntapped:) forControlEvents:UIControlEventTouchUpInside];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController action:@selector(sectionUntappedOutside:) forControlEvents:UIControlEventTouchUpOutside];
    [customView addSubview:invisibleHeaderButton];
    
    if (!appDelegate.hasNoSites) {
        UIButton *disclosureButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *disclosureImage = [UIImage imageNamed:@"disclosure.png"];
        [disclosureButton setImage:disclosureImage forState:UIControlStateNormal];
        disclosureButton.frame = CGRectMake(customView.frame.size.width - 32, -1, 29, 29);

        // Add collapse button to all folders except Everything
        if (section != 1 && folderName != @"saved_stories") {
            if (!isFolderCollapsed) {
                disclosureButton.transform = CGAffineTransformMakeRotation(M_PI_2);
            }
            
            disclosureButton.tag = section;
            [disclosureButton addTarget:appDelegate.feedsViewController action:@selector(didCollapseFolder:) forControlEvents:UIControlEventTouchUpInside];

            UIImage *disclosureBorder = [UIImage imageNamed:@"disclosure_border.png"];
            [disclosureBorder drawInRect:CGRectMake(customView.frame.size.width - 32, -1, 29, 29)];
        } else {
            // Everything/Saved folder doesn't get a button
            [disclosureButton setUserInteractionEnabled:NO];
        }
        [customView addSubview:disclosureButton];
    }
    
    UIImage *folderImage;
    int folderImageViewX = 10;
    
    if (section == 0) {
        folderImage = [UIImage imageNamed:@"group.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 8;
        }
    } else if (section == 1) {
        folderImage = [UIImage imageNamed:@"archive.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else if (folderName == @"saved_stories") {
        folderImage = [UIImage imageNamed:@"clock.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else {
        if (isFolderCollapsed) {
            folderImage = [UIImage imageNamed:@"folder_collapsed.png"];
        } else {
            folderImage = [UIImage imageNamed:@"folder_2.png"];
        }
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        } else {
            folderImageViewX = 7;
        }
    }
    [folderImage drawInRect:CGRectMake(folderImageViewX, 3, 20, 20)];
    
    [customView setAutoresizingMask:UIViewAutoresizingNone];
    
    if (isFolderCollapsed) {
        [self insertSubview:customView belowSubview:unreadCount];
    } else {
        [self addSubview:customView];
    }
}

@end
