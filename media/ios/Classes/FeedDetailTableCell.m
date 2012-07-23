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

static UIFont *textFont = nil;
static UIFont *indicatorFont = nil;

@implementation FeedDetailTableCell

@synthesize storyTitle;
@synthesize storyAuthor;
@synthesize storyDate;
@synthesize storyUnreadIndicator;
@synthesize siteTitle;
@synthesize siteFavicon;
@synthesize isRead;
@synthesize isRiverOrSocial;
@synthesize feedColorBar;
@synthesize feedColorBarTopBorder;

#define leftMargin 39
#define rightMargin 18


+ (void) initialize{
    if (self == [FeedDetailTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
        indicatorFont = [UIFont boldSystemFontOfSize:12];
    }
}



- (void) drawContentView:(CGRect)r highlighted:(BOOL)highlighted {

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // set the background color
    UIColor *backgroundColor;
    if (self.selected || self.highlighted) {
        backgroundColor = [UIColor colorWithRed:0.15 green:0.55 blue:0.95 alpha:1.0];
    } else {
        backgroundColor = [UIColor whiteColor];
    }
    [backgroundColor set];
    
    CGContextFillRect(context, r);
    CGRect rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding

    // set site title
    UIColor *textColor;
    UIFont *font;
    
    if (self.isRead) {
        font = [UIFont fontWithName:@"Helvetica" size:11];
        textColor = UIColorFromRGB(0xc0c0c0);
    } else {
        font = [UIFont fontWithName:@"Helvetica-Bold" size:11];
        textColor = UIColorFromRGB(0x606060);
        
    }
    if (self.selected || self.highlighted) {
        textColor = [UIColor whiteColor];
    }
    [textColor set];
    
    
    [self.siteTitle 
     drawInRect:CGRectMake(leftMargin, 8, rect.size.width - rightMargin, 21) 
     withFont:font
     lineBreakMode:UILineBreakModeTailTruncation 
     alignment:UITextAlignmentLeft];
    
    if (self.isRead) {
        font = [UIFont fontWithName:@"Helvetica" size:14];
        textColor = UIColorFromRGB(0xc0c0c0);
    } else {
        textColor = UIColorFromRGB(0x333333);
        font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    }
    if (self.selected || self.highlighted) {
        textColor = [UIColor whiteColor];
    }
    [textColor set];

    
    [self.storyTitle 
     drawInRect:CGRectMake(leftMargin, 26, rect.size.width - rightMargin, 20.0) 
     withFont:font
     lineBreakMode:UILineBreakModeTailTruncation 
     alignment:UITextAlignmentLeft];
    
    // story author style
    if (self.isRead) {
        textColor = UIColorFromRGB(0xc0c0c0);
        font = [UIFont fontWithName:@"Helvetica" size:10];
    } else {
        textColor = UIColorFromRGB(0x959595);
        font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    }
    if (self.selected || self.highlighted) {
        textColor = [UIColor whiteColor];
    }
    [textColor set];

    [self.storyAuthor 
     drawInRect:CGRectMake(leftMargin, 62, (rect.size.width - rightMargin) / 2 - 10, 15.0) 
     withFont:font
     lineBreakMode:UILineBreakModeTailTruncation 
     alignment:UITextAlignmentLeft];
    
    // story date
    
    if (self.isRead) {
        textColor = UIColorFromRGB(0xbabdd1);
        font = [UIFont fontWithName:@"Helvetica" size:10];
    } else {
        textColor = UIColorFromRGB(0x262c6c);
        font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    }
    
    if (self.selected || self.highlighted) {
        textColor = [UIColor whiteColor];
    }
    [textColor set];
    
    [self.storyDate 
         drawInRect:CGRectMake(leftMargin + (rect.size.width - rightMargin) / 2 - 10, 62, (rect.size.width - rightMargin) / 2 + 10, 15.0) 
         withFont:font
         lineBreakMode:UILineBreakModeTailTruncation 
         alignment:UITextAlignmentRight];
    
    // top border
    UIColor *gray = UIColorFromRGB(0xcccccc);
    
    CGContextSetStrokeColor(context, CGColorGetComponents([gray CGColor]));

    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 10.0f, 0.0f);
    CGContextAddLineToPoint(context, 400, 0.0f);
    CGContextStrokePath(context);
    
    // top border    
    CGContextSetStrokeColor(context, CGColorGetComponents([feedColorBarTopBorder CGColor]));
    if (self.isRead) {
        CGContextSetAlpha(context, 0.25);
    }
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 0.0f, 0.0f);
    CGContextAddLineToPoint(context, 10.0, 0.0f);
    CGContextStrokePath(context);

    // feed bar
    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBar CGColor]));
    if (self.isRead) {
        CGContextSetAlpha(context, 0.25);
    }
    CGContextSetLineWidth(context, 10.0f);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 5.0f, 1.0f);
    CGContextAddLineToPoint(context, 5.0f, 81.0f);
    CGContextStrokePath(context);
    
    // site favicon
    
    [self.siteFavicon drawInRect:CGRectMake(18.0, 6.0, 16.0, 16.0)];
    [self.storyUnreadIndicator drawInRect:CGRectMake(18, 34, 16, 16)];
}


@end
