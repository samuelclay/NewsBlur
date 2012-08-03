//
//  FeedTableCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/18/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "FeedTableCell.h"
#import "ABTableViewCell.h"
#import "UIView+TKCategory.h"

static UIFont *textFont = nil;
static UIFont *indicatorFont = nil;
static UIColor *indicatorWhiteColor = nil;
static UIColor *indicatorBlackColor = nil;
static UIColor *positiveBackgroundColor = nil;
static UIColor *neutralBackgroundColor = nil;
static UIColor *negativeBackgroundColor = nil;
static CGFloat *psColors = nil;

@implementation FeedTableCell

@synthesize appDelegate;
@synthesize feedTitle;
@synthesize feedFavicon;
@synthesize positiveCount = _positiveCount;
@synthesize neutralCount = _neutralCount;
@synthesize negativeCount = _negativeCount;
@synthesize positiveCountStr;
@synthesize neutralCountStr;
@synthesize negativeCountStr;
@synthesize isSocial;

+ (void) initialize{
    if (self == [FeedTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
        indicatorFont = [UIFont boldSystemFontOfSize:12];
        indicatorWhiteColor = [UIColor whiteColor];
        indicatorBlackColor = [UIColor blackColor];

        UIColor *ps = UIColorFromRGB(0x3B7613);
        UIColor *nt = UIColorFromRGB(0xF9C72A);
        UIColor *ng = UIColorFromRGB(0xCC2A2E);
        positiveBackgroundColor = ps;
        neutralBackgroundColor = nt;
        negativeBackgroundColor = ng;
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
    _positiveCountStr = [NSString stringWithFormat:@"%d", ps];
    [self setNeedsDisplay];
}

- (void) setNeutralCount:(int)nt {
    if (nt == _neutralCount) return;
    
    _neutralCount = nt;
    _neutralCountStr = [NSString stringWithFormat:@"%d", nt];
    [self setNeedsDisplay];
}

- (void) setNegativeCount:(int)ng {
    if (ng == _negativeCount) return;
    
    _negativeCount = ng;
    _negativeCountStr = [NSString stringWithFormat:@"%d", ng];
    [self setNeedsDisplay];
}


- (void) drawContentView:(CGRect)r highlighted:(BOOL)highlighted {
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIColor *backgroundColor;
    
    backgroundColor = self.selected || self.highlighted ? 
                      UIColorFromRGB(0xd2e6fd) : 
                      [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];

    [backgroundColor set];
    CGContextFillRect(context, r);
    
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
        CGContextMoveToPoint(context, 0, self.bounds.size.height - 1.5f);
        CGContextAddLineToPoint(context, self.bounds.size.width, self.bounds.size.height - 1.5f);
        CGContextStrokePath(context);
    }
    
    CGRect rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding
    
    int psWidth = _positiveCount == 0 ? 0 : _positiveCount < 10 ? 
                    14 : _positiveCount < 100 ? 22 : 28;
    int ntWidth = _neutralCount  == 0 ? 0 : _neutralCount < 10 ? 
                    14 : _neutralCount  < 100 ? 22 : 28;
    int ngWidth = _negativeCount == 0 ? 0 : _negativeCount < 10 ? 
                    14 : _negativeCount < 100 ? 22 : 28;
    
    int psOffset = _positiveCount == 0 ? 0 : psWidth - 20;
    int ntOffset = _neutralCount  == 0 ? 0 : ntWidth - 20;
    int ngOffset = _negativeCount == 0 ? 0 : ngWidth - 20;
    
    int psPadding = _positiveCount == 0 ? 0 : 2;
    int ntPadding = _neutralCount  == 0 ? 0 : 2;
    
    if(_positiveCount > 0){     
        [positiveBackgroundColor set];
        CGRect rr;
        
        if (self.isSocial) {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                rr = CGRectMake(rect.size.width + rect.origin.x - psOffset, 14, psWidth, 17);
            } else {
                rr = CGRectMake(rect.size.width + rect.origin.x - psOffset, 10, psWidth, 17);
            }
        } else {
            rr = CGRectMake(rect.size.width + rect.origin.x - psOffset, 9, psWidth, 17);
        }
        
        ;
        [UIView drawLinearGradientInRect:rr colors:psColors];
        [UIView drawRoundRectangleInRect:rr withRadius:4];
        
        [indicatorWhiteColor set];
        
        CGSize size = [_positiveCountStr sizeWithFont:indicatorFont];   
        float x_pos = (rr.size.width - size.width) / 2; 
        float y_pos = (rr.size.height - size.height) / 2; 
        [_positiveCountStr 
         drawAtPoint:CGPointMake(rr.origin.x + x_pos, rr.origin.y + y_pos) 
         withFont:indicatorFont];
    }
    if(_neutralCount > 0 && appDelegate.selectedIntelligence <= 0){     
        [neutralBackgroundColor set];
        
        CGRect rr;
        if (self.isSocial) {
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntOffset, 14, ntWidth, 17);
            } else {
                rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntOffset, 10, ntWidth, 17);
            }
        } else {
            rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntOffset, 9, ntWidth, 17);
        }

        [UIView drawRoundRectangleInRect:rr withRadius:4];
