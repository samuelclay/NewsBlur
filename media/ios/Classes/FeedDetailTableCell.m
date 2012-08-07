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
@synthesize hasAlpha;

#define leftMargin 39
#define rightMargin 18


+ (void) initialize {
    if (self == [FeedDetailTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
        indicatorFont = [UIFont boldSystemFontOfSize:12];
    }
}

- (void) drawContentView:(CGRect)r highlighted:(BOOL)highlighted {
    int adjustForSocial = 3;
    if (self.isRiverOrSocial) {
        adjustForSocial = 20; 
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding

    // set the background color
    UIColor *backgroundColor;
    if (self.selected || self.highlighted) {
        backgroundColor = UIColorFromRGB(0xd2e6fd);
        
        // gradient start
//        CGRect fullRect = self.bounds;
//        CGColorRef top = [UIColorFromRGB(0xd2e6fd) CGColor];
//        CGColorRef bottom = [UIColorFromRGB(0xb0d1f9) CGColor];
//        drawLinearGradient(context, fullRect, top, bottom);
//        backgroundColor = [UIColor clearColor];
        // gradient end
        
    } else {
        backgroundColor = [UIColor whiteColor];
    }
    [backgroundColor set];
    
    CGContextFillRect(context, r);

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
        textColor = UIColorFromRGB(0x686868); //0x686868 
    }
    [textColor set];
    
    if (self.isRiverOrSocial) {
        [self.siteTitle 
         drawInRect:CGRectMake(leftMargin, 6, rect.size.width - rightMargin, 21) 
         withFont:font
         lineBreakMode:UILineBreakModeTailTruncation 
         alignment:UITextAlignmentLeft];
        
        if (self.isRead) {
            font = [UIFont fontWithName:@"Helvetica" size:12];
            textColor = UIColorFromRGB(0xc0c0c0);
            
        } else {
            textColor = UIColorFromRGB(0x333333);
            font = [UIFont fontWithName:@"Helvetica-Bold" size:12];
        }
        if (self.selected || self.highlighted) {
            textColor = UIColorFromRGB(0x686868);
        }
        [textColor set];
    }
    

    CGSize theSize = [self.storyTitle sizeWithFont:font constrainedToSize:CGSizeMake(rect.size.width - rightMargin, 30.0) lineBreakMode:UILineBreakModeTailTruncation];
    
    [self.storyTitle 
     drawInRect:CGRectMake(leftMargin, 6 + adjustForSocial + ((30 - theSize.height)/2), rect.size.width - rightMargin, theSize.height) 
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
        textColor = UIColorFromRGB(0x686868);
    }
    [textColor set];
    

    [self.storyAuthor 
     drawInRect:CGRectMake(leftMargin, 42 + adjustForSocial, (rect.size.width - rightMargin) / 2 - 10, 15.0) 
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
        textColor = UIColorFromRGB(0x686868);
    }
    [textColor set];
    
    [self.storyDate 
         drawInRect:CGRectMake(leftMargin + (rect.size.width - rightMargin) / 2 - 10, 42 + adjustForSocial, (rect.size.width - rightMargin) / 2 + 10, 15.0) 
         withFont:font
         lineBreakMode:UILineBreakModeTailTruncation 
         alignment:UITextAlignmentRight];
    
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
    
    CGContextSetLineWidth(context, 1.0f);
    if (self.highlighted || self.selected) {
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
        if (self.isRead) {
            CGContextSetAlpha(context, 0.5);
        }
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0.0f, 0.5f);
        CGContextAddLineToPoint(context, 10.0, 0.5f);
        CGContextStrokePath(context);
    }
    
    // site favicon
    if (self.isRead && !self.hasAlpha) {
        if (self.isRiverOrSocial) {
            self.siteFavicon = [self imageByApplyingAlpha:self.siteFavicon withAlpha:0.25];
        }
        self.storyUnreadIndicator = [self imageByApplyingAlpha:self.storyUnreadIndicator withAlpha:0.15];
        self.hasAlpha = YES;
    }
    
    if (self.isRiverOrSocial) {
        [self.siteFavicon drawInRect:CGRectMake(18.0, 6.0, 16.0, 16.0)];
        [self.storyUnreadIndicator drawInRect:CGRectMake(18, 34, 16, 16)];
    } else {
        [self.storyUnreadIndicator drawInRect:CGRectMake(18, 24, 16, 16)];
    }

}

- (UIImage *)imageByApplyingAlpha:(UIImage *)image withAlpha:(CGFloat) alpha {
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0f);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect area = CGRectMake(0, 0, image.size.width, image.size.height);
    
    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -area.size.height);
    
    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);

    CGContextSetAlpha(ctx, alpha);
    
    CGContextDrawImage(ctx, area, image.CGImage);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}


@end
