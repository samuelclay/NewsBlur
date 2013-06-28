//
//  DEFacebookTextView.m
//  DEFacebooker
//
//  Copyright (c) 2011 Double Encore, Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
//  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
//  in the documentation and/or other materials provided with the distribution. Neither the name of the Double Encore Inc. nor the names of its 
//  contributors may be used to endorse or promote products derived from this software without specific prior written permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS 
//  BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
//  GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "DEComposeTextView.h"
#import "DEComposeRuledView.h"


@interface DEComposeTextView ()

@property (nonatomic, retain) DEComposeRuledView *ruledView;
@property (nonatomic, retain) UIButton *fromButton;
@property (nonatomic, retain) UIButton *accountButton;
@property (nonatomic, retain) UIImageView *accountLine;

- (void)textViewInit;
- (CGRect)ruledViewFrame;
- (void)updateAccountsView;

@end


@implementation DEComposeTextView

    // Public
@synthesize accountName = _accountName;
@dynamic fromButtonFrame;

    // Private
@synthesize ruledView = _ruledView;
@synthesize fromButton = _fromButton;
@synthesize accountButton = _accountButton;
@synthesize accountLine = _accountLine;


#pragma mark - Setup & Teardown

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self textViewInit];
    }
    
    return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self textViewInit];
    }
    
    return self;
}


- (void)textViewInit
{   
    self.clipsToBounds = NO;

    _ruledView = [[DEComposeRuledView alloc] initWithFrame:[self ruledViewFrame]];
    _ruledView.lineColor = [UIColor colorWithWhite:0.5f alpha:0.15f];
    _ruledView.lineWidth = 1.0f;
    _ruledView.rowHeight = self.font.lineHeight;
    [self insertSubview:self.ruledView atIndex:0];
}


#pragma mark - Superclass Overrides

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if ([self.accountName length] > 0) {
        CGRect frame = self.fromButton.frame;
        frame.origin = CGPointMake(12.0f, -21.0f);
        self.fromButton.frame = frame;
        
        frame = self.accountButton.frame;
        frame.origin.x = CGRectGetMaxX(self.fromButton.frame) + 3.0f;
        frame.origin.y = self.fromButton.frame.origin.y;
        self.accountButton.frame = frame;
        
        frame = self.accountLine.frame;
        frame.origin = CGPointMake(0.0f, CGRectGetMaxY(self.fromButton.frame) + 2.0f);
        self.accountLine.frame = frame;
        
        self.contentInset = UIEdgeInsetsMake(25.0f, 0.0f, 0.0f, 0.0f);
    }
    
    self.ruledView.frame = [self ruledViewFrame];
}


- (void)setContentSize:(CGSize)contentSize
{
    [super setContentSize:contentSize];
    self.ruledView.frame = [self ruledViewFrame];
}


- (void)setFont:(UIFont *)font
{
    [super setFont:font];
    self.ruledView.rowHeight = self.font.lineHeight;
}


#pragma mark - Private

- (CGRect)ruledViewFrame
{
    CGFloat extraForBounce = 200.0f;  // Extra added to top and bottom so it's visible when the user drags past the bounds.
    CGFloat width = 1024.0f;  // Needs to be at least as wide as we might make the Tweet sheet.
    CGFloat textAlignmentOffset = -2.0f;  // To center the text between the lines. May want to find a way to determine this procedurally eventually.
    
    CGRect frame;
    if ([self.accountName length] > 0) {
        frame = CGRectMake(0.0f, 30.0f, width, self.contentSize.height + extraForBounce);
    }
    else {
        frame = CGRectMake(0.0f, -extraForBounce + textAlignmentOffset, width, self.contentSize.height + (2 * extraForBounce));
    }
    
    return frame;
}


- (void)updateAccountsView
{
    if ([self.accountName length] > 0) {
        if (self.fromButton == nil) {
            self.fromButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [self.fromButton addTarget:self action:@selector(accountButtonTouched) forControlEvents:UIControlEventTouchUpInside];
            [self.fromButton setTitle:NSLocalizedString(@"From:", @"") forState:UIControlStateNormal];
            self.fromButton.titleLabel.font = [UIFont systemFontOfSize:17.0f];
            [self.fromButton setTitleColor:[UIColor colorWithWhite:0.58f alpha:1.0f] forState:UIControlStateNormal];
            [self.fromButton setTitleColor:[UIColor lightTextColor] forState:UIControlStateHighlighted];
            [self.fromButton sizeToFit];
            [self addSubview:self.fromButton];
        }
        if (self.accountButton == nil) {
            self.accountButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [self.accountButton addTarget:self action:@selector(accountButtonTouched) forControlEvents:UIControlEventTouchUpInside];
            [self.accountButton setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
            [self.accountButton setTitleColor:[UIColor lightTextColor] forState:UIControlStateHighlighted];
            self.accountButton.titleLabel.font = [UIFont systemFontOfSize:17.0f];
            [self addSubview:self.accountButton];
            
            self.accountLine = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DEFacebookCardAccountLine"]];
            [self addSubview:self.accountLine];
        }
        [self.accountButton setTitle:self.accountName forState:UIControlStateNormal];
        [self.accountButton sizeToFit];
        [self setNeedsLayout];
    }
    
    else {
        [self.fromButton removeFromSuperview];
        self.fromButton = nil;
        [self.accountButton removeFromSuperview];
        self.accountButton = nil;
    }
}


#pragma mark - Actions

- (IBAction)accountButtonTouched
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

    SEL tweetTextViewAccountButtonWasTouched = sel_registerName("tweetTextViewAccountButtonWasTouched:");

    if ([self.delegate respondsToSelector:tweetTextViewAccountButtonWasTouched]) {
        [self.delegate performSelector:tweetTextViewAccountButtonWasTouched withObject:self];
    }
#pragma clang diagnostic pop

}


#pragma mark - Accessors

- (void)setAccountName:(NSString *)name
{
    if ([_accountName isEqualToString:name] == NO) {
        _accountName = [name copy];
        [self updateAccountsView];
    }
}


- (CGRect)fromButtonFrame
{
    return self.fromButton.frame;
}


@end
