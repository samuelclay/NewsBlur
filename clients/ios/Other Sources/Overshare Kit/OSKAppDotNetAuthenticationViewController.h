//
//  OSKAppDotNetAuthenticationViewController.h
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKWebViewController.h"

#import "OSKAuthenticationViewController.h"

@class OSKApplicationCredential;

@interface OSKAppDotNetAuthenticationViewController : OSKWebViewController <OSKAuthenticationViewController>

- (instancetype)initWithApplicationCredential:(OSKApplicationCredential *)credential;

@end
