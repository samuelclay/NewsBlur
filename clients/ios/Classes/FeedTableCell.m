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
    }
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        cellContent = [[FeedTableCellView alloc] initWithFrame:self.frame];
        cellContent.opaque = YES;
        [self.contentView addSubview:cellContent];
        [self setupGestures];
    }

    return self;
}

- (void)drawRect:(CGRect)rect {
    ((FeedTableCellView *)cellContent).cell = self;
    cellContent.frame = rect;
    [cellContent setNeedsDisplay];
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
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    [self setDelegate:(NewsBlurViewController <MCSwipeTableViewCellDelegate> *)appDelegate.feedsViewController];
    [self setFirstStateIconName:@"train.png"
                     firstColor:UIColorFromRGB(0xA4D97B)
            secondStateIconName:nil
                    secondColor:nil
                  thirdIconName:@"g_icn_unread.png"
                     thirdColor:UIColorFromRGB(0xFFFFD2)
                 fourthIconName:nil
                    fourthColor:nil];
    
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
        CGFloat lineWidth = 0.5f;
        CGContextSetStrokeColor(context, CGColorGetComponents([highlightBorderColor CGColor]));
        CGContextSetLineWidth(context, lineWidth);
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, lineWidth*0.5f);
        CGContextAddLineToPoint(context, r.size.width, 0.5f);
        CGContextStrokePath(context);
        
        // bottom border    
        CGContextBeginPath(context);
        CGContextSetLineWidth(context, lineWidth);
        CGContextMoveToPoint(context, 0, r.size.height - .5f*lineWidth);
        CGContextAddLineToPoint(context, r.size.width, r.size.height - .5f*lineWidth);
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