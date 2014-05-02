//
//  OSKAccount.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKManagedAccount.h"

#import "NSString+OSK_UUID.h"
#import "NSCoder+OSKCoder.h"

#import "OSKManagedAccountCredential.h"
#import "OSKApplicationCredential.h"

static NSString * OSKManagedAccountKey_OvershareAccountIdentifier = @"OSKManagedAccountKey_OvershareAccountIdentifier";
static NSString * OSKManagedAccountKey_AccountID = @"OSKManagedAccountKey_AccountID";
static NSString * OSKManagedAccountKey_Username = @"OSKManagedAccountKey_Username";
static NSString * OSKManagedAccountKey_FullName = @"OSKManagedAccountKey_FullName";
static NSString * OSKManagedAccountKey_ActivityType = @"OSKManagedAccountKey_ActivityType";

@interface OSKManagedAccount ()

@property (copy, nonatomic, readwrite) NSString *overshareAccountIdentifier;
@property (copy, nonatomic, readwrite) NSString *activityType;
@property (strong, nonatomic, readwrite) OSKManagedAccountCredential *credential;

@end

@implementation OSKManagedAccount

+ (NSString *)generateNewOvershareAccountIdentifier {
    return [NSString osk_stringWithNewUUID];
}

+ (BOOL)accountsAreDuplicates:(OSKManagedAccount *)firstAccount secondAccount:(OSKManagedAccount *)secondAccount {
    BOOL areDuplicates = NO;
    if ([firstAccount.activityType isEqualToString:secondAccount.activityType]) {
        if ([firstAccount.accountID isEqualToString:secondAccount.accountID]) {
            areDuplicates = YES;
        }
        else if ([firstAccount.username isEqualToString:secondAccount.username]) {
            areDuplicates = YES;
        }
    }
    return areDuplicates;
}

- (instancetype)initWithOvershareAccountIdentifier:(NSString *)identifier
                                      activityType:(NSString *)activityType
                                        credential:(OSKManagedAccountCredential *)credential {
    self = [super init];
    if (self) {
        _overshareAccountIdentifier = [identifier copy];
        _activityType = activityType.copy;
        _credential = credential;
    }
    return self;
}

- (void)signOut {
    // no op at this time, though we could remove shit from the Keychain.
}

- (NSString *)nonNilDisplayName {
    NSString *name = nil;
    if (self.username.length) {
        name = self.username;
    }
    else if (self.fullName.length) {
        name = self.fullName;
    }
    else if (self.credential.email.length) {
        name = self.credential.email;
    }
    else {
        name = @"You";
    }
    return name;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _overshareAccountIdentifier = [aDecoder decodeObjectForKey:OSKManagedAccountKey_OvershareAccountIdentifier];
        
        NSAssert(_overshareAccountIdentifier.length, @"OSKManagedAccounts read from disk must have a valid overshare account identifier.");
        _credential = [[OSKManagedAccountCredential alloc] initWithSavedValuesFromTheKeychain:_overshareAccountIdentifier];
        
        _accountID = [aDecoder decodeObjectForKey:OSKManagedAccountKey_AccountID];
        _username = [aDecoder decodeObjectForKey:OSKManagedAccountKey_Username];
        _fullName = [aDecoder decodeObjectForKey:OSKManagedAccountKey_FullName];
        _activityType = [aDecoder decodeObjectForKey:OSKManagedAccountKey_ActivityType];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [NSCoder osk_encodeObjectIfNotNil:self.overshareAccountIdentifier forKey:OSKManagedAccountKey_OvershareAccountIdentifier withCoder:aCoder];
    [NSCoder osk_encodeObjectIfNotNil:self.accountID forKey:OSKManagedAccountKey_AccountID withCoder:aCoder];
    [NSCoder osk_encodeObjectIfNotNil:self.username forKey:OSKManagedAccountKey_Username withCoder:aCoder];
    [NSCoder osk_encodeObjectIfNotNil:self.fullName forKey:OSKManagedAccountKey_FullName withCoder:aCoder];
    [NSCoder osk_encodeObjectIfNotNil:self.activityType forKey:OSKManagedAccountKey_ActivityType withCoder:aCoder];
}

@end









