//
//  UnreadCountView.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/3/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UnreadCountView.h"
#import "UIView+TKCategory.h"

static UIFont *indicatorFont = nil;

@implementation UnreadCountView

const int COUNT_HEIGHT = 15;
@synthesize appDelegate;
@synthesize psWidth, psPadding, ntWidth, ntPadding;
@synthesize psCount, ntCount, blueCount;
@synthesize rect;

+ (void) initialize {
    if (self == [UnreadCountView class]) {
        indicatorFont = [UIFont boldSystemFontOfSize:12];
    }
}

- (void)drawRect:(CGRect)r {
    self.userInteractionEnabled = NO;
    
    return [self drawInRect:r ps:psCount nt:ntCount listType:NBFeedListFolder];
}

- (void)drawInRect:(CGRect)r ps:(int)ps nt:(int)nt listType:(NBFeedListType)listType {
    rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding
    
    if (listType == NBFeedListSaved || (listType == NBFeedListFolder && self.blueCount)) {
        blueCount = ps;
        psCount = ps;
        ntCount = 0;
    } else {
        blueCount = 0;
        psCount = ps;
        ntCount = nt;
    }
    [self calculateOffsets:ps nt:nt];
    
    int psOffset = ps == 0 ? 0 : psWidth - 20;
    int ntOffset = nt == 0 ? 0 : ntWidth - 20;
    
    if (ps > 0 || blueCount) {
        CGRect rr;
        
        if (listType == NBFeedListSocial) {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                rr = CGRectMake(rect.size.width + rect.origin.x - psOffset, 7, psWidth, COUNT_HEIGHT);
            } else {
                rr = CGRectMake(rect.size.width + rect.origin.x - psOffset, 7, psWidth, COUNT_HEIGHT);
            }
        } else if (listType == NBFeedListFolder) {
            rr = CGRectMake(rect.size.width + rect.origin.x - psOffset - 22, 8, psWidth, COUNT_HEIGHT);
        } else {
            rr = CGRectMake(rect.size.width + rect.origin.x - psOffset, 7, psWidth, COUNT_HEIGHT);
        }
        
        if (blueCount) {
            [UIColorFromFixedRGB(0x01346B) set];
        } else {
            [UIColorFromFixedRGB(0x4E872A) set];
        }
        CGRect rrShadow = CGRectMake(rr.origin.x, rr.origin.y+1, rr.size.width, rr.size.height);
        [UIView drawRoundRectangleInRect:rrShadow withRadius:4];
        
        if (blueCount) {
            [UIColorFromFixedRGB(0x11448B) set];
        } else {
            [UIColorFromFixedRGB(0x6EA74A) set];
        }
        [UIView drawRoundRectangleInRect:rr withRadius:4];
        
        
        NSString *psStr = [NSString stringWithFormat:@"%d", ps];
        CGSize size = [psStr sizeWithAttributes:@{NSFontAttributeName: indicatorFont}];
        float x_pos = (rr.size.width - size.width) / 2;
        float y_pos = (rr.size.height - size.height) / 2;
        
        UIColor *psColor;
        if (blueCount) {
            psColor = UIColorFromFixedRGB(NEWSBLUR_BLACK_COLOR);
        } else {
            psColor = UIColorFromFixedRGB(0x4E872A);
        }
        [psStr
         drawAtPoint:CGPointMake(rr.origin.x + x_pos, rr.origin.y + y_pos + 1)
         withAttributes:@{NSFontAttributeName: indicatorFont,
                          NSForegroundColorAttributeName: psColor}];
        
        [psStr
         drawAtPoint:CGPointMake(rr.origin.x + x_pos, rr.origin.y + y_pos)
         withAttributes:@{NSFontAttributeName: indicatorFont,
                          NSForegroundColorAttributeName: UIColorFromFixedRGB(NEWSBLUR_WHITE_COLOR)}];
    }
    
    if (nt > 0 && appDelegate.selectedIntelligence <= 0) {        
        CGRect rr;
        if (listType == NBFeedListSocial) {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntOffset, 7, ntWidth, COUNT_HEIGHT);
            } else {
                rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntOffset, 7, ntWidth, COUNT_HEIGHT);
            }
        } else if (listType == NBFeedListFolder) {
            rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntOffset - 22, 8, ntWidth, COUNT_HEIGHT);
        } else {
            rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntOffset, 7, ntWidth, COUNT_HEIGHT);
        }
        
        
        [UIColorFromLightDarkRGB(0x93968D, 0x53564D) set];
        CGRect rrShadow = CGRectMake(rr.origin.x, rr.origin.y+1, rr.size.width, rr.size.height);
        [UIView drawRoundRectangleInRect:rrShadow withRadius:4];
        
        [UIColorFromLightDarkRGB(0xB3B6AD, 0xA3A69D) set];
        [UIView drawRoundRectangleInRect:rr withRadius:4];        
        
        NSString *ntStr = [NSString stringWithFormat:@"%d", nt];
        CGSize size = [ntStr sizeWithAttributes:@{NSFontAttributeName: indicatorFont}];
        float x_pos = (rr.size.width - size.width) / 2;
        float y_pos = (rr.size.height - size.height) / 2;
        
        [ntStr
         drawAtPoint:CGPointMake(rr.origin.x + x_pos, rr.origin.y + y_pos + 1)
         withAttributes:@{NSFontAttributeName: indicatorFont,
                          NSForegroundColorAttributeName:UIColorFromLightSepiaMediumDarkRGB(0x93968D, 0x93968D, 0x93968D, 0x93968D)}];
        
        [ntStr
         drawAtPoint:CGPointMake(rr.origin.x + x_pos, rr.origin.y + y_pos)
         withAttributes:@{NSFontAttributeName: indicatorFont,
                          NSForegroundColorAttributeName:UIColorFromLightSepiaMediumDarkRGB(0xFFFFFF, 0xF8F8E9, 0x606060, 0x000000)}];
    }
}

- (void)calculateOffsets:(int)ps nt:(int)nt {
    psWidth = ps == 0 ? 0 : ps < 10 ? 14 : ps < 100 ? 22 : ps < 1000 ? 28 : ps < 10000 ? 34 : 40;
    ntWidth = nt == 0 ? 0 : nt < 10 ? 14 : nt < 100 ? 22 : nt < 1000 ? 28 : nt < 10000 ? 34 : 40;
    
    psPadding = ps == 0 ? 0 : 2;
    ntPadding = nt == 0 ? 0 : 2;
}

- (int)offsetWidth {
    int width = 0;
    if (self.psCount > 0) {
        width += psWidth + psPadding;
    }
    if (self.ntCount > 0 && appDelegate.selectedIntelligence <= 0) {
        width += ntWidth + ntPadding;
    }
    return width;
}

@end
