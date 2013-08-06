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

- (void)drawContentView:(CGRect)r highlighted:(BOOL)highlighted {

    
    int adjustForSocial = 3;
    if (self.isRiverOrSocial) {
        adjustForSocial = 20; 
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding
    
    if (!highlighted) {
        UIColor *backgroundColor;
        backgroundColor = UIColorFromRGB(0xf4f4f4);
        [backgroundColor set];
    }
    
    CGContextFillRect(context, r);
    
    if (highlighted) {
        [NewsBlurAppDelegate fillGradient:r startColor:UIColorFromRGB(0xFFFDEF) endColor:UIColorFromRGB(0xFFFDDF)];
    }
    
    UIColor *textColor;
    UIFont *font;

    if (self.isRead) {
        font = [UIFont fontWithName:@"Helvetica" size:11];
        textColor = UIColorFromRGB(0x808080);
    } else {
        font = [UIFont fontWithName:@"Helvetica-Bold" size:11];
        textColor = UIColorFromRGB(0x606060);
        
    }
    if (highlighted) {
        textColor = UIColorFromRGB(0x686868); 
    }
    [textColor set];
    
    if (self.isRiverOrSocial) {
        [self.siteTitle 
         drawInRect:CGRectMake(leftMargin + 20, 7, rect.size.width - 20, 21)
         withFont:font
         lineBreakMode:NSLineBreakByTruncatingTail 
         alignment:NSTextAlignmentLeft];
        
        if (self.isRead) {
            font = [UIFont fontWithName:@"Helvetica" size:12];
            textColor = UIColorFromRGB(0x606060);
            
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

    CGSize theSize = [self.storyTitle sizeWithFont:font constrainedToSize:CGSizeMake(rect.size.width, 30.0) lineBreakMode:NSLineBreakByTruncatingTail];
    
    int storyTitleY = 7 + adjustForSocial + ((30 - theSize.height)/2);
    if (self.isShort) {
        storyTitleY = 7 + adjustForSocial + 2;
    }
    int storyTitleX = leftMargin;
    if (self.isStarred) {
        UIImage *savedIcon = [UIImage imageNamed:@"clock"];
        [savedIcon drawInRect:CGRectMake(storyTitleX, storyTitleY - 1, 16, 16) blendMode:nil alpha:1];
        storyTitleX += 20;
    }
    if (self.isShared) {
        UIImage *savedIcon = [UIImage imageNamed:@"menu_icn_share"];
        [savedIcon drawInRect:CGRectMake(storyTitleX, storyTitleY - 1, 16, 16) blendMode:nil alpha:1];
        storyTitleX += 20;
    }
    [self.storyTitle
     drawInRect:CGRectMake(storyTitleX, storyTitleY, rect.size.width - storyTitleX + leftMargin, theSize.height)
     withFont:font
     lineBreakMode:NSLineBreakByTruncatingTail 
     alignment:NSTextAlignmentLeft];

    int storyAuthorDateY = 41 + adjustForSocial;
    if (self.isShort) {
        storyAuthorDateY -= 13;
    }

    // story author style
    if (self.isRead) {
        textColor = UIColorFromRGB(0x808080);
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
     lineBreakMode:NSLineBreakByTruncatingTail
     alignment:NSTextAlignmentLeft];

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
         lineBreakMode:NSLineBreakByTruncatingTail 
         alignment:NSTextAlignmentRight];
    
    // feed bar
    
    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBarTopBorder CGColor]));
    if (self.isRead) {
        CGContextSetAlpha(context, 0.15);
    }
    CGContextSetLineWidth(context, 4.0f);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 2.0f, 1.0f);
    CGContextAddLineToPoint(context, 2.0f, self.frame.size.height - 1);
    CGContextStrokePath(context);

    CGContextSetStrokeColor(context, CGColorGetComponents([self.feedColorBar CGColor]));
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 6.0f, 1.0f);
    CGContextAddLineToPoint(context, 6.0, self.frame.size.height - 1);
    CGContextStrokePath(context);
    
    // reset for borders
    
    CGContextSetAlpha(context, 1.0);
    CGContextSetLineWidth(context, 1.0f);
    if (highlighted) {
        // top border
        UIColor *blue = UIColorFromRGB(0xF9F8F4);
        
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

    UIImage *unreadIcon;
    if (storyScore == -1) {
        unreadIcon = [UIImage imageNamed:@"g_icn_hidden"];
    } else if (storyScore == 1) {
        unreadIcon = [UIImage imageNamed:@"g_icn_focus"];
    } else {
        unreadIcon = [UIImage imageNamed:@"g_icn_unread"];
    }
    
    [unreadIcon drawInRect:CGRectMake(15, storyIndicatorY + 14, 8, 8) blendMode:nil alpha:(self.isRead ? .15 : 1)];
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
