//
//  ADNPassportLaunchView.m
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

#import "ADNPassportLaunchView.h"

#import "ADNLogin.h"


@implementation ADNPassportLaunchView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		[self setupSubviews];
    }

    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		[self setupSubviews];
	}

	return self;
}

- (void)setupSubviews {
	self.backgroundColor = [UIColor whiteColor];

	self.signupLabel = [[UILabel alloc] initWithFrame:CGRectMake(20.0, 4.0, 280.0, 39.0)];
	self.signupLabel.backgroundColor = [UIColor clearColor];
	self.signupLabel.textAlignment = NSTextAlignmentCenter;
	self.signupLabel.numberOfLines = 0;
	self.signupLabel.lineBreakMode = NSLineBreakByWordWrapping;
	self.signupLabel.font = [UIFont systemFontOfSize:14.0];
	[self addSubview:self.signupLabel];

	self.button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	self.button.frame = CGRectMake(20.0, 50.0, 280.0, 42.0);
	[self.button addTarget:self action:@selector(installClicked:) forControlEvents:UIControlEventTouchUpInside];
	[self addSubview:self.button];

	self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	self.activityIndicator.frame = CGRectMake(85.0, 100.0, 20.0, 20.0);
	self.activityIndicator.alpha = 0.0;
	[self addSubview:self.activityIndicator];

	self.waitingLabel = [[UILabel alloc] initWithFrame:CGRectMake(113.0, 99.0, 187.0, 21.0)];
	self.waitingLabel.backgroundColor = [UIColor clearColor];
	self.waitingLabel.font = [UIFont systemFontOfSize:14.0];
	self.waitingLabel.alpha = 0.0;
	[self addSubview:self.waitingLabel];

	if ([[ADNLogin sharedInstance] isLoginAvailable]) {
		self.signupLabel.text = NSLocalizedString(@"Need an App.net account?\nLaunch Passport to sign up for free.", nil);
		[self.button setTitle:NSLocalizedString(@"Authorize with App.net Passport", nil) forState:UIControlStateNormal];
		self.waitingLabel.text = NSLocalizedString(@"Launching Passport...", nil);
	} else {
		self.signupLabel.text = NSLocalizedString(@"Need an App.net account?\nGet Passport to sign up for free.", nil);
		[self.button setTitle:NSLocalizedString(@"Install App.net Passport", nil) forState:UIControlStateNormal];
		self.waitingLabel.text = NSLocalizedString(@"Waiting for install...", nil);
	}
}

- (CGRect)hiddenStateFrameInView:(UIView *)view {
	return CGRectMake(0.0, view.bounds.size.height, view.bounds.size.width, 129.0);
}

- (CGRect)visibleStateFrameInView:(UIView *)view {
	return CGRectMake(0.0, view.bounds.size.height - 105.0, view.bounds.size.width, 129.0);
}

- (CGRect)pollingStateFrameInView:(UIView *)view {
	return CGRectMake(0.0, view.bounds.size.height - 129.0, view.bounds.size.width, 129.0);
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
	[super willMoveToSuperview:newSuperview];
	
	CGRect frame = [self hiddenStateFrameInView:newSuperview];
	if (!CGRectIsEmpty(frame)) {
		self.frame = frame;
	}
}

- (void)animateToVisibleStateWithCompletion:(void (^)(BOOL finished))completion {
	[UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
		CGRect frame = [self visibleStateFrameInView:self.superview];
		if (!CGRectIsEmpty(frame)) {
			self.frame = frame;
		}

		self.activityIndicator.alpha = 0.0;
		self.waitingLabel.alpha = 0.0;
	} completion:^(BOOL finished) {
		[self.activityIndicator stopAnimating];

		if (completion) {
			completion(finished);
		}
	}];
}

- (void)animateToPollingStateWithCompletion:(void (^)(BOOL finished))completion {
	[self.activityIndicator startAnimating];

	[UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
		CGRect frame = [self pollingStateFrameInView:self.superview];
		if (!CGRectIsEmpty(frame)) {
			self.frame = frame;
		}

		self.activityIndicator.alpha = 1.0;
		self.waitingLabel.alpha = 1.0;
	} completion:completion];
}

- (void)installClicked:(id)sender {
	if ([[ADNLogin sharedInstance] isLoginAvailable]) {
		[self.delegate adnPassportLaunchViewDidRequestLogin:self];
	} else {
		[self.delegate adnPassportLaunchViewDidRequestInstall:self];
	}
}

@end
