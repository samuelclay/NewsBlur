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
	if(self == [FeedTableCell class])
	{
		textFont = [[UIFont boldSystemFontOfSize:18] retain];
		indicatorFont = [[UIFont boldSystemFontOfSize:12] retain];
		indicatorWhiteColor = [[UIColor whiteColor] retain];
		indicatorBlackColor = [[UIColor blackColor] retain];
        
        UIColor *ps = UIColorFromRGB(0x3B7613);
        UIColor *nt = UIColorFromRGB(0xF9C72A);
        UIColor *ng = UIColorFromRGB(0xCC2A2E);
		positiveBackgroundColor = [ps retain];
		neutralBackgroundColor = [nt retain];
		negativeBackgroundColor = [ng retain];
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

- (void)dealloc {
    [feedTitle release];
    [feedFavicon release];
    [super dealloc];
}

- (void) setPositiveCount:(int)ps {    
	if (ps == _positiveCount) return;
    
	_positiveCount = ps;
	_positiveCountStr = [[NSString stringWithFormat:@"%d", ps] retain];
	[self setNeedsDisplay];
}

- (void) setNeutralCount:(int)nt {    
	if (nt == _neutralCount) return;
    
	_neutralCount = nt;
	_neutralCountStr = [[NSString stringWithFormat:@"%d", nt] retain];
	[self setNeedsDisplay];
}

- (void) setNegativeCount:(int)ng {    
	if (ng == _negativeCount) return;
    
	_negativeCount = ng;
	_negativeCountStr = [[NSString stringWithFormat:@"%d", ng] retain];
	[self setNeedsDisplay];
}


- (void) drawContentView:(CGRect)r highlighted:(BOOL)highlighted {
    
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	UIColor *backgroundColor;
    
    if (self.isSocial) {
        backgroundColor = self.selected || self.highlighted ? 
                        [UIColor colorWithRed:0.15 green:0.55 blue:0.95 alpha:1.0] : 
                        UIColorFromRGB(0xe9e9ee);
    } else {
        backgroundColor = self.selected || self.highlighted ? 
        [UIColor colorWithRed:0.15 green:0.55 blue:0.95 alpha:1.0] : 
        [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];

    }
	
	[backgroundColor set];
	CGContextFillRect(context, r);
	
	
	CGRect rect = CGRectInset(r, 12, 12);
	rect.size.width -= 18; // Scrollbar padding
	
    int psWidth = _positiveCount == 0 ? 0 : _positiveCount < 10 ? 
                    14 : _positiveCount < 100 ? 20 : 26;
    int ntWidth = _neutralCount  == 0 ? 0 : _neutralCount < 10 ? 
                    14 : _neutralCount  < 100 ? 20 : 26;
    int ngWidth = _negativeCount == 0 ? 0 : _negativeCount < 10 ? 
                    14 : _negativeCount < 100 ? 20 : 26;
    
    int psOffset = _positiveCount == 0 ? 0 : psWidth - 20;
    int ntOffset = _neutralCount  == 0 ? 0 : ntWidth - 20;
    int ngOffset = _negativeCount == 0 ? 0 : ngWidth - 20;
    
    int psPadding = _positiveCount == 0 ? 0 : 2;
    int ntPadding = _neutralCount  == 0 ? 0 : 2;
    
	if(_positiveCount > 0){		
		[positiveBackgroundColor set];
		CGRect rr = CGRectMake(rect.size.width + rect.origin.x - psOffset, 10, psWidth, 18);
        [UIView drawLinearGradientInRect:rr colors:psColors];
		[UIView drawRoundRectangleInRect:rr withRadius:5];
		
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
		CGRect rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntOffset, 10, ntWidth, 18);
		[UIView drawRoundRectangleInRect:rr withRadius:5];
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
		CGRect rr = CGRectMake(rect.size.width + rect.origin.x - psWidth - psPadding - ntWidth - ntPadding - ngOffset, 10, ngWidth, 18);
		[UIView drawRoundRectangleInRect:rr withRadius:5];
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
                         [UIColor whiteColor] : 
                         [UIColor blackColor];
    [textColor set];
    UIFont *font;
    if (self.negativeCount || self.neutralCount || self.positiveCount) {
        font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:13.0];
    } else {
        font = [UIFont fontWithName:@"Helvetica" size:12.6];
    }

    if (isSocial) {
        self.feedFavicon = [self roundCorneredImage:self.feedFavicon radius:6];
        [self.feedFavicon drawInRect:CGRectMake(4.0, 4.0, 32.0, 32.0)];
        [feedTitle 
         drawInRect:CGRectMake(36 + 6.0, 11.0, rect.size.width - psWidth - psPadding - ntWidth - ntPadding - ngWidth - 10 - 6, 20.0) 
         withFont:font
         lineBreakMode:UILineBreakModeTailTruncation 
         alignment:UITextAlignmentLeft];
    } else {
        [self.feedFavicon drawInRect:CGRectMake(14.0, 11.0, 16.0, 16.0)];
        [feedTitle 
         drawInRect:CGRectMake(36.0, 11.0, rect.size.width - psWidth - psPadding - ntWidth - ntPadding - ngWidth - 10, 20.0) 
         withFont:font
         lineBreakMode:UILineBreakModeTailTruncation 
         alignment:UITextAlignmentLeft];
    }
}

#pragma mark
#pragma Adding rounded corners to UIImage

- (UIImage *)roundCorneredImage: (UIImage*) orig radius:(CGFloat) r {
    UIGraphicsBeginImageContextWithOptions(orig.size, NO, 0);
    [[UIBezierPath bezierPathWithRoundedRect:(CGRect){CGPointZero, orig.size} 
                                cornerRadius:r] addClip];
    [orig drawInRect:(CGRect){CGPointZero, orig.size}];
    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

@end
