//
//  EmptyExplainer.m
//  NewsBlur
//
//  Created by Samuel Clay on 3/28/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "EmptyExplainer.h"

@implementation EmptyExplainer

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.opaque = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(24, 100, rect.size.width-48, 100)];
    label.text = @"Nope";
    [label drawRect:rect];
}

@end
