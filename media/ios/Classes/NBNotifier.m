//
//  NBNotifier.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/6/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "NBNotifier.h"

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

- (id)initWithView:(UIView *)view andText:(NSString *)text withStyle:(NBNotifierStyle)style {
    self._text = text;
    self._style = style;
    self._view = view;
    return [self initWithFrame:view.frame];
}

- (void)drawRect:(CGRect)r {
    NSLog(@"drawRect: %@", NSStringFromCGRect(r));
    
    [[UIColor redColor] set];
    
    if (YES || self._style == NBOfflineStyle) {
        r.size.height = 40;
        [self._text
         drawAtPoint:CGPointMake(40, 4)
         withFont:[UIFont boldSystemFontOfSize:12]];
    } else if (self._style == NBSyncingStyle) {
        r.size.height = 40;
    } else if (self._style == NBLoadingStyle) {
        r.size.height = 40;
    }

    self.frame = r;
}


@end
