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
    button.bounds = CGRectMake(0, 0, image.size.width, image.size.height);
    [button setImage:image forState:UIControlStateNormal];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem* item = [[self alloc] initWithCustomView:button];
    return item;
}

@end