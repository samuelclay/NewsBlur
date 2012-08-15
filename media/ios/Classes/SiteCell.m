//
//  SiteCell.m
//  NewsBlur
//
//  Created by Roy Yang on 8/14/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "SiteCell.h"
#import "ABTableViewCell.h"
#import "UIView+TKCategory.h"
#import "Utilities.h"

static UIFont *textFont = nil;
static UIFont *indicatorFont = nil;


@implementation SiteCell

@synthesize siteTitle;
@synthesize siteFavicon;
@synthesize feedColorBar;
@synthesize feedColorBarTopBorder;

#define leftMargin 18
#define rightMargin 18

+ (void) initialize {
    if (self == [SiteCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
        indicatorFont = [UIFont boldSystemFontOfSize:12];
    }
}

- (void)drawContentView:(CGRect)r highlighted:(BOOL)highlighted {    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding
    
    // set the background color
    UIColor *backgroundColor = UIColorFromRGB(0xf4f4f4);
    [backgroundColor set];
    
    CGContextFillRect(context, r);
    
//    if (self.selected) {
//        CGContextSetAlpha(context, 1);
//    } else {
//        CGContextSetAlpha(context, 0.5);
//    }
    // set site title
    UIColor *textColor;
    UIFont *font;
    
    font = [UIFont fontWithName:@"Helvetica-Bold" size:11];
    textColor = UIColorFromRGB(0x606060);
    [textColor set];
    
    [self.siteTitle 
     drawInRect:CGRectMake(leftMargin + 20, 6, rect.size.width - 20, 21) 
     withFont:font
     lineBreakMode:UILineBreakModeTailTruncation 
     alignment:UITextAlignmentLeft];
    
    // feed bar
    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBar CGColor])); //feedColorBarTopBorder
    CGContextSetLineWidth(context, 6.0f);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 3.0f, 1.0f);
    CGContextAddLineToPoint(context, 3.0f, self.frame.size.height);
    CGContextStrokePath(context);
    
    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBar CGColor])); //feedColorBarTopBorder
    CGContextSetLineWidth(context, 6.0f);
    CGContextBeginPath(context);
    float width = self.bounds.size.width - 23.0f;
    CGContextMoveToPoint(context, width, 1.0f);
    CGContextAddLineToPoint(context, width, self.frame.size.height);
    CGContextStrokePath(context);

    // site favicon
    [self.siteFavicon drawInRect:CGRectMake(leftMargin, 5.0, 16.0, 16.0)];
}

@end
