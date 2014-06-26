//
//  OSKSystemAccountManager.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKSystemAccountStore.h"
#import <Accounts/Accounts.h>
#import "OSKLogger.h"
#import "OSKFileManager.h"

static NSString * OSKSystemAccountStoreSavedActiveAccountIDsKey = @"OSKSystemAccountStoreSavedActiveAccountIDsKey";

@interface OSKSystemAccountStore ()

@property (nonatomic, strong) ACAccountStore *accountStore;
@property (strong, nonatomic) NSMutableDictionary *lastUsedAccountIDsByAccountType;

@end

@implementation OSKSystemAccountStore

+ (id)sharedInstance {
    static dispatch_once_t once;
    static OSKSystemAccountStore * sharedInstance;
    dispatch_once(&once, ^ { sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.accountStore = [[ACAccountStore alloc] init];
        [self _loadSavedActiveAccountIDs];
    }
    return self;
}

- (BOOL)accessGrantedForAccountsWithAccountTypeIdentifier:(NSString *)accountTypeIdentifier {
    ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:accountTypeIdentifier];

    return [accountType accessGranted];
}

- (void)requestAccessToAccountsWithAccountTypeIdentifier:(NSString *)accountTypeIdentifier
                                                 options:(NSDictionary *)options
                                              completion:(OSKSystemAccountAccessRequestCompletionHandler)completion
{
    ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:accountTypeIdentifier];

    [self.accountStore requestAccessToAccountsWithType:accountType options:options completion:^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                OSKLog(@"System account access request denied: %@", error.localizedDescription);
            }
           completion(granted, error);
        });
    }];
}

- (NSArray *)accountsForAccountTypeIdentifier:(NSString *)accountTypeIdentifier {
    ACAccountType *accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:accountTypeIdentifier];

    return [self.accountStore accountsWithAccountType:accountType];
}

- (void)renewCredentialsForAccount:(ACAccount *)account completion:(void(^)(ACAccountCredentialRenewResult renewResult, NSError *error))completion {
    [self.accountStore renewCredentialsForAccount:account completion:^(ACAccountCredentialRenewResult theRenewResult, NSError *theError) {
        if (completion) {
            completion(theRenewResult, theError);
        }
    }];
}

#pragma mark - Active Accounts

- (NSString *)lastUsedAccountIdentifierForType:(NSString *)accountTypeIdentifier {
    NSParameterAssert(accountTypeIdentifier);
    return self.lastUsedAccountIDsByAccountType[accountTypeIdentifier];
}

- (void)setLastUsedAccountIdentifier:(NSString *)identifier forType:(NSString *)accountTypeIdentifier {
    NSParameterAssert(identifier);
    NSParameterAssert(accountTypeIdentifier);
    [self.lastUsedAccountIDsByAccountType setObject:identifier forKey:accountTypeIdentifier];
    [[OSKFileManager sharedInstance] saveObject:self.lastUsedAccountIDsByAccountType
                                         forKey:OSKSystemAccountStoreSavedActiveAccountIDsKey
                                     completion:nil
                                completionQueue:nil];
}

- (void)_loadSavedActiveAccountIDs {
    NSDictionary *savedDictionary = (NSDictionary *)[[OSKFileManager sharedInstance] loadSavedObjectForKey:OSKSystemAccountStoreSavedActiveAccountIDsKey];
    _lastUsedAccountIDsByAccountType = [[NSMutableDictionary alloc] init];
    if (savedDictionary) {
        [_lastUsedAccountIDsByAccountType addEntriesFromDictionary:savedDictionary];
    }
}

@end






