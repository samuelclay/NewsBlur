//
//  OSKManagedAccountCredential.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKManagedAccountCredential.h"

#import "NSDate+OSK_ISO8601.h"
#import "OSKKeychainUtility.h"

NSString * const OSKManagedAccountCredentialBaseKey_accountID = @"OSKManagedAccountCredentialBaseKey_accountID";
NSString * const OSKManagedAccountCredentialBaseKey_username = @"OSKManagedAccountCredentialBaseKey_username";
NSString * const OSKManagedAccountCredentialBaseKey_email = @"OSKManagedAccountCredentialBaseKey_email";
NSString * const OSKManagedAccountCredentialBaseKey_password = @"OSKManagedAccountCredentialBaseKey_password";
NSString * const OSKManagedAccountCredentialBaseKey_token = @"OSKManagedAccountCredentialBaseKey_token";
NSString * const OSKManagedAccountCredentialBaseKey_tokenSecret = @"OSKManagedAccountCredentialBaseKey_tokenSecret";
NSString * const OSKManagedAccountCredentialBaseKey_refreshToken = @"OSKManagedAccountCredentialBaseKey_refreshToken";
NSString * const OSKManagedAccountCredentialBaseKey_expiryDate = @"OSKManagedAccountCredentialBaseKey_expiryDate";
NSString * const OSKManagedAccountCredentialBaseKey_expiringToken = @"OSKManagedAccountCredentialBaseKey_expiringToken";

@interface OSKManagedAccountCredential ()

@property (copy, nonatomic, readwrite) NSString *overshareAccountIdentifier;
@property (copy, nonatomic, readwrite) NSString *accountID;
@property (copy, nonatomic, readwrite) NSString *username;
@property (copy, nonatomic, readwrite) NSString *email;
@property (copy, nonatomic, readwrite) NSString *password;
@property (copy, nonatomic, readwrite) NSString *token;
@property (copy, nonatomic, readwrite) NSString *tokenSecret;
@property (copy, nonatomic, readwrite) NSString *refreshToken; // OAuth2
@property (copy, nonatomic, readwrite) NSDate *expiryDate; // OAuth2
@property (copy, nonatomic, readwrite) NSString *expiringToken; // OAuth2

@end

@implementation OSKManagedAccountCredential

- (instancetype)initWithSavedValuesFromTheKeychain:(NSString *)overshareAccountIdentifier {
    self = [super init];
    if (self) {
        _overshareAccountIdentifier = [overshareAccountIdentifier copy];
        [self readAllNonNilValesFromTheKeychain];
    }
    return self;
}

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                          username:(NSString *)username
                                          password:(NSString *)password {
    self = [super init];
    if (self) {
        _overshareAccountIdentifier = [identifier copy];
        _username = [username copy];
        _password = [password copy];
        [self saveAllNonNilValuesToTheKeychain];
    }
    return self;
}

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                             email:(NSString *)email
                                          password:(NSString *)password  {
    self = [super init];
    if (self) {
        _overshareAccountIdentifier = [identifier copy];
        _email = [email copy];
        _password = [password copy];
        [self saveAllNonNilValuesToTheKeychain];
    }
    return self;
}

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                       accessToken:(NSString *)accessToken {
    self = [super init];
    if (self) {
        _overshareAccountIdentifier = [identifier copy];
        _token = [accessToken copy];
        [self saveAllNonNilValuesToTheKeychain];
    }
    return self;
}

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                         accountID:(NSString *)accountID
                                       accessToken:(NSString *)accessToken {
    self = [super init];
    if (self) {
        _overshareAccountIdentifier = [identifier copy];
        _accountID = [accountID copy];
        _token = [accessToken copy];
        [self saveAllNonNilValuesToTheKeychain];
    }
    return self;
}

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                         accountID:(NSString *)accountID
                                        OauthToken:(NSString *)accessToken
                                  OauthTokenSecret:(NSString *)accessTokenSecret{
    self = [super init];
    if (self) {
        _overshareAccountIdentifier = [identifier copy];
        _accountID = [accountID copy];
        _token = [accessToken copy];
        _tokenSecret = [accessTokenSecret copy];
        [self saveAllNonNilValuesToTheKeychain];
    }
    return self;
}

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                         accountID:(NSString *)accountID
                               Oauth2ExpiringToken:(NSString *)expiringToken
                                      refreshToken:(NSString *)refreshToken
                                        expiryDate:(NSDate *)expiryDate {
    self = [super init];
    if (self) {
        _overshareAccountIdentifier = [identifier copy];
        _accountID = [accountID copy];
        _expiringToken = [expiringToken copy];
        _refreshToken = [refreshToken copy];
        _expiryDate = [expiryDate copy];
        [self saveAllNonNilValuesToTheKeychain];
    }
    return self;
}

- (void)updateWithNewExpiringToken:(NSString *)expiringToken expiryDate:(NSDate *)expiryDate {
    [self setExpiringToken:expiringToken];
    [self setExpiryDate:expiryDate];
    [self saveAllNonNilValuesToTheKeychain];
}

- (void)saveAllNonNilValuesToTheKeychain {
    if (self.accountID.length) {
        NSString *key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_accountID];
        [OSKKeychainUtility saveString:self.accountID forKey:key];
    }
    if (self.username.length) {
        NSString *key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_username];
        [OSKKeychainUtility saveString:self.username forKey:key];
    }
    if (self.email.length) {
        NSString *key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_email];
        [OSKKeychainUtility saveString:self.email forKey:key];
    }
    if (self.password.length) {
        NSString *key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_password];
        [OSKKeychainUtility saveString:self.password forKey:key];
    }
    if (self.token.length) {
        NSString *key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_token];
        [OSKKeychainUtility saveString:self.token forKey:key];
    }
    if (self.tokenSecret.length) {
        NSString *key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_tokenSecret];
        [OSKKeychainUtility saveString:self.tokenSecret forKey:key];
    }
    if (self.refreshToken.length) {
        NSString *key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_refreshToken];
        [OSKKeychainUtility saveString:self.refreshToken forKey:key];
    }
    if (self.expiringToken.length) {
        NSString *key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_expiringToken];
        [OSKKeychainUtility saveString:self.expiringToken forKey:key];
    }
    if (self.expiryDate) {
        NSString *stringFromDate = [NSDate osk_ISO8601stringFromDate:self.expiryDate];
        NSString *key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_expiryDate];
        [OSKKeychainUtility saveString:stringFromDate forKey:key];
    }
}

- (void)readAllNonNilValesFromTheKeychain {
    NSString *key = nil;
    
    key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_accountID];
    _accountID = [OSKKeychainUtility getStringForKey:key];
    
    key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_username];
    _username = [OSKKeychainUtility getStringForKey:key];

    key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_email];
    _email = [OSKKeychainUtility getStringForKey:key];

    key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_password];
    _password = [OSKKeychainUtility getStringForKey:key];

    key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_token];
    _token = [OSKKeychainUtility getStringForKey:key];

    key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_tokenSecret];
    _tokenSecret = [OSKKeychainUtility getStringForKey:key];

    key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_refreshToken];
    _refreshToken = [OSKKeychainUtility getStringForKey:key];

    key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_expiringToken];
    _expiringToken = [OSKKeychainUtility getStringForKey:key];

    key = [self composedKeyForBaseKey:OSKManagedAccountCredentialBaseKey_expiryDate];
    NSString *dateString = [OSKKeychainUtility getStringForKey:key];
    if (dateString.length) {
        _expiryDate = [NSDate osk_dateFromISO8601string:dateString];
    }
}

- (NSString *)composedKeyForBaseKey:(NSString *)baseKey {
    return [NSString stringWithFormat:@"%@_%@", baseKey, self.overshareAccountIdentifier];
}

@end












