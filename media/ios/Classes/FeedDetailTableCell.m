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
@synthesize storyScore;
@synthesize siteTitle;
@synthesize siteFavicon;
@synthesize isRead;
@synthesize isShort;
@synthesize isRiverOrSocial;
@synthesize feedColorBar;
@synthesize feedColorBarTopBorder;
@synthesize hasAlpha;


#define leftMargin 26
#define rightMargin 18


+ (void) initialize {
    if (self == [FeedDetailTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
        indicatorFont = [UIFont boldSystemFontOfSize:12];
    }
}

- (void)drawContentView:(CGRect)r highlighted:(BOOL)highlighted {

    
    int adjustForSocial = 3;
    if (self.isRiverOrSocial) {
        adjustForSocial = 20; 
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding

    // set the background color
    UIColor *backgroundColor;
    if (highlighted) {
        backgroundColor = UIColorFromRGB(NEWSBLUR_HIGHLIGHT_COLOR);
    } else {
        backgroundColor = UIColorFromRGB(0xf4f4f4);
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
    if (highlighted) {
        textColor = UIColorFromRGB(0x686868); //0x686868 
    }
    [textColor set];
    
    if (self.isRiverOrSocial) {
        [self.siteTitle 
         drawInRect:CGRectMake(leftMargin + 20, 7, rect.size.width - 20, 21) 
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
        if (highlighted) {
            textColor = UIColorFromRGB(0x686868);
        }
        [textColor set];
    }
    
    // story title 

    CGSize theSize = [self.storyTitle sizeWithFont:font constrainedToSize:CGSizeMake(rect.size.width, 30.0) lineBreakMode:UILineBreakModeTailTruncation];
    
    int storyTitleY = 7 + adjustForSocial + ((30 - theSize.height)/2);
    if (self.isShort){
        storyTitleY = 7 + adjustForSocial + 2;
    }
    
    [self.storyTitle
     drawInRect:CGRectMake(leftMargin, storyTitleY, rect.size.width, theSize.height) 
     withFont:font
     lineBreakMode:UILineBreakModeTailTruncation 
     alignment:UITextAlignmentLeft];

    int storyAuthorDateY = 41 + adjustForSocial;
    if (self.isShort){
        storyAuthorDateY -= 13;
    }

    // story author style

    if (self.isRead) {
        textColor = UIColorFromRGB(0xc0c0c0);
        font = [UIFont fontWithName:@"Helvetica" size:10];
    } else {
        textColor = UIColorFromRGB(0x959595);
        font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    }
    if (highlighted) {
        textColor = UIColorFromRGB(0x686868);
    }
    [textColor set];
        
    [self.storyAuthor
     drawInRect:CGRectMake(leftMargin, storyAuthorDateY, (rect.size.width) / 2 - 10, 15.0)
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
    
    if (highlighted) {
        textColor = UIColorFromRGB(0x686868);
    }
    [textColor set];
    
    [self.storyDate 
         drawInRect:CGRectMake(leftMargin + (rect.size.width) / 2 - 10, storyAuthorDateY, (rect.size.width) / 2 + 10, 15.0) 
         withFont:font
         lineBreakMode:UILineBreakModeTailTruncation 
         alignment:UITextAlignmentRight];
    
    // feed bar
    
    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBarTopBorder CGColor])); //feedColorBarTopBorder
    if (self.isRead) {
        CGContextSetAlpha(context, 0.25);
    }
    CGContextSetLineWidth(context, 6.0f);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 3.0f, 1.0f);
    CGContextAddLineToPoint(context, 3.0f, self.frame.size.height - 1);
    CGContextStrokePath(context);

    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBar CGColor]));
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 9.0f, 1.0f);
    CGContextAddLineToPoint(context, 9.0, self.frame.size.height - 1);
    CGContextStrokePath(context);
    
    // reset for borders
    
    CGContextSetAlpha(context, 1.0);
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
        CGContextMoveToPoint(context, 0, self.bounds.size.height - 1.5f);
        CGContextAddLineToPoint(context, self.bounds.size.width, self.bounds.size.height - 1.5f);
        CGContextStrokePath(context);
    } else {
        // top border
        UIColor *white = UIColorFromRGB(0xffffff);
        
        CGContextSetStrokeColor(context, CGColorGetComponents([white CGColor]));
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0.0f, 0.5f);
        CGContextAddLineToPoint(context, self.bounds.size.width, 0.5f);
        CGContextStrokePath(context);
    }
    
    // site favicon
    if (self.isRead && !self.hasAlpha) {
        if (self.isRiverOrSocial) {
            self.siteFavicon = [self imageByApplyingAlpha:self.siteFavicon withAlpha:0.25];
        }
        self.hasAlpha = YES;
    }
    
    if (self.isRiverOrSocial) {
        [self.siteFavicon drawInRect:CGRectMake(leftMargin, 6.0, 16.0, 16.0)];
    }

    // story indicator 
    int storyIndicatorY = 4 + adjustForSocial;
    if (self.isShort){
        storyIndicatorY = 4 + adjustForSocial - 5 ;
    }

    UIColor *scoreColor;
    if (storyScore == -1) {
        scoreColor = UIColorFromRGB(0xCC2A2E);
    } else if (storyScore == 0) {
        scoreColor = UIColorFromRGB(0xF9C72A);
    } else {
        scoreColor = UIColorFromRGB(0x3B7613);
    }
    CGContextSetFillColorWithColor(context, UIColorFromRGB(0xf4f4f4).CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(7, storyIndicatorY + 12, 12, 12));

    if (self.isRead) {
        CGContextSetAlpha(context, 0.25);
    }
    
    CGContextSetFillColorWithColor(context, scoreColor.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(9, storyIndicatorY + 14, 8, 8));
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
