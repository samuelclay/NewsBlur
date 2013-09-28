//
//  FeedDetailTableCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "FeedDetailTableCell.h"
#import "ABTableViewCell.h"
#import "UIView+TKCategory.h"
#import "Utilities.h"
#import "MCSwipeTableViewCell.h"

static UIFont *textFont = nil;
static UIFont *indicatorFont = nil;

@class FeedDetailViewController;

@implementation FeedDetailTableCell

@synthesize storyTitle;
@synthesize storyAuthor;
@synthesize storyDate;
@synthesize storyScore;
@synthesize siteTitle;
@synthesize siteFavicon;
@synthesize isRead;
@synthesize isStarred;
@synthesize isShared;
@synthesize isShort;
@synthesize isRiverOrSocial;
@synthesize feedColorBar;
@synthesize feedColorBarTopBorder;
@synthesize hasAlpha;


#define leftMargin 30
#define rightMargin 18


+ (void) initialize {
    if (self == [FeedDetailTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
        indicatorFont = [UIFont boldSystemFontOfSize:12];
    }
}

- (void)setupGestures {
    NSString *unreadIcon;
    if (storyScore == -1) {
        unreadIcon = @"g_icn_hidden.png";
    } else if (storyScore == 1) {
        unreadIcon = @"g_icn_focus.png";
    } else {
        unreadIcon = @"g_icn_unread.png";
    }

    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    [self setDelegate:appDelegate.feedDetailViewController];
    [self setFirstStateIconName:@"clock.png"
                     firstColor:[UIColor colorWithRed:85.0 / 255.0 green:213.0 / 255.0 blue:80.0 / 255.0 alpha:1.0]
            secondStateIconName:nil
                    secondColor:nil
                  thirdIconName:unreadIcon
                     thirdColor:[UIColor colorWithRed:254.0 / 255.0 green:217.0 / 255.0 blue:56.0 / 255.0 alpha:1.0]
                 fourthIconName:nil
                    fourthColor:nil];
    
//    [self.contentView setBackgroundColor:[UIColor whiteColor]];
    
    // Setting the default inactive state color to the tableView background color
//    [self setDefaultColor:self.tableView.backgroundView.backgroundColor];
    
    //
    [self setSelectionStyle:UITableViewCellSelectionStyleGray];
    
    self.mode = MCSwipeTableViewCellModeSwitch;
    self.shouldAnimatesIcons = NO;
}

@end

@implementation FeedDetailTableCellView

@synthesize cell;

- (void)drawRect:(CGRect)r {
    int adjustForSocial = 3;
    if (cell.isRiverOrSocial) {
        adjustForSocial = 20;
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding
    
    UIColor *backgroundColor;
    backgroundColor = cell.highlighted || cell.selected ?
                      UIColorFromRGB(0xFFFDEF) : UIColorFromRGB(0xf4f4f4);
    [backgroundColor set];
    
    CGContextFillRect(context, r);
    
    UIColor *textColor;
    UIFont *font;
    
    if (cell.isRead) {
        font = [UIFont fontWithName:@"Helvetica" size:11];
        textColor = UIColorFromRGB(0x808080);
    } else {
        font = [UIFont fontWithName:@"Helvetica-Bold" size:11];
        textColor = UIColorFromRGB(0x606060);
        
    }
    if (cell.highlighted || cell.selected) {
        textColor = UIColorFromRGB(0x686868);
    }
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    
    if (cell.isRiverOrSocial) {
        [cell.siteTitle drawInRect:CGRectMake(leftMargin + 20, 7, rect.size.width - 20, 21)
                    withAttributes:@{NSFontAttributeName: font,
                                     NSForegroundColorAttributeName: textColor,
                                     NSParagraphStyleAttributeName: paragraphStyle}];
        
        if (cell.isRead) {
            font = [UIFont fontWithName:@"Helvetica" size:12];
            textColor = UIColorFromRGB(0x606060);
            
        } else {
            textColor = UIColorFromRGB(0x333333);
            font = [UIFont fontWithName:@"Helvetica-Bold" size:12];
        }
        if (cell.highlighted || cell.selected) {
            textColor = UIColorFromRGB(0x686868);
        }
    }
    
    // story title
    CGSize theSize = [cell.storyTitle
                      boundingRectWithSize:CGSizeMake(rect.size.width, 30.0)
                      options:nil
                      attributes:@{NSFontAttributeName: font,
                                   NSParagraphStyleAttributeName: paragraphStyle}
                      context:nil].size;
    
    int storyTitleY = 7 + adjustForSocial + ((30 - theSize.height)/2);
    if (cell.isShort) {
        storyTitleY = 7 + adjustForSocial + 2;
    }
    int storyTitleX = leftMargin;
    if (cell.isStarred) {
        UIImage *savedIcon = [UIImage imageNamed:@"clock"];
        [savedIcon drawInRect:CGRectMake(storyTitleX, storyTitleY - 1, 16, 16) blendMode:nil alpha:1];
        storyTitleX += 20;
    }
    if (cell.isShared) {
        UIImage *savedIcon = [UIImage imageNamed:@"menu_icn_share"];
        [savedIcon drawInRect:CGRectMake(storyTitleX, storyTitleY - 1, 16, 16) blendMode:nil alpha:1];
        storyTitleX += 20;
    }
    [cell.storyTitle drawInRect:CGRectMake(storyTitleX, storyTitleY, rect.size.width - storyTitleX + leftMargin, theSize.height)
                 withAttributes:@{NSFontAttributeName: font,
                                  NSForegroundColorAttributeName: textColor,
                                  NSParagraphStyleAttributeName: paragraphStyle}];
    
    int storyAuthorDateY = 41 + adjustForSocial;
    if (cell.isShort) {
        storyAuthorDateY -= 13;
    }
    
    // story author style
    if (cell.isRead) {
        textColor = UIColorFromRGB(0x959595);
        font = [UIFont fontWithName:@"Helvetica" size:10];
    } else {
        textColor = UIColorFromRGB(0xA6A8A2);
        font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    }
    if (cell.highlighted || cell.selected) {
        textColor = UIColorFromRGB(0x686868);
    }
    
    [cell.storyAuthor
     drawInRect:CGRectMake(leftMargin, storyAuthorDateY, (rect.size.width) / 2 - 10, 15.0)
     withAttributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}];
    // story date
    if (cell.isRead) {
        textColor = UIColorFromRGB(0xbabdd1);
        font = [UIFont fontWithName:@"Helvetica" size:10];
    } else {
        textColor = UIColorFromRGB(0x262c6c);
        font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    }
    
    if (cell.highlighted || cell.selected) {
        textColor = UIColorFromRGB(0x686868);
    }
    
    paragraphStyle.alignment = NSTextAlignmentRight;
    [cell.storyDate
     drawInRect:CGRectMake(leftMargin + (rect.size.width) / 2 - 10, storyAuthorDateY, (rect.size.width) / 2 + 10, 15.0)
     withAttributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}];
    // feed bar
    
    CGContextSetStrokeColor(context, CGColorGetComponents([cell.feedColorBarTopBorder CGColor]));
    if (cell.isRead) {
        CGContextSetAlpha(context, 0.15);
    }
    CGContextSetLineWidth(context, 4.0f);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 2.0f, 1.0f);
    CGContextAddLineToPoint(context, 2.0f, cell.frame.size.height - 1);
    CGContextStrokePath(context);
    
    CGContextSetStrokeColor(context, CGColorGetComponents([cell.feedColorBar CGColor]));
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 6.0f, 1.0f);
    CGContextAddLineToPoint(context, 6.0, cell.frame.size.height - 1);
    CGContextStrokePath(context);
    
    // reset for borders
    
    CGContextSetAlpha(context, 1.0);
    CGContextSetLineWidth(context, 1.0f);
    if (cell.highlighted || cell.selected) {
        // top border
        UIColor *blue = UIColorFromRGB(0xF9F8F4);
        
        CGContextSetStrokeColor(context, CGColorGetComponents([blue CGColor]));
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, 0.5f);
        CGContextAddLineToPoint(context, cell.bounds.size.width, 0.5f);
        CGContextStrokePath(context);
        
        // bottom border
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, cell.bounds.size.height - .5f);
        CGContextAddLineToPoint(context, cell.bounds.size.width, cell.bounds.size.height - .5f);
        CGContextStrokePath(context);
    } else {
        // top border
        UIColor *white = UIColorFromRGB(0xffffff);
        
        CGContextSetStrokeColor(context, CGColorGetComponents([white CGColor]));
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0.0f, 0.5f);
        CGContextAddLineToPoint(context, cell.bounds.size.width, 0.5f);
        CGContextStrokePath(context);
    }
    
    // site favicon
    if (cell.isRead && !cell.hasAlpha) {
        if (cell.isRiverOrSocial) {
            cell.siteFavicon = [cell imageByApplyingAlpha:cell.siteFavicon withAlpha:0.25];
        }
        cell.hasAlpha = YES;
    }
    
    if (cell.isRiverOrSocial) {
        [cell.siteFavicon drawInRect:CGRectMake(leftMargin, 6.0, 16.0, 16.0)];
    }
    
    // story indicator
    int storyIndicatorY = 4 + adjustForSocial;
    if (cell.isShort){
        storyIndicatorY = 4 + adjustForSocial - 5 ;
    }
    
    UIImage *unreadIcon;
    if (cell.storyScore == -1) {
        unreadIcon = [UIImage imageNamed:@"g_icn_hidden"];
    } else if (cell.storyScore == 1) {
        unreadIcon = [UIImage imageNamed:@"g_icn_focus"];
    } else {
        unreadIcon = [UIImage imageNamed:@"g_icn_unread"];
    }
    
    [unreadIcon drawInRect:CGRectMake(15, storyIndicatorY + 14, 8, 8) blendMode:nil alpha:(cell.isRead ? .15 : 1)];
}

@end