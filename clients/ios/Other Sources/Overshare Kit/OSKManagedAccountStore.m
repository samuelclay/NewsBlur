//
//  OSKThirdPartyAccountManager.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKManagedAccountStore.h"

#import "OSKFileManager.h"
#import "OSKManagedAccount.h"
#import "OSKLogger.h"

static NSString * OSKManagedAccountStoreSavedAccountsKey = @"OSKManagedAccountStoreSavedAccountsKey";
static NSString * OSKManagedAccountStoreSavedActiveAccountIDsKey = @"OSKManagedAccountStoreSavedActiveAccountIDsKey";

@interface OSKManagedAccountStore ()

@property (strong, nonatomic) NSMutableDictionary *accountDictionariesByActivityType;
@property (strong, nonatomic) NSMutableDictionary *activeAccountIDsByActivityType;

@end

@implementation OSKManagedAccountStore

+ (id)sharedInstance {
    static dispatch_once_t once;
    static OSKManagedAccountStore * sharedInstance;
    dispatch_once(&once, ^ { sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        NSDictionary *savedAccounts = [self loadSavedAccounts];
        if (savedAccounts.allValues.count) {
            _accountDictionariesByActivityType = [[NSMutableDictionary alloc] initWithDictionary:savedAccounts];
        } else {
            _accountDictionariesByActivityType = [[NSMutableDictionary alloc] init];
        }
        _activeAccountIDsByActivityType = [self _loadSavedActiveAccountIDs];
    }
    return self;
}

- (NSArray *)accountsForActivityType:(NSString *)activityType {
    NSParameterAssert(activityType);
    return [[self _mutableAccountsDictionaryForActivityType:activityType] allValues];
}

- (OSKManagedAccount *)existingAccountMatchingPotentialDuplicateAccount:(OSKManagedAccount *)account {
    OSKManagedAccount *matchingAccount = nil;
    NSMutableDictionary *accounts = [self _mutableAccountsDictionaryForActivityType:account.activityType];
    for (OSKManagedAccount *existingAccount in accounts.allValues) {
        if ([OSKManagedAccount accountsAreDuplicates:account secondAccount:existingAccount]) {
            matchingAccount = existingAccount;
            break;
        }
    }
    return matchingAccount;
}

- (void)addAccount:(OSKManagedAccount *)account forActivityType:(NSString *)activityType {
    NSParameterAssert(account);
    NSParameterAssert(activityType);
    OSKManagedAccount *existingDuplicateAccount = nil;
    existingDuplicateAccount = [self existingAccountMatchingPotentialDuplicateAccount:account];
    if (existingDuplicateAccount) {
        OSKLog(@"New account is a duplicate. Replacing old: %@ with new: %@", existingDuplicateAccount, account);
        [self removeAccount:existingDuplicateAccount forActivityType:existingDuplicateAccount.activityType];
    } else {
        OSKLog(@"Added account: %@ of type: %@", account, activityType);
    }
    
    NSMutableDictionary *mutableDictionary = [self _mutableAccountsDictionaryForActivityType:activityType];
    mutableDictionary[account.overshareAccountIdentifier] = account;
    [self saveAccounts];
}

- (void)removeAccount:(OSKManagedAccount *)account forActivityType:(NSString *)activityType {
    NSParameterAssert(account);
    NSParameterAssert(activityType);
    [account signOut];
    NSMutableDictionary *mutableDictionary = [self _mutableAccountsDictionaryForActivityType:activityType];
    [mutableDictionary removeObjectForKey:account.overshareAccountIdentifier];
    [self saveAccounts];
}

- (NSMutableDictionary *)_mutableAccountsDictionaryForActivityType:(NSString *)activityType {
    NSMutableDictionary *mutableDictionary = _accountDictionariesByActivityType[activityType];
    if (mutableDictionary == nil) {
        mutableDictionary = [[NSMutableDictionary alloc] init];
        _accountDictionariesByActivityType[activityType] = mutableDictionary;
    }
    return mutableDictionary;
}

- (NSDictionary *)loadSavedAccounts {
    return (NSDictionary *)[[OSKFileManager sharedInstance] loadSavedObjectForKey:OSKManagedAccountStoreSavedAccountsKey];
}

- (void)saveAccounts {
    [[OSKFileManager sharedInstance] saveObject:_accountDictionariesByActivityType
                                         forKey:OSKManagedAccountStoreSavedAccountsKey
                                     completion:nil
                                completionQueue:nil];
    [[OSKFileManager sharedInstance] saveObject:_activeAccountIDsByActivityType
                                         forKey:OSKManagedAccountStoreSavedActiveAccountIDsKey
                                     completion:nil
                                completionQueue:nil];
}

#pragma mark - Active Accounts

- (OSKManagedAccount *)activeAccountForActivityType:(NSString *)activityType {
    NSParameterAssert(activityType);
    NSString *accountID = _activeAccountIDsByActivityType[activityType];
    NSMutableDictionary *mutableDictionary = [self _mutableAccountsDictionaryForActivityType:activityType];
    OSKManagedAccount *account = nil;
    if (accountID.length) {
        account = mutableDictionary[accountID];
    }
    if (account == nil && mutableDictionary.count > 0) {
        account = [mutableDictionary.allValues firstObject];
    }
    return account;
}

- (void)setActiveAccount:(OSKManagedAccount *)account forActivityType:(NSString *)activityType {
    NSParameterAssert(account);
    NSParameterAssert(activityType);
    [_activeAccountIDsByActivityType setObject:account.overshareAccountIdentifier forKey:activityType];
    [[OSKFileManager sharedInstance] saveObject:_activeAccountIDsByActivityType
                                         forKey:OSKManagedAccountStoreSavedActiveAccountIDsKey
                                     completion:nil
                                completionQueue:nil];
}

- (NSMutableDictionary *)_loadSavedActiveAccountIDs {
    NSDictionary *savedDictionary = (NSDictionary *)[[OSKFileManager sharedInstance] loadSavedObjectForKey:OSKManagedAccountStoreSavedActiveAccountIDsKey];
    _activeAccountIDsByActivityType = [[NSMutableDictionary alloc] init];
    if (savedDictionary) {
        [_activeAccountIDsByActivityType addEntriesFromDictionary:savedDictionary];
    }
    return _activeAccountIDsByActivityType;
}

@end





