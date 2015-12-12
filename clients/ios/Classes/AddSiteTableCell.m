//
//  AddSiteTableCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "AddSiteTableCell.h"
#import "ABTableViewCell.h"
#import "UIView+TKCategory.h"
#import "Utilities.h"

static UIFont *textFont = nil;
static UIFont *indicatorFont = nil;

@implementation AddSiteTableCell

@synthesize siteTitle;
@synthesize siteUrl;
@synthesize siteFavicon;
@synthesize feedColorBar;
@synthesize feedColorBarTopBorder;
@synthesize siteSubscribers;

#define leftMargin 39
#define rightMargin 18


+ (void)initialize {
    if (self == [AddSiteTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
        indicatorFont = [UIFont boldSystemFontOfSize:12];
    }
}

- (void)drawContentView:(CGRect)r highlighted:(BOOL)highlighted {
    int adjustForSocial = 3;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding
    
    // set the background color
    UIColor *backgroundColor;
    if (highlighted) {
        backgroundColor = UIColorFromRGB(NEWSBLUR_HIGHLIGHT_COLOR);
    } else {
        backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    }
    [backgroundColor set];
    
    CGContextFillRect(context, r);
    
    // set site title
    UIColor *textColor;
    UIFont *font;
    
    font = [UIFont fontWithName:@"Helvetica-Bold" size:14];
    textColor = UIColorFromRGB(0x606060);
    
    if (highlighted) {
        textColor = UIColorFromRGB(0x686868); //0x686868 
    }

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    
    [self.siteTitle
     drawInRect:CGRectMake(leftMargin, 6, rect.size.width - rightMargin, 21) 
     withAttributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}];
    
    textColor = UIColorFromRGB(0x333333);    
    if (highlighted) {
        textColor = UIColorFromRGB(0x686868);
    }
    [textColor set];
    
    
    // url
        
    // site subscribers
    
    textColor = UIColorFromRGB(0x262c6c);
    font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    
    if (highlighted) {
        textColor = UIColorFromRGB(0x686868);
    }
    
    paragraphStyle.alignment = NSTextAlignmentRight;
    [self.siteSubscribers 
     drawInRect:CGRectMake(leftMargin + (rect.size.width - rightMargin) / 2 - 10, 42 + adjustForSocial, (rect.size.width - rightMargin) / 2 + 10, 15.0) 
     withAttributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}];
    
    // feed bar
    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBar CGColor]));

    CGContextSetLineWidth(context, 10.0f);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 5.0f, 1.0f);
    CGContextAddLineToPoint(context, 5.0f, 81.0f);
    CGContextStrokePath(context);
    
    CGContextSetLineWidth(context, 1.0f);
    if (highlighted) {
        // top border
        UIColor *blue = UIColorFromRGB(0x6eadf5);
        
        CGContextSetStrokeColor(context, CGColorGetComponents([blue CGColor]));
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, 0.5f);
        CGContextAddLineToPoint(context, self.bounds.size.width, 0.5f);
        CGContextStrokePath(context);
        
        // bottom border    
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, self.bounds.size.height - 0.5f);
        CGContextAddLineToPoint(context, self.bounds.size.width, self.bounds.size.height - 0.5f);
        CGContextStrokePath(context);
    } else {
        // top border
        UIColor *gray = UIColorFromRGB(0xcccccc);
        
        CGContextSetStrokeColor(context, CGColorGetComponents([gray CGColor]));
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 10.0f, 0.5f);
        CGContextAddLineToPoint(context, self.bounds.size.width, 0.5f);
        CGContextStrokePath(context);
        
        // feed bar border    
        CGContextSetStrokeColor(context, CGColorGetComponents([feedColorBarTopBorder CGColor]));
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0.0f, 0.5f);
        CGContextAddLineToPoint(context, 10.0, 0.5f);
        CGContextStrokePath(context);
    }
    
    // site favicon
    [self.siteFavicon drawInRect:CGRectMake(18.0, 6.0, 16.0, 16.0)];
    
}

@end
