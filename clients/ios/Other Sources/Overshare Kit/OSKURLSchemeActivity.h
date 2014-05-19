//
//  OSKURLSchemeActivity.h
//  Overshare
//
//  Created by Jared on 1/26/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

@import Foundation;

#import "OSKXCallbackURLInfo.h"

@protocol OSKURLSchemeActivity <NSObject>

- (BOOL)targetApplicationSupportsXCallbackURL;

@optional

- (void)prepareToPerformActionUsingXCallbackURLInfo:(id <OSKXCallbackURLInfo>)info;

@end
