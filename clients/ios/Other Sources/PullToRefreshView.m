//
//  PullToRefreshView.m
//  Grant Paul (chpwn)
//
//  (based on EGORefreshTableHeaderView)
//
//  Created by Devin Doty on 10/14/09October14.
//  Copyright 2009 enormego. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "PullToRefreshView.h"

#define TEXT_COLOR	 [UIColor colorWithRed:(87.0/255.0) green:(108.0/255.0) blue:(137.0/255.0) alpha:1.0]
#define FLIP_ANIMATION_DURATION 0.18f


@interface PullToRefreshView (Private)

@property (nonatomic, assign) PullToRefreshViewState state;

@end

@implementation PullToRefreshView
@synthesize delegate, scrollView;

- (void)showActivity:(BOOL)shouldShow animated:(BOOL)animated {
    if (shouldShow) [activityView startAnimating];
    else [activityView stopAnimating];

    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:(animated ? 0.1f : 0.0)];
    arrowImage.opacity = (shouldShow ? 0.0 : 1.0);
    [UIView commitAnimations];
}

- (void)setImageFlipped:(BOOL)flipped {
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.1f];
    arrowImage.transform = (flipped ? CATransform3DMakeRotation(M_PI * 2, 0.0f, 0.0f, 1.0f) : CATransform3DMakeRotation(M_PI, 0.0f, 0.0f, 1.0f));
    [UIView commitAnimations];
}

- (id)initWithScrollView:(UIScrollView *)scroll {
    CGRect frame = CGRectMake(0.0f, 0.0f - scroll.bounds.size.height, scroll.bounds.size.width, scroll.bounds.size.height);

    if ((self = [super initWithFrame:frame])) {
        scrollView = scroll;
        [scrollView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];

        UIColor *bgColor = UIColorFromRGB(0xF4F4F4);
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.backgroundColor = bgColor;

		lastUpdatedLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 30.0f, self.frame.size.width, 20.0f)];
		lastUpdatedLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		lastUpdatedLabel.font = [UIFont systemFontOfSize:12.0f];
		lastUpdatedLabel.textColor = TEXT_COLOR;
		lastUpdatedLabel.backgroundColor = [UIColor clearColor];
		lastUpdatedLabel.textAlignment = NSTextAlignmentCenter;
		[self addSubview:lastUpdatedLabel];

		statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 48.0f, self.frame.size.width, 20.0f)];
		statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		statusLabel.font = [UIFont boldSystemFontOfSize:13.0f];
		statusLabel.textColor = TEXT_COLOR;
		statusLabel.backgroundColor = [UIColor clearColor];
		statusLabel.textAlignment = NSTextAlignmentCenter;
		[self addSubview:statusLabel];

		arrowImage = [[CALayer alloc] init];
		arrowImage.frame = CGRectMake(25.0f, frame.size.height - 60.0f, 24.0f, 52.0f);
		arrowImage.contentsGravity = kCAGravityResizeAspect;
		arrowImage.contents = (id) [UIImage imageNamed:@"arrow"].CGImage;

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 40000
		if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
			arrowImage.contentsScale = [[UIScreen mainScreen] scale];
		}
#endif

		[self.layer addSublayer:arrowImage];

        activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.color = TEXT_COLOR;
		activityView.frame = CGRectMake(30.0f, frame.size.height - 38.0f, 20.0f, 20.0f);
		[self addSubview:activityView];

		[self setState:PullToRefreshViewStateNormal];
    }

    return self;
}

#pragma mark -
#pragma mark Setters

- (void)refreshLastUpdatedDate {
    NSDate *date = [NSDate date];

	if ([delegate respondsToSelector:@selector(pullToRefreshViewLastUpdated:)])
		date = [delegate pullToRefreshViewLastUpdated:self];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.doesRelativeDateFormatting = YES;
    formatter.timeStyle = NSDateFormatterShortStyle;
    formatter.dateStyle = NSDateFormatterMediumStyle;
    lastUpdatedLabel.text = [NSString stringWithFormat:@"Updated %@",
                             [formatter stringFromDate:date]];

    //    [@[[NSLocale localeWithLocaleIdentifier:@"de_DE"], [NSLocale localeWithLocaleIdentifier:@"es_ES"],[NSLocale localeWithLocaleIdentifier:@"en_US"]] enumerateObjectsUsingBlock:^(NSLocale *locale, NSUInteger idx, BOOL *stop) {
//        [formatter setLocale:locale];
//        [timeFormatter setLocale:locale];
//        [formatter setTimeZone:[NSTimeZone systemTimeZone]];
//        NSString *dateString=[formatter stringFromDate:date];
//        NSString *timeString = [timeFormatter stringFromDate:date];
//        NSLog(@"%@ %@", dateString, timeString);
//    }];
    
    [formatter release];
}

- (void)setState:(PullToRefreshViewState)state_ {
    state = state_;

	switch (state) {
		case PullToRefreshViewStateReady:
			statusLabel.text = @"Release to refresh...";
			[self showActivity:NO animated:NO];
            [self setImageFlipped:YES];
			[self refreshLastUpdatedDate];
            scrollView.contentInset = UIEdgeInsetsZero;
			break;

		case PullToRefreshViewStateNormal:
			statusLabel.text = @"Pull down to refresh...";
			[self showActivity:NO animated:NO];
            [self setImageFlipped:NO];
			[self refreshLastUpdatedDate];
            scrollView.contentInset = UIEdgeInsetsZero;
			break;

		case PullToRefreshViewStateLoading:
			statusLabel.text = @"Loading...";
			[self showActivity:YES animated:YES];
            [self setImageFlipped:NO];
			[self refreshLastUpdatedDate];
            scrollView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
			break;

		default:
			break;
	}
}

#pragma mark -
#pragma mark UIScrollView

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentOffset"]) {
        if (scrollView.isDragging) {
            if (state == PullToRefreshViewStateReady) {
                if (scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f) 
                    [self setState:PullToRefreshViewStateNormal];
            } else if (state == PullToRefreshViewStateNormal) {
                if (scrollView.contentOffset.y < -65.0f)
                    [self setState:PullToRefreshViewStateReady];
            } else if (state == PullToRefreshViewStateLoading) {
                if (scrollView.contentOffset.y >= 0)
                    scrollView.contentInset = UIEdgeInsetsZero;
                else
                    scrollView.contentInset = UIEdgeInsetsMake(MIN(-scrollView.contentOffset.y, 60.0f), 0, 0, 0);
            }
        } else {
            if (state == PullToRefreshViewStateReady) {
                [UIView beginAnimations:nil context:NULL];
                [UIView setAnimationDuration:0.2f];
                [self setState:PullToRefreshViewStateLoading];
                [UIView commitAnimations];

                if ([delegate respondsToSelector:@selector(pullToRefreshViewShouldRefresh:)])
                    [delegate pullToRefreshViewShouldRefresh:self];
            }
        }
    }
}

- (void)finishedLoading {
    if (state == PullToRefreshViewStateLoading) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.3f];
        [self setState:PullToRefreshViewStateNormal];
        [UIView commitAnimations];
    }
}

#pragma mark -
#pragma mark Dealloc

- (void)dealloc {
	[scrollView removeObserver:self forKeyPath:@"contentOffset"];
	
    [arrowImage release];
    [activityView release];
    [statusLabel release];
    [lastUpdatedLabel release];

    [super dealloc];
}

@end
