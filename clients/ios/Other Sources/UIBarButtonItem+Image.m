//
//  UIBarButtonItem+Image.m
//  NewsBlur
//
//  Created by Samuel Clay on 2/27/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import "UIBarButtonItem+Image.h"

@implementation UIBarButtonItem (Image)

+(UIBarButtonItem *)barItemWithImage:(UIImage *)image target:(id)target action:(SEL)action
{
    UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
// iOS 13 crash with sizeToFit.
//    [button sizeToFit];
//    button.imageView.contentMode = UIViewContentModeCenter;
    UIBarButtonItem* item = [[self alloc] initWithCustomView:button];
//    button.layer.borderColor = [[UIColor redColor] CGColor];
//    button.layer.borderWidth = 0.5f;
    return item;
}

@end
