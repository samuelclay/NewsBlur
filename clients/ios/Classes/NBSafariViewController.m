//
//  NBSafariViewController.m
//  NewsBlur
//
//  Created by David Sinclair on 2015-10-23.
//  Copyright © 2015 NewsBlur. All rights reserved.
//
//  Based on Swift code from https://github.com/stringcode86/SCSafariViewController
//

#import "NBSafariViewController.h"

@interface NBSafariViewController ()

@property (nonatomic, strong) UIView *edgeView;

@end


@implementation NBSafariViewController

- (UIView *)edgeView {
    if (_edgeView == nil && self.isViewLoaded) {
        self.edgeView = [UIView new];
        _edgeView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:_edgeView];
        _edgeView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.005];
        
        NSDictionary *bindings = @{@"edgeView" : _edgeView};
        NSLayoutFormatOptions options = 0;
        NSArray *hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"|-0-[edgeView(20)]" options:options metrics:nil views:bindings];
        NSArray *vConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[edgeView]-0-|" options:options metrics:nil views:bindings];
        
        [NSLayoutConstraint activateConstraints:hConstraints];
        [NSLayoutConstraint activateConstraints:vConstraints];
    }
    
    return _edgeView;
}

@end

