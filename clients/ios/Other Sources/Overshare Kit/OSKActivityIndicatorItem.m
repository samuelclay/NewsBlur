//
//  OSKActivityIndicatorItem.m
//  Overshare
//
//  Created by Jared Sinclair on 10/19/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKActivityIndicatorItem.h"

#import "OSKPresentationManager.h"

// ================================================

@interface OSKActivityIndicatorView : UIActivityIndicatorView
@property (assign, nonatomic) OSKActivityIndicatorItemPosition position;
@end
@implementation OSKActivityIndicatorView
- (UIEdgeInsets)alignmentRectInsets {
    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (self.position == OSKActivityIndicatorItemPosition_Left) {
        insets = UIEdgeInsetsMake(0, 6.0f, 0, 0); // usually it should be 9.0, but this looks better with the spinner
    }
    else if (self.position == OSKActivityIndicatorItemPosition_Right) {
        insets = UIEdgeInsetsMake(0, 0, 0, 6.0f); // usually it should be 9.0, but this looks better with the spinner
    }
    return insets;
}
@end

// ================================================

@interface OSKActivityIndicatorItem ()

@property (strong, nonatomic) OSKActivityIndicatorView *spinner;

@end

@implementation OSKActivityIndicatorItem

+ (instancetype)item:(UIActivityIndicatorViewStyle)style {
    OSKActivityIndicatorView *spinner = [[OSKActivityIndicatorView alloc] initWithActivityIndicatorStyle:style];
    spinner.hidesWhenStopped = YES;
    OSKActivityIndicatorItem *item = [[OSKActivityIndicatorItem alloc] initWithCustomView:spinner];
    [item setSpinner:spinner];
    return item;
}

- (void)setPosition:(OSKActivityIndicatorItemPosition)position {
    [self.spinner setPosition:position];
}

- (void)startSpinning {
    [self.spinner startAnimating];
}

- (void)stopSpinning {
    [self.spinner stopAnimating];
}

@end
