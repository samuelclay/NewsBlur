//
//  FeedTableCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/18/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "FeedTableCell.h"
#import "UnreadCountView.h"
#import "ABTableViewCell.h"
#import "MCSwipeTableViewCell.h"
#import "NewsBlur-Swift.h"

static UIFont *textFont = nil;

@implementation FeedTableCell

@synthesize appDelegate;
@synthesize feedTitle;
@synthesize feedFavicon;
@synthesize positiveCount = _positiveCount;
@synthesize neutralCount = _neutralCount;
@synthesize negativeCount = _negativeCount;
@synthesize negativeCountStr;
@synthesize isSocial;
@synthesize isSaved;
@synthesize unreadCount;

+ (void) initialize{
    if (self == [FeedTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
    }
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
        
        unreadCount = [UnreadCountView alloc];
        unreadCount.appDelegate = self.appDelegate;
        self.unreadCount = unreadCount;
        
        cellContent = [[FeedTableCellView alloc] initWithFrame:self.frame];
        cellContent.opaque = YES;
        
        // Clear out half pixel border on top and bottom that the draw code can't touch
        UIView *selectedBackground = [[UIView alloc] init];
        [selectedBackground setBackgroundColor:[UIColor clearColor]];
        self.selectedBackgroundView = selectedBackground;

        [self.contentView addSubview:cellContent];
    }

    return self;
}

- (void)drawRect:(CGRect)rect {
    ((FeedTableCellView *)cellContent).cell = self;
    
    CGFloat indentationOffset = self.indentationLevel * self.indentationWidth;
    rect.origin.x += indentationOffset;
    rect.size.width -= indentationOffset;
    
    cellContent.frame = rect;
    [cellContent setNeedsDisplay];
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
    [super setHighlighted:highlighted animated:animated];
    
    [self setNeedsDisplay];
}

- (void) setPositiveCount:(int)ps {
    if (ps == _positiveCount) return;
    
    _positiveCount = ps;
//    [cellContent setNeedsDisplay];
}

- (void) setNeutralCount:(int)nt {
    if (nt == _neutralCount) return;
    
    _neutralCount = nt;
//    [cellContent setNeedsDisplay];
}

- (void) setNegativeCount:(int)ng {
    if (ng == _negativeCount) return;
    
    _negativeCount = ng;
    _negativeCountStr = [NSString stringWithFormat:@"%d", ng];
//    [cellContent setNeedsDisplay];
}

- (void)setupGestures {
    if (self.isSaved) {
        self.shouldDrag = NO;
        return;
    }
    
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSString *swipe = [preferences stringForKey:@"feed_swipe_left"];
    NSString *iconName;
    
    if (self.isSocial) {
        iconName = @"menu_icn_fetch_subscribers.png";
    } else if ([swipe isEqualToString:@"notifications"]) {
        iconName = @"menu_icn_notifications.png";
    } else if ([swipe isEqualToString:@"statistics"]) {
        iconName = @"menu_icn_statistics.png";
    } else {
        iconName = @"train.png";
    }
    
    [self setDelegate:(FeedsViewController <MCSwipeTableViewCellDelegate> *)appDelegate.feedsViewController];
    [self setFirstStateIconName:(iconName)
                     firstColor:UIColorFromRGB(0xA4D97B)
            secondStateIconName:nil
                    secondColor:nil
                  thirdIconName:@"indicator-unread"
                     thirdColor:UIColorFromRGB(0x6A6659)
                 fourthIconName:nil
                    fourthColor:nil];
    
    self.mode = MCSwipeTableViewCellModeSwitch;
    self.shouldAnimatesIcons = NO;
}

- (void)redrawUnreadCounts {
    [((FeedTableCellView *)cellContent) redrawUnreadCounts];
}


- (UIFontDescriptor *)fontDescriptorUsingPreferredSize:(NSString *)textStyle {
    UIFontDescriptor *fontDescriptor = appDelegate.fontDescriptorTitleSize;
    if (fontDescriptor) return fontDescriptor;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];

    fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:textStyle];
    if (![userPreferences boolForKey:@"use_system_font_size"]) {
        if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xs"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:10.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"small"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:12.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"medium"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:13.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"large"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:16.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xl"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:18.0f];
        }
    }
    
    return fontDescriptor;
}


@end

@implementation FeedTableCellView

@synthesize cell;

- (void)drawRect:(CGRect)r {
    if (!cell) {
        return;
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    BOOL isHighlighted = cell.highlighted || cell.selected;
    UIColor *backgroundColor;
    
    backgroundColor = cell.isSocial ? UIColorFromRGB(0xD8E3DB) :
                      cell.isSearch ? UIColorFromRGB(0xDBDFE6) :
                      cell.isSaved ? UIColorFromRGB(0xDFDCD6) :
                      UIColorFromRGB(0xF7F8F5);

//    [backgroundColor set];
    self.backgroundColor = backgroundColor;
    cell.backgroundColor = backgroundColor;
    
    if (isHighlighted) {
        UIColor *highlightColor = UIColorFromLightSepiaMediumDarkRGB(0xFFFFD2, 0xFFFFD2, 0x304050, 0x000022);
        
        CGContextSetFillColorWithColor(context, highlightColor.CGColor);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:8];
        CGContextAddPath(context, path.CGPath);
        CGContextFillPath(context);
    }
    
    if (cell.isInactive) {
        CGRect imageRect = CGRectMake(CGRectGetMaxX(r) - 25, CGRectGetMidY(r) - 8, 16, 16);
        [[UIImage imageNamed:@"mute_gray.png"] drawInRect:imageRect];
    } else if (cell.savedStoriesCount > 0) {
        [cell.unreadCount drawInRect:r ps:cell.savedStoriesCount nt:0 listType:NBFeedListSaved];
    } else {
        [cell.unreadCount drawInRect:r ps:cell.positiveCount nt:cell.neutralCount
                        listType:(cell.isSocial ? NBFeedListSocial : cell.isSaved ? NBFeedListSaved : NBFeedListFeed)];
    }
    
    UIColor *textColor = isHighlighted ?
                         UIColorFromRGB(NEWSBLUR_BLACK_COLOR):
                         UIColorFromRGB(0x3A3A3A);
    UIFont *font;
    UIFontDescriptor *fontDescriptor = [cell fontDescriptorUsingPreferredSize:UIFontTextStyleFootnote];
    if (cell.negativeCount || cell.neutralCount || cell.positiveCount) {
        UIFontDescriptor *boldFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
        font = [UIFont fontWithName:@"WhitneySSm-Medium" size:boldFontDescriptor.pointSize];
    } else {
        font = [UIFont fontWithName:@"WhitneySSm-Book" size:fontDescriptor.pointSize];
    }
    NSInteger titleOffsetY = ((r.size.height - font.pointSize) / 2) - 1;
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    CGSize faviconSize;
    if (cell.isSocial) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            faviconSize = CGSizeMake(28, 28);
            UIImage *feedIcon = [Utilities roundCorneredImage:cell.feedFavicon radius:4 convertToSize:faviconSize];
            [feedIcon drawInRect:CGRectMake(9.0, CGRectGetMidY(r)-faviconSize.height/2, faviconSize.width, faviconSize.height)];
            [cell.feedTitle drawInRect:CGRectMake(46, titleOffsetY, r.size.width - ([cell.unreadCount offsetWidth] + 36) - 10 - 16, font.pointSize*1.4)
                   withAttributes:@{NSFontAttributeName: font,
                                    NSForegroundColorAttributeName: textColor,
                                    NSParagraphStyleAttributeName: paragraphStyle}];
        } else {
            faviconSize = CGSizeMake(26, 26);
            UIImage *feedIcon = [Utilities roundCorneredImage:cell.feedFavicon radius:4 convertToSize:faviconSize];
            [feedIcon drawInRect:CGRectMake(9.0, CGRectGetMidY(r)-faviconSize.height/2, faviconSize.width, faviconSize.height)];
            [cell.feedTitle drawInRect:CGRectMake(42, titleOffsetY, r.size.width - ([cell.unreadCount offsetWidth] + 36) - 10 - 12, font.pointSize*1.4)
                   withAttributes:@{NSFontAttributeName: font,
                                    NSForegroundColorAttributeName: textColor,
                                    NSParagraphStyleAttributeName: paragraphStyle}];
        }
    } else {
        faviconSize = CGSizeMake(16, 16);
        UIImage *feedIcon = [Utilities roundCorneredImage:cell.feedFavicon radius:4 convertToSize:faviconSize];
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            [feedIcon drawInRect:CGRectMake(12.0, CGRectGetMidY(r)-faviconSize.height/2, faviconSize.width, faviconSize.height)];
            [cell.feedTitle drawInRect:CGRectMake(36.0, titleOffsetY, r.size.width - ([cell.unreadCount offsetWidth] + 36) - 10, font.pointSize*1.4)
                   withAttributes:@{NSFontAttributeName: font,
                                    NSForegroundColorAttributeName: textColor,
                                    NSParagraphStyleAttributeName: paragraphStyle}];
        } else {
            [feedIcon drawInRect:CGRectMake(9.0, CGRectGetMidY(r)-faviconSize.height/2, faviconSize.width, faviconSize.height)];
            [cell.feedTitle drawInRect:CGRectMake(34.0, titleOffsetY, r.size.width - ([cell.unreadCount offsetWidth] + 36) - 10, font.pointSize*1.4)
                   withAttributes:@{NSFontAttributeName: font,
                                    NSForegroundColorAttributeName: textColor,
                                    NSParagraphStyleAttributeName: paragraphStyle}];
        }
    }
}

- (void)redrawUnreadCounts {
    if (cell.savedStoriesCount) {
        cell.unreadCount.blueCount = cell.savedStoriesCount;
    } else if (cell.isSaved) {
        cell.unreadCount.blueCount = cell.positiveCount;
    } else {
        cell.unreadCount.psCount = cell.positiveCount;
        cell.unreadCount.ntCount = cell.neutralCount;
    }
    [cell.unreadCount setNeedsLayout];
}

@end
