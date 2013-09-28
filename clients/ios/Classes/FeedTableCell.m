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

+ (void) initialize{
    if (self == [FeedTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
//        UIColor *psGrad = UIColorFromRGB(0x559F4D);
//        UIColor *ntGrad = UIColorFromRGB(0xE4AB00);
//        UIColor *ngGrad = UIColorFromRGB(0x9B181B);
//        const CGFloat* psTop = CGColorGetComponents(ps.CGColor);
//        const CGFloat* psBot = CGColorGetComponents(psGrad.CGColor);
//        CGFloat psGradient[] = {
//            psTop[0], psTop[1], psTop[2], psTop[3],
//            psBot[0], psBot[1], psBot[2], psBot[3]
//        };
//        psColors = psGradient;
    }
}


- (void) setPositiveCount:(int)ps {
    if (ps == _positiveCount) return;
    
    _positiveCount = ps;
    [self setNeedsDisplay];
}

- (void) setNeutralCount:(int)nt {
    if (nt == _neutralCount) return;
    
    _neutralCount = nt;
    [self setNeedsDisplay];
}

- (void) setNegativeCount:(int)ng {
    if (ng == _negativeCount) return;
    
    _negativeCount = ng;
    _negativeCountStr = [NSString stringWithFormat:@"%d", ng];
    [self setNeedsDisplay];
}

- (void)setupGestures {
    [self setDelegate:appDelegate.feedsViewController];
    [self setFirstStateIconName:@"clock.png"
                     firstColor:[UIColor colorWithRed:85.0 / 255.0 green:213.0 / 255.0 blue:80.0 / 255.0 alpha:1.0]
            secondStateIconName:nil
                    secondColor:nil
                  thirdIconName:@"clock.png"
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

@implementation FeedTableCellView

@synthesize cell;

- (void)drawRect:(CGRect)r {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIColor *backgroundColor;
    
    backgroundColor = cell.highlighted || cell.selected ?
                      UIColorFromRGB(0xFFFFD2) :
                      cell.isSocial ? UIColorFromRGB(0xE6ECE8) :
                      UIColorFromRGB(0xF7F8F5);

    [backgroundColor set];
    CGContextFillRect(context, r);
    
    if (cell.highlighted || cell.selected) {
//        [NewsBlurAppDelegate fillGradient:CGRectMake(r.origin.x, r.origin.y + 1, r.size.width, r.size.height - 1) startColor:UIColorFromRGB(0xFFFFD2) endColor:UIColorFromRGB(0xFDED8D)];
        
        // top border
        UIColor *highlightBorderColor = UIColorFromRGB(0xE3D0AE);
        CGContextSetStrokeColor(context, CGColorGetComponents([highlightBorderColor CGColor]));
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, 0.5f);
        CGContextAddLineToPoint(context, r.size.width, 0.5f);
        CGContextStrokePath(context);
        
        // bottom border    
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, r.size.height - .5f);
        CGContextAddLineToPoint(context, r.size.width, r.size.height - .5f);
        CGContextStrokePath(context);
    }
    
    UnreadCountView *unreadCount = [UnreadCountView alloc];
    unreadCount.appDelegate = cell.appDelegate;
    [unreadCount drawInRect:r ps:cell.positiveCount nt:cell.neutralCount
                   listType:(cell.isSocial ? NBFeedListSocial : NBFeedListFeed)];
    
    UIColor *textColor = cell.highlighted || cell.selected ?
                         [UIColor blackColor]:
                         UIColorFromRGB(0x3a3a3a);
    UIFont *font;
    if (cell.negativeCount || cell.neutralCount || cell.positiveCount) {
        font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:13.0];
    } else {
        font = [UIFont fontWithName:@"Helvetica" size:12.6];
    }
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    
    if (cell.isSocial) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [cell.feedFavicon drawInRect:CGRectMake(9.0, 2.0, 28.0, 28.0)];
            [cell.feedTitle drawInRect:CGRectMake(46, 7, r.size.width - ([unreadCount offsetWidth] + 36) - 10 - 16, 20.0)
                   withAttributes:@{NSFontAttributeName: font,
                                    NSForegroundColorAttributeName: textColor,
                                    NSParagraphStyleAttributeName: paragraphStyle}];
        } else {
            [cell.feedFavicon drawInRect:CGRectMake(9.0, 3.0, 26.0, 26.0)];
            [cell.feedTitle drawInRect:CGRectMake(42, 7, r.size.width - ([unreadCount offsetWidth] + 36) - 10 - 12, 20.0)
                   withAttributes:@{NSFontAttributeName: font,
                                    NSForegroundColorAttributeName: textColor,
                                    NSParagraphStyleAttributeName: paragraphStyle}];
        }

    } else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [cell.feedFavicon drawInRect:CGRectMake(12.0, 7.0, 16.0, 16.0)];
            [cell.feedTitle drawInRect:CGRectMake(36.0, 7.0, r.size.width - ([unreadCount offsetWidth] + 36) - 10, 20.0)
                   withAttributes:@{NSFontAttributeName: font,
                                    NSForegroundColorAttributeName: textColor,
                                    NSParagraphStyleAttributeName: paragraphStyle}];
        } else {
            [cell.feedFavicon drawInRect:CGRectMake(9.0, 7.0, 16.0, 16.0)];
            [cell.feedTitle drawInRect:CGRectMake(34.0, 7.0, r.size.width - ([unreadCount offsetWidth] + 36) - 10, 20.0)
                   withAttributes:@{NSFontAttributeName: font,
                                    NSForegroundColorAttributeName: textColor,
                                    NSParagraphStyleAttributeName: paragraphStyle}];
        }
    }
    
}



@end