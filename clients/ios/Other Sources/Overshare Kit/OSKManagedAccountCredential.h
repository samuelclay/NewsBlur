//
//  OSKManagedAccountCredential.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

extern NSString * const OSKManagedAccountCredentialBaseKey_accountID;
extern NSString * const OSKManagedAccountCredentialBaseKey_username;
extern NSString * const OSKManagedAccountCredentialBaseKey_email;
extern NSString * const OSKManagedAccountCredentialBaseKey_password;
extern NSString * const OSKManagedAccountCredentialBaseKey_token;
extern NSString * const OSKManagedAccountCredentialBaseKey_tokenSecret;
extern NSString * const OSKManagedAccountCredentialBaseKey_refreshToken;
extern NSString * const OSKManagedAccountCredentialBaseKey_expiryDate;
extern NSString * const OSKManagedAccountCredentialBaseKey_expiringToken;

@interface OSKManagedAccountCredential : NSObject

@property (copy, nonatomic, readonly) NSString *overshareAccountIdentifier;
@property (copy, nonatomic, readonly) NSString *accountID;
@property (copy, nonatomic, readonly) NSString *username;
@property (copy, nonatomic, readonly) NSString *email;
@property (copy, nonatomic, readonly) NSString *password;
@property (copy, nonatomic, readonly) NSString *token;
@property (copy, nonatomic, readonly) NSString *tokenSecret;
@property (copy, nonatomic, readonly) NSString *refreshToken; // OAuth2
@property (copy, nonatomic, readonly) NSDate *expiryDate; // OAuth2
@property (copy, nonatomic, readonly) NSString *expiringToken; // OAuth2

- (instancetype)initWithSavedValuesFromTheKeychain:(NSString *)overshareAccountIdentifier;

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                          username:(NSString *)username
                                          password:(NSString *)password;

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                             email:(NSString *)email
                                          password:(NSString *)password;

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                       accessToken:(NSString *)accessToken;

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                         accountID:(NSString *)accountID
                                       accessToken:(NSString *)accessToken;

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                         accountID:(NSString *)accountID
                                        OauthToken:(NSString *)accessToken
                                  OauthTokenSecret:(NSString *)accessTokenSecret;

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                         accountID:(NSString *)accountID
                               Oauth2ExpiringToken:(NSString *)expiringToken
                                      refreshToken:(NSString *)refreshToken
                                        expiryDate:(NSDate *)expiryDate;

- (void)updateWithNewExpiringToken:(NSString *)expiringToken expiryDate:(NSDate *)expiryDate;

@end