//        [UIView drawLinearGradientInRect:rr colors:ntColors];
        
        [indicatorBlackColor set];
        CGSize size = [_neutralCountStr sizeWithFont:indicatorFont];   
        float x_pos = (rr.size.width - size.width) / 2; 
        float y_pos = (rr.size.height - size.height) / 2; 
        [_neutralCountStr 
         drawAtPoint:CGPointMake(rr.origin.x + x_pos, rr.origin.y + y_pos) 
         withFont:indicatorFont];     
    }
    if(_negativeCount > 0 && appDelegate.selectedIntelligence <= -1){       
        [negativeBackgroundColor set];
        CGRect rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntWidth - ntPadding - ngOffset, self.isSocial ? 14: 9, ngWidth, 17);
        [UIView drawRoundRectangleInRect:rr withRadius:4];
//        [UIView drawLinearGradientInRect:rr colors:ngColors];
        
        [indicatorWhiteColor set];
        CGSize size = [_negativeCountStr sizeWithFont:indicatorFont];   
        float x_pos = (rr.size.width - size.width) / 2; 
        float y_pos = (rr.size.height - size.height) / 2; 
        [_negativeCountStr 
         drawAtPoint:CGPointMake(rr.origin.x + x_pos, rr.origin.y + y_pos) 
         withFont:indicatorFont];    
    }
    
    UIColor *textColor = self.selected || self.highlighted ? 
                         [UIColor blackColor]:
                         [UIColor blackColor];

    [textColor set];
    UIFont *font;
    if (self.negativeCount || self.neutralCount || self.positiveCount) {
        font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:13.0];
    } else {
        font = [UIFont fontWithName:@"Helvetica" size:12.6];
    }

    if (isSocial) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.feedFavicon drawInRect:CGRectMake(12.0, 5.0, 36.0, 36.0)];
            [feedTitle 
             drawInRect:CGRectMake(56, 13, rect.size.width - psWidth - psPadding - ntWidth - ntPadding - ngWidth - 10 - 20, 20.0) 
             withFont:font
             lineBreakMode:UILineBreakModeTailTruncation 
             alignment:UITextAlignmentLeft]; 
        } else {
            [self.feedFavicon drawInRect:CGRectMake(9.0, 3.0, 32.0, 32.0)];
            [feedTitle 
             drawInRect:CGRectMake(50, 11, rect.size.width - psWidth - psPadding - ntWidth - ntPadding - ngWidth - 10 - 20, 20.0) 
             withFont:font
             lineBreakMode:UILineBreakModeTailTruncation 
             alignment:UITextAlignmentLeft];
        }

    } else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.feedFavicon drawInRect:CGRectMake(12.0, 9.0, 16.0, 16.0)];
            [feedTitle 
             drawInRect:CGRectMake(36.0, 9.0, rect.size.width - psWidth - psPadding - ntWidth - ntPadding - ngWidth - 10, 20.0) 
             withFont:font
             lineBreakMode:UILineBreakModeTailTruncation 
             alignment:UITextAlignmentLeft];
        } else {
            [self.feedFavicon drawInRect:CGRectMake(9.0, 9.0, 16.0, 16.0)];
            [feedTitle 
             drawInRect:CGRectMake(34.0, 9.0, rect.size.width - psWidth - psPadding - ntWidth - ntPadding - ngWidth - 10, 20.0) 
             withFont:font
             lineBreakMode:UILineBreakModeTailTruncation 
             alignment:UITextAlignmentLeft];
        }
    }
    
}



@end