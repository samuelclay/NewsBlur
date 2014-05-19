//
//  OSKApplicationCredential.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

///-----------------------------------------------
/// @name Application Credential
///-----------------------------------------------

/**
 Some services require application-specific credentials in order to authenticate a user.
 */
@interface OSKApplicationCredential : NSObject

/**
 The application key or identifier, obtained from the third-party service.
 
 @warning Overshare does **not** store application credentials.
 */
@property (copy, nonatomic, readonly) NSString *applicationKey;

/**
 The application secret or identifier, obtained from the third-party service.
 
  @warning Overshare does **not** store application credentials.
 */
@property (copy, nonatomic, readonly) NSString *applicationSecret;

/**
 A human-readable name for the current application as it might appear to users of the 
 third-party service from which the application credential was derived.
 */
@property (copy, nonatomic, readonly) NSString *appName;

- (instancetype)initWithOvershareApplicationKey:(NSString *)applicationKey
                              applicationSecret:(NSString *)applicationSecret
                                        appName:(NSString *)appName;

@end


