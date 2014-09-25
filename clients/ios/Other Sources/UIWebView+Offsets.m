//
//  UIWebView+Offsets.m
//  NewsBlur
//
//  Created by Samuel Clay on 9/17/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "UIWebView+Offsets.h"

@implementation UIWebView (Offsets)

- (CGSize)windowSize
{
    CGSize size;
    size.width = [[self stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] integerValue];
    size.height = [[self stringByEvaluatingJavaScriptFromString:@"window.innerHeight"] integerValue];
    return size;
}

- (CGPoint)scrollOffset
{
    CGPoint pt;
    pt.x = [[self stringByEvaluatingJavaScriptFromString:@"window.pageXOffset"] integerValue];
    pt.y = [[self stringByEvaluatingJavaScriptFromString:@"window.pageYOffset"] integerValue];
    return pt;
}

@end
