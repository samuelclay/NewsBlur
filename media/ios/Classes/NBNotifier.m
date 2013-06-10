//
//  NBNotifier.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/6/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "NBNotifier.h"
#import "UIView+TKCategory.h"

@implementation NBNotifier

+ (void)initialize {
    if (self == [NBNotifier class]) {
        
    }
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (id)drawInView:(UIView *)view withText:(NSString *)text style:(NBNotifierStyle)style {
    self._text = text;
    self._style = style;
    self._view = view;
    return [self initWithFrame:view.frame];
}

- (void)drawRect:(CGRect)r {
    [[UIColor redColor] set];
    r.size.height = 20;
    [self setBackgroundColor:[UIColor clearColor]];
    [self setAlpha:0.4];
    
    [UIView drawLineInRect:CGRectMake(0, 0, r.size.width, 1) red:242 green:250 blue:230 alpha:1];
    [UIView drawLineInRect:CGRectMake(0, 1, r.size.width, 1) red:255 green:255 blue:255 alpha:1];
    [UIView drawLineInRect:CGRectMake(0, r.size.height-2, r.size.width, 1) red:255 green:255 blue:255 alpha:1];
    [UIView drawLineInRect:CGRectMake(0, r.size.height-1, r.size.width, 1) red:242 green:250 blue:230 alpha:1];
//    UIColor *psGrad = UIColorFromRGB(0x559F4D);
//    UIColor *ngGrad = UIColorFromRGB(0x9B181B);
    const CGFloat* psTop = CGColorGetComponents(UIColorFromRGB(0xE4AB00).CGColor);
    const CGFloat* psBot = CGColorGetComponents(UIColorFromRGB(0xD9A200).CGColor);
    CGFloat psGradient[] = {
        psTop[0], psTop[1], psTop[2], psTop[3],
        psBot[0], psBot[1], psBot[2], psBot[3]
    };
    NSLog(@"Drawing Notifier: %@", NSStringFromCGRect(r));
    [UIView drawLinearGradientInRect:r colors:psGradient];
    
    switch (self._style) {
        case NBOfflineStyle: {
            [self._text
             drawAtPoint:CGPointMake(40, 4)
             withFont:[UIFont boldSystemFontOfSize:12]];
            break;
        }
        case NBSyncingStyle: {
            [self._text
             drawAtPoint:CGPointMake(40, 4)
             withFont:[UIFont boldSystemFontOfSize:12]];
            break;
        }
        case NBLoadingStyle: {
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
                                                initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
            spinner.frame = CGRectMake(6, 6, 4, 4);
            spinner.center = CGPointMake(10, 10);
            spinner.color = UIColorFromRGB(0x5060C0);
            [self addSubview:spinner];
            [spinner startAnimating];
            [[UIColor darkGrayColor] set];
            [self._text
             drawAtPoint:CGPointMake(r.origin.x + 26, r.origin.y + 4)
             withFont:[UIFont boldSystemFontOfSize:12]];
            break;
        }
    }

    self.frame = r;
}

- (void)hideWithAnimation:(BOOL)animate {
    [UIView beginAnimations:nil context:nil];
    self.alpha = 0;
    [UIView commitAnimations];
}

@end
