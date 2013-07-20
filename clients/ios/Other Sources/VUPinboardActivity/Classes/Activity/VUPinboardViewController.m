//
//  VUPinboardViewController.m
//  UIActivityDemo
//
//  Created by Boris Buegling on 29.09.12.
//  Copyright (c) 2012 Boris Buegling. All rights reserved.
//

#import "SSKeychain.h"
#import "VUPinboardAccess.h"
#import "VUPinboardActivity.h"
#import "VUPinboardViewController.h"

static NSString* const kAccount     = @"vu.org.Pinboard";
static NSString* const kServiceName = @"pinboard.in";

@interface VUPinboardViewController () <VUDialogDelegate>

@property (nonatomic, strong) VUPinboardAccess* access;
@property (nonatomic, weak) VUPinboardActivity* activity;
@property (nonatomic, assign) NSString* pinboardAccessToken;
@property (nonatomic, strong) NSURL* url;

@property (nonatomic, strong) UITextField* accessTokenView;
@property (nonatomic, strong) UITextView* descriptionView;
@property (nonatomic, strong) UISwitch* sharedView;
@property (nonatomic, strong) UITextField* tagsView;
@property (nonatomic, strong) UISwitch* toreadView;

@end

#pragma mark -

@implementation VUPinboardViewController

@dynamic pinboardAccessToken;

#pragma mark -

-(id)initWithURL:(NSURL*)url activity:(VUPinboardActivity*)activity {
    self = [super init];
    if (self) {
        self.activity = activity;
        self.delegate = self;
        self.url = url;
    }
    return self;
}

-(void)viewDidLoad {
    [self headlineWithImageResource:@"PinboardActivityImage" ofType:@"png" text:@"pinboard"];
    
    if (!self.pinboardAccessToken) {
        self.accessTokenView = [self textFieldWithLabel:@"Access token"];
        
    }
    
    UILabel* urlLabel = [self labelWithText:[NSString stringWithFormat:@"URL: %@", self.url]];
    urlLabel.font = [UIFont boldSystemFontOfSize:urlLabel.font.pointSize];
    
    // TODO: Prefill the page title into the description
    self.descriptionView = [self textViewWithLabel:@"Description"];
    self.tagsView = [self textFieldWithLabel:@"Tags"];
    
    self.sharedView = [self switchWithLabel:@"Public"];
    // TODO: Check actual user default of this property
    self.sharedView.on = YES;
    
    self.toreadView = [self switchWithLabel:@"Read later"];
    self.toreadView.on = NO;
    
    [self defaultDialogButtonsWithSubmitLabel:@"Submit" cancelLabel:@"Cancel"];
}

#pragma mark - Handle access token

-(NSString*)pinboardAccessToken {
    return [SSKeychain passwordForService:kServiceName account:kAccount];
}

-(void)setPinboardAccessToken:(NSString *)pinboardAccessToken {
    [SSKeychain setPassword:pinboardAccessToken forService:kServiceName account:kAccount];
}

#pragma mark - VUDialog delegate methods

-(void)cancelWithDialogViewController:(VUDialogViewController *)dialogViewController {
    [self.activity activityDidFinish:NO];
}

-(void)submitWithDialogViewController:(VUDialogViewController *)dialogViewController {
    if (self.accessTokenView) {
        [self setPinboardAccessToken:self.accessTokenView.text];
    }

    self.access = [[VUPinboardAccess alloc] initWithAccessToken:self.pinboardAccessToken];
    
    __weak VUPinboardViewController* sself = self;
    [self.access addURL:self.url
       description:self.descriptionView.text
              tags:self.tagsView.text
            shared:self.sharedView.on
            toread:self.toreadView.on withCompletionHandler:^(BOOL success, NSError *error) {
                [sself.activity activityDidFinish:success];
                
                if (!success) {
                    [self.activity presentError:error];
                }
            }];
}

@end
