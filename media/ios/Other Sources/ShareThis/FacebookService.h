/* Copyright 2012 IGN Entertainment, Inc. */

#import <Foundation/Foundation.h>
#import "ShareThis.h"

@interface FacebookService : NSObject <STService>
+ (BOOL)handleFacebookOpenUrl:(NSURL *)url;
+ (void)startSessionWithURLSchemeSuffix:(NSString *)suffix;
+ (void)closeSession;
+ (BOOL)facebookAvailable;
@end
