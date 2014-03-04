//
//  ADNPassportLaunchView.h
//  ADNSDK
//
//  Created by Bryan Berg on 6/14/13.
//  Copyright (c) 2013 Mixed Media Labs, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this
//  software and associated documentation files (the "Software"), to deal in the Software
//  without restriction, including without limitation the rights to use, copy, modify,
//  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <UIKit/UIKit.h>


@class ADNPassportLaunchView;


@protocol ADNPassportLaunchViewDelegate <NSObject>

- (void)adnPassportLaunchViewDidRequestInstall:(ADNPassportLaunchView *)passportLaunchView;
- (void)adnPassportLaunchViewDidRequestLogin:(ADNPassportLaunchView *)passportLaunchView;

@end


@interface ADNPassportLaunchView : UIView

@property (weak, nonatomic) NSObject<ADNPassportLaunchViewDelegate> *delegate;

@property (strong, nonatomic) UIButton *button;
@property (strong, nonatomic) UILabel *signupLabel;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;
@property (strong, nonatomic) UILabel *waitingLabel;

// Subclass and override if desired
- (CGRect)hiddenStateFrameInView:(UIView *)view;
- (CGRect)visibleStateFrameInView:(UIView *)view;
- (CGRect)pollingStateFrameInView:(UIView *)view;

- (void)animateToVisibleStateWithCompletion:(void (^)(BOOL finished))completion;
- (void)animateToPollingStateWithCompletion:(void (^)(BOOL finished))completion;

@end
