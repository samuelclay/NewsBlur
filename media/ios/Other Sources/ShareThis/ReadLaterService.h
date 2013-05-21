/* Copyright 2012 IGN Entertainment, Inc. */

#import <Foundation/Foundation.h>
#import "KeychainItemWrapper.h"

@protocol RLService <NSObject>

@optional
- (void)handleStatusCode;
- (void)loginWithUsername:(NSString *)username password:(NSString *)password;
- (void)postToService;
- (void)logOutOfService;

@end

@interface ReadLaterService : NSObject <RLService>
@property (nonatomic) int statusCode;
@property (nonatomic, strong) NSString *url;
@property (nonatomic, strong) NSString *articleTitle;
@property (strong, nonatomic) NSDictionary *params;
- (void)performConnectionToUrl:(NSURL *)url;
- (void)performConnectionWithRequest:(NSURLRequest *)request;
- (void)performAlertViewUsingKeychain:(KeychainItemWrapper *)keychain;
- (void)showAlertMessageWithTitle:(NSString *)alertTitle Message:(NSString *)message;
@end