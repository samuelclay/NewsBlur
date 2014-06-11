//
//  OSKActivitiesManager.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKActivitiesManager.h"

#import "ADNLogin.h"
#import "OSKActivity.h"
#import "OSKActivityCustomizations.h"
#import "OSKApplicationCredential.h"
#import "OSKFileManager.h"
#import "OSKShareableContent.h"
#import "OSKShareableContentItem.h"
#import "OSKLogger.h"

#import "OSK1PasswordSearchActivity.h"
#import "OSK1PasswordBrowserActivity.h"
#import "OSKAirDropActivity.h"
#import "OSKAppDotNetActivity.h"
#import "OSKChromeActivity.h"
#import "OSKCopyToPasteboardActivity.h"
#import "OSKDraftsActivity.h"
#import "OSKEmailActivity.h"
#import "OSKFacebookActivity.h"
#import "OSKGooglePlusActivity.h"
#import "OSKInstapaperActivity.h"
#import "OSKReadingListActivity.h"
#import "OSKOmnifocusActivity.h"
#import "OSKPinboardActivity.h"
#import "OSKPocketActivity.h"
#import "OSKReadabilityActivity.h"
#import "OSKSafariActivity.h"
#import "OSKSaveToCameraRollActivity.h"
#import "OSKSMSActivity.h"
#import "OSKThingsActivity.h"
#import "OSKTwitterActivity.h"

#if DEBUG == 1
// DEVELOPMENT KEYS ONLY, YOUR APP SHOULD SUPPLY YOUR APP CREDENTIALS VIA THE CUSTOMIZATIONS DELEGATE.
static NSString * OSKApplicationCredential_AppDotNet_Dev = @"pZRc4r5hqKsZ73EW8T2dmaQGBcBNVSr6";
static NSString * OSKApplicationCredential_Pocket_iPhone_Dev = @"19568-eab36ebc89e751893a754475";
static NSString * OSKApplicationCredential_Pocket_iPad_Dev = @"19568-04ba9f583c2efd7d3c59208f";
static NSString * OSKApplicationCredential_Readability_Key = @"oversharedev";
static NSString * OSKApplicationCredential_Readability_Secret = @"hWA7rwPqzvNEaK8ZbRBw9fc5kKBQMdRK";
static NSString * OSKApplicationCredential_Facebook_Key = @"554155471323751";
static NSString * OSKApplicationCredential_GooglePlus_Key = @"810720596839-qccfsg2b2ljn0cnu76rha48f5dguns3j.apps.googleusercontent.com";
#endif

NSString * const OSKActivitiesManagerDidMarkActivityTypesAsPurchasedNotification = @"OSKActivitiesManagerDidMarkActivityTypesAsPurchasedNotification";
NSString * const OSKActivitiesManagerDidMarkActivityTypesAsUnpurchasedNotification = @"OSKActivitiesManagerDidMarkActivityTypesAsUnpurchasedNotification";
NSString * const OSKActivitiesManagerActivityTypesKey = @"OSKActivitiesManagerActivityTypesKey";

static NSString * OSKActivitiesManagerPersistentExclusionsKey = @"OSKActivitiesManagerPersistentExclusionsKey";

@interface OSKActivitiesManager ()

@property (strong, nonatomic) NSMutableSet *activityTypesRequiringPurchase;
@property (strong, nonatomic) NSMutableSet *purchasedActivityTypes;
@property (strong, nonatomic) NSMutableSet *persistentExclusions;

@end

@implementation OSKActivitiesManager

#pragma mark - Initialization

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static OSKActivitiesManager * sharedInstance;
    dispatch_once(&once, ^ { sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}

- (void)dealloc {
    if (_syncActivityTypeExclusionsViaiCloud) {
        [[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
         object:[NSUbiquitousKeyValueStore defaultStore]];
    }
}

- (id)init {
    self = [super init];
    if (self) {
        _activityTypesRequiringPurchase = [[NSMutableSet alloc] init];
        _purchasedActivityTypes = [[NSMutableSet alloc] init];
        [self loadSavedPersistentExclusions];
    }
    return self;
}

#pragma mark - Creating Valid Activities

- (NSArray *)validActivitiesForContent:(OSKShareableContent *)content options:(NSDictionary *)options {
    // Create an OSKActivity for each OSKActivity subclass that supports
    // each contentItem of the content object, excluding those activities
    // whose types are included in the excludedActivityTypes. Then append
    // the bespokeActivities, if any.
    
    NSArray *bespokeActivities = options[OSKActivityOption_BespokeActivities];
    BOOL requireOperations = [options[OSKActivityOption_RequireOperations] boolValue];
    
    NSArray *excludedActivityTypes = options[OSKActivityOption_ExcludedTypes];
    if (excludedActivityTypes == nil) {
        excludedActivityTypes = _persistentExclusions.allObjects;
    } else {
        excludedActivityTypes = [excludedActivityTypes arrayByAddingObjectsFromArray:_persistentExclusions.allObjects];
    }
    
    NSMutableArray *validActivities = [[NSMutableArray alloc] init];
    NSArray *sortedContentItems = [self sortedContentItemsForContent:content];
    for (OSKShareableContentItem *item in sortedContentItems) {
        NSArray *activitiesToAdd = nil;
        if ([item.itemType isEqualToString:OSKShareableContentItemType_AirDrop]) {
            activitiesToAdd = [self builtInActivitiesForAirDropItem:(OSKAirDropContentItem *)item
                                              excludedActivityTypes:excludedActivityTypes
                                                  requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_MicroblogPost]) {
            activitiesToAdd = [self builtInActivitiesForMicroblogPostItem:(OSKMicroblogPostContentItem *)item
                                                    excludedActivityTypes:excludedActivityTypes
                                                        requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_Facebook]) {
            activitiesToAdd = [self builtInActivitiesForFacebookItem:(OSKFacebookContentItem *)item
                                               excludedActivityTypes:excludedActivityTypes
                                                   requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_BlogPost]) {
            activitiesToAdd = [self builtInActivitiesForBlogPostItem:(OSKBlogPostContentItem *)item
                                             excludedActivityTypes:excludedActivityTypes
                                                 requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_Email]) {
            activitiesToAdd = [self builtInActivitiesForEmailItem:(OSKEmailContentItem *)item
                                          excludedActivityTypes:excludedActivityTypes
                                              requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_SMS]) {
            activitiesToAdd = [self builtInActivitiesForSMSItem:(OSKSMSContentItem *)item
                                        excludedActivityTypes:excludedActivityTypes
                                            requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_PhotoSharing]) {
            activitiesToAdd = [self builtInActivitiesForPhotosharingItem:(OSKPhotoSharingContentItem *)item
                                                 excludedActivityTypes:excludedActivityTypes
                                                     requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_CopyToPasteboard]) {
            activitiesToAdd = [self builtInActivitiesForCopyToPasteboardItem:(OSKCopyToPasteboardContentItem *)item
                                                     excludedActivityTypes:excludedActivityTypes
                                                         requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_ReadLater]) {
            activitiesToAdd = [self builtInActivitiesForReadLaterItem:(OSKReadLaterContentItem *)item
                                              excludedActivityTypes:excludedActivityTypes
                                                  requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_LinkBookmark]) {
            activitiesToAdd = [self builtInActivitiesForLinkBookmarkingItem:(OSKLinkBookmarkContentItem *)item
                                                    excludedActivityTypes:excludedActivityTypes
                                                        requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_WebBrowser]) {
            activitiesToAdd = [self builtInActivitiesForWebBrowserItem:(OSKWebBrowserContentItem *)item
                                               excludedActivityTypes:excludedActivityTypes
                                                   requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_ToDoListEntry]) {
            activitiesToAdd = [self builtInActivitiesForToDoListItem:(OSKToDoListEntryContentItem *)item
                                               excludedActivityTypes:excludedActivityTypes
                                                   requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_PasswordManagementAppSearch]) {
            activitiesToAdd = [self builtInActivitiesForPasswordSearchItem:(OSKPasswordManagementAppSearchContentItem *)item
                                                   excludedActivityTypes:excludedActivityTypes
                                                       requireOperations:requireOperations];
        }
        else if ([item.itemType isEqualToString:OSKShareableContentItemType_TextEditing]) {
            activitiesToAdd = [self builtInActivitiesForTextEditingItem:(OSKTextEditingContentItem *)item
                                                  excludedActivityTypes:excludedActivityTypes
                                                      requireOperations:requireOperations];
        }
        
        [validActivities addObjectsFromArray:activitiesToAdd];
        
        for (id activityClass in bespokeActivities) {
            NSAssert([activityClass respondsToSelector:@selector(supportedContentItemType)], @"The bespokeActivities array must contain classes inheriting from OSKActivity, not actual instances of the class.");
            if ([[activityClass supportedContentItemType] isEqualToString:item.itemType]) {
                NSString *type = [activityClass activityType];
                if ([excludedActivityTypes containsObject:type] == NO) {
                    if ((requireOperations && [activityClass canPerformViaOperation]) || requireOperations == NO) {
                        OSKActivity *activity = [[activityClass alloc] initWithContentItem:item];
                        if (activity) {
                            [validActivities addObject:activity];
                        }
                    }
                }
            }
        }
    }
    
    return validActivities;
}

- (NSArray *)sortedContentItemsForContent:(OSKShareableContent *)content {
    NSMutableArray *sortedItems = [[NSMutableArray alloc] init];
    NSArray *additionals = nil;
    
    if (content.airDropItem) { [sortedItems addObject:content.airDropItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_AirDrop inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.smsItem) { [sortedItems addObject:content.smsItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_SMS inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.emailItem) { [sortedItems addObject:content.emailItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_Email inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.facebookItem) { [sortedItems addObject:content.facebookItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_Facebook inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.microblogPostItem) { [sortedItems addObject:content.microblogPostItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_MicroblogPost inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.pasteboardItem) { [sortedItems addObject:content.pasteboardItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_CopyToPasteboard inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.webBrowserItem) { [sortedItems addObject:content.webBrowserItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_WebBrowser inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.photoSharingItem) { [sortedItems addObject:content.photoSharingItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_PhotoSharing inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.readLaterItem) { [sortedItems addObject:content.readLaterItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_ReadLater inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.blogPostItem) { [sortedItems addObject:content.blogPostItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_BlogPost inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.linkBookmarkItem) { [sortedItems addObject:content.linkBookmarkItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_LinkBookmark inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.textEditingItem) { [sortedItems addObject:content.textEditingItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_TextEditing inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];

    if (content.toDoListItem) { [sortedItems addObject:content.toDoListItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_ToDoListEntry inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.passwordSearchItem) { [sortedItems addObject:content.passwordSearchItem]; }
    additionals = [self contentItemsOfType:OSKShareableContentItemType_PasswordManagementAppSearch inArray:content.additionalItems];
    [sortedItems addObjectsFromArray:additionals];
    
    if (content.additionalItems) {
        NSMutableSet *customContentItems = [NSMutableSet setWithArray:content.additionalItems];
        [customContentItems minusSet:[NSSet setWithArray:sortedItems]];
        if (customContentItems.count) {
            [sortedItems addObjectsFromArray:customContentItems.allObjects];
        }
    }

    return sortedItems;
}

- (NSArray *)contentItemsOfType:(NSString *)itemType inArray:(NSArray *)array {
    NSMutableArray *additionals = [[NSMutableArray alloc] init];
    for (OSKShareableContentItem *item in array) {
        if ([item.itemType isEqualToString:itemType]) {
            [additionals addObject:item];
        }
    }
    return additionals;
}

- (NSArray *)builtInActivitiesForMicroblogPostItem:(OSKMicroblogPostContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKTwitterActivity *twitter = [self validActivityForType:[OSKTwitterActivity activityType]
                                                   class:[OSKTwitterActivity class]
                                           excludedTypes:excludedActivityTypes
                                       requireOperations:requireOperations
                                                    item:item];
    if (twitter) { [activities addObject:twitter]; }
    
    OSKAppDotNetActivity *appDotNet = [self validActivityForType:[OSKAppDotNetActivity activityType]
                                                       class:[OSKAppDotNetActivity class]
                                               excludedTypes:excludedActivityTypes
                                           requireOperations:requireOperations
                                                        item:item];
    if (appDotNet) { [activities addObject:appDotNet]; }

    OSKGooglePlusActivity *googlePlus = [self validActivityForType:[OSKGooglePlusActivity activityType]
                                                             class:[OSKGooglePlusActivity class]
                                                     excludedTypes:excludedActivityTypes
                                                 requireOperations:requireOperations
                                                              item:item];
    if (googlePlus) { [activities addObject:googlePlus]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForFacebookItem:(OSKFacebookContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKFacebookActivity *facebook = [self validActivityForType:[OSKFacebookActivity activityType]
                                                         class:[OSKFacebookActivity class]
                                                 excludedTypes:excludedActivityTypes
                                             requireOperations:requireOperations
                                                          item:item];
    if (facebook) { [activities addObject:facebook]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForBlogPostItem:(OSKBlogPostContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    return nil;
}

- (NSArray *)builtInActivitiesForSMSItem:(OSKSMSContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKSMSActivity *message = [self validActivityForType:[OSKSMSActivity activityType]
                                                   class:[OSKSMSActivity class]
                                           excludedTypes:excludedActivityTypes
                                       requireOperations:requireOperations
                                                    item:item];
    if (message) { [activities addObject:message]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForEmailItem:(OSKEmailContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKEmailActivity *email = [self validActivityForType:[OSKEmailActivity activityType]
                                                   class:[OSKEmailActivity class]
                                           excludedTypes:excludedActivityTypes
                                       requireOperations:requireOperations
                                                    item:item];
    if (email) { [activities addObject:email]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForPasswordSearchItem:(OSKPasswordManagementAppSearchContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSK1PasswordSearchActivity *onePassword = [self validActivityForType:[OSK1PasswordSearchActivity activityType]
                                                                   class:[OSK1PasswordSearchActivity class]
                                                           excludedTypes:excludedActivityTypes
                                                       requireOperations:requireOperations
                                                                    item:item];
    if (onePassword) { [activities addObject:onePassword]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForCopyToPasteboardItem:(OSKCopyToPasteboardContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKCopyToPasteboardActivity *copyToPasteboard = [self validActivityForType:[OSKCopyToPasteboardActivity activityType]
                                                                         class:[OSKCopyToPasteboardActivity class]
                                                                 excludedTypes:excludedActivityTypes
                                                             requireOperations:requireOperations
                                                                          item:item];
    if (copyToPasteboard) { [activities addObject:copyToPasteboard]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForToDoListItem:(OSKToDoListEntryContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKOmnifocusActivity *omniFocus = [self validActivityForType:[OSKOmnifocusActivity activityType]
                                                            class:[OSKOmnifocusActivity class]
                                                    excludedTypes:excludedActivityTypes
                                                requireOperations:requireOperations
                                                             item:item];
    if (omniFocus) { [activities addObject:omniFocus]; }
    
    OSKThingsActivity *things = [self validActivityForType:[OSKThingsActivity activityType]
                                                     class:[OSKThingsActivity class]
                                             excludedTypes:excludedActivityTypes
                                         requireOperations:requireOperations
                                                      item:item];
    if (things) { [activities addObject:things]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForPhotosharingItem:(OSKPhotoSharingContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKSaveToCameraRollActivity *saveToCameraRoll = [self validActivityForType:[OSKSaveToCameraRollActivity activityType]
                                                                         class:[OSKSaveToCameraRollActivity class]
                                                                 excludedTypes:excludedActivityTypes
                                                             requireOperations:requireOperations
                                                                          item:item];
    if (saveToCameraRoll) { [activities addObject:saveToCameraRoll]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForReadLaterItem:(OSKReadLaterContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKReadingListActivity *readingList = [self validActivityForType:[OSKReadingListActivity activityType]
                                                               class:[OSKReadingListActivity class]
                                                       excludedTypes:excludedActivityTypes
                                                   requireOperations:requireOperations
                                                                item:item];
    if (readingList) { [activities addObject:readingList]; }
    
    OSKInstapaperActivity *instapaper = [self validActivityForType:[OSKInstapaperActivity activityType]
                                                                 class:[OSKInstapaperActivity class]
                                                         excludedTypes:excludedActivityTypes
                                                     requireOperations:requireOperations
                                                                  item:item];
    if (instapaper) { [activities addObject:instapaper]; }
    
    OSKPocketActivity *pocket = [self validActivityForType:[OSKPocketActivity activityType]
                                                     class:[OSKPocketActivity class]
                                             excludedTypes:excludedActivityTypes
                                         requireOperations:requireOperations
                                                      item:item];
    if (pocket) { [activities addObject:pocket]; }
    
    OSKReadabilityActivity *readability = [self validActivityForType:[OSKReadabilityActivity activityType]
                                                               class:[OSKReadabilityActivity class]
                                                       excludedTypes:excludedActivityTypes
                                                   requireOperations:requireOperations
                                                                item:item];
    if (readability) { [activities addObject:readability]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForLinkBookmarkingItem:(OSKLinkBookmarkContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKPinboardActivity *pinboardActivity = [self validActivityForType:[OSKPinboardActivity activityType]
                                                                 class:[OSKPinboardActivity class]
                                                         excludedTypes:excludedActivityTypes
                                                     requireOperations:requireOperations
                                                                  item:item];
    if (pinboardActivity) { [activities addObject:pinboardActivity]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForWebBrowserItem:(OSKWebBrowserContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKSafariActivity *safariActivity = [self validActivityForType:[OSKSafariActivity activityType]
                                                             class:[OSKSafariActivity class]
                                                     excludedTypes:excludedActivityTypes
                                                 requireOperations:requireOperations
                                                              item:item];
    if (safariActivity) { [activities addObject:safariActivity]; }
    
    OSKChromeActivity *chromeActivity = [self validActivityForType:[OSKChromeActivity activityType]
                                                             class:[OSKChromeActivity class]
                                                     excludedTypes:excludedActivityTypes
                                                 requireOperations:requireOperations
                                                              item:item];
    if (chromeActivity) { [activities addObject:chromeActivity]; }

    OSK1PasswordBrowserActivity *onePassword = [self validActivityForType:[OSK1PasswordBrowserActivity activityType]
                                                                    class:[OSK1PasswordBrowserActivity class]
                                                            excludedTypes:excludedActivityTypes
                                                        requireOperations:requireOperations
                                                                     item:item];
    if (onePassword) { [activities addObject:onePassword]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForAirDropItem:(OSKAirDropContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKAirDropActivity *airDrop = [self validActivityForType:[OSKAirDropActivity activityType]
                                                             class:[OSKAirDropActivity class]
                                                     excludedTypes:excludedActivityTypes
                                                 requireOperations:requireOperations
                                                              item:item];
    if (airDrop) { [activities addObject:airDrop]; }
    
    return activities;
}

- (NSArray *)builtInActivitiesForTextEditingItem:(OSKTextEditingContentItem *)item excludedActivityTypes:(NSArray *)excludedActivityTypes requireOperations:(BOOL)requireOperations {
    NSMutableArray *activities = [[NSMutableArray alloc] init];
    
    OSKDraftsActivity *drafts = [self validActivityForType:[OSKDraftsActivity activityType]
                                                      class:[OSKDraftsActivity class]
                                               excludedTypes:excludedActivityTypes
                                           requireOperations:requireOperations
                                                        item:item];
    if (drafts) { [activities addObject:drafts]; }
    
    return activities;
}

- (id)validActivityForType:(NSString *)activityType class:(id)activityClass excludedTypes:(NSArray *)excludedTypes requireOperations:(BOOL)requireOperations item:(OSKShareableContentItem *)item {
    OSKActivity *activity = nil;
    if ([excludedTypes containsObject:activityType] == NO) {
        if ([activityClass isAvailable]) {
            if ((requireOperations && [activityClass canPerformViaOperation]) || requireOperations == NO) {
                BOOL applicationCredentialOkay = YES;
                if ([activityClass respondsToSelector:@selector(requiresApplicationCredential)]) {
                    BOOL requiresAppCred = [activityClass requiresApplicationCredential];
                    if (requiresAppCred) {
                        OSKApplicationCredential *appCred = [self applicationCredentialForActivityType:activityType];
                        if (appCred == nil) {
                            applicationCredentialOkay = NO;
                        }
                    }
                }
                if (applicationCredentialOkay) {
                    activity = [[activityClass alloc] initWithContentItem:item];
                }
            }
        }
    }
    return activity;
}

#pragma mark - Persistent Exclusions

- (void)markActivityTypes:(NSArray *)types alwaysExcluded:(BOOL)excluded {
    if (excluded) {
        [_persistentExclusions addObjectsFromArray:types];
    } else {
        for (NSString *type in types) {
            [_persistentExclusions removeObject:type];
        }
    }
    [self savePersistentExclusions:YES];
}

- (void)savePersistentExclusions:(BOOL)writeToiCloudIfEnabled {
    [[OSKFileManager sharedInstance] saveObject:_persistentExclusions.allObjects
                                         forKey:OSKActivitiesManagerPersistentExclusionsKey
                                     completion:nil
                                completionQueue:nil];
    
    if (_syncActivityTypeExclusionsViaiCloud && writeToiCloudIfEnabled) {
        NSArray *excludedTypes = _persistentExclusions.allObjects;
        [[NSUbiquitousKeyValueStore defaultStore] setObject:excludedTypes forKey:OSKActivitiesManagerPersistentExclusionsKey];
        [[NSUbiquitousKeyValueStore defaultStore] synchronize];
    }
}

- (void)loadSavedPersistentExclusions {
    NSArray *savedExclusions = [[OSKFileManager sharedInstance] loadSavedObjectForKey:OSKActivitiesManagerPersistentExclusionsKey];
    if (savedExclusions) {
        _persistentExclusions = [[NSMutableSet alloc] initWithArray:savedExclusions];
    } else {
        _persistentExclusions = [[NSMutableSet alloc] init];
    }
}

- (BOOL)activityTypeIsAlwaysExcluded:(NSString *)type {
    return [_persistentExclusions containsObject:type];
}

- (void)setSyncActivityTypeExclusionsViaiCloud:(BOOL)syncActivityTypeExclusionsViaiCloud {
    if (_syncActivityTypeExclusionsViaiCloud != syncActivityTypeExclusionsViaiCloud) {
        _syncActivityTypeExclusionsViaiCloud = syncActivityTypeExclusionsViaiCloud;
        if (_syncActivityTypeExclusionsViaiCloud) {
            [self startObservingKeyValueStoreChanges];
            [self savePersistentExclusions:YES];
        } else {
            [self stopObservingKeyValueStoreChanges];
        }
    }
}

- (void)startObservingKeyValueStoreChanges {
    [[NSNotificationCenter defaultCenter]
     addObserver: self
     selector: @selector(handleUbiquitousKeyValueChanges:)
     name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification
     object: [NSUbiquitousKeyValueStore defaultStore]];
    
    // get changes that might have happened while this
    // instance of your app wasn't running
    [[NSUbiquitousKeyValueStore defaultStore] synchronize];
}

- (void)stopObservingKeyValueStoreChanges {
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:NSUbiquitousKeyValueStoreDidChangeExternallyNotification
     object:[NSUbiquitousKeyValueStore defaultStore]];
}

- (void)handleUbiquitousKeyValueChanges:(NSNotification *)notification {
    if (_syncActivityTypeExclusionsViaiCloud) {
        NSArray *changedKeys = notification.userInfo[NSUbiquitousKeyValueStoreChangedKeysKey];
        NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];
        if ([changedKeys containsObject:OSKActivitiesManagerPersistentExclusionsKey]) {
            NSArray *exclusionsToAdd = [store objectForKey:OSKActivitiesManagerPersistentExclusionsKey];
            if (exclusionsToAdd) {
                NSMutableSet *exclusionsToRemove = [_persistentExclusions mutableCopy];
                [exclusionsToRemove minusSet:[NSSet setWithArray:exclusionsToAdd]];
                OSKLog(@"Updating activity exclusions with iCloud data:\n%@\n\nBased on userInfo: %@",
                       exclusionsToAdd,
                       notification.userInfo);
                if (exclusionsToRemove.count) {
                    [self markActivityTypes:exclusionsToRemove.allObjects alwaysExcluded:NO];
                }
                if (exclusionsToAdd.count) {
                    [self markActivityTypes:exclusionsToAdd alwaysExcluded:YES];
                }
            }
        }
    }
}

#pragma mark - App Credentials

- (OSKApplicationCredential *)applicationCredentialForActivityType:(NSString *)activityType {
    OSKApplicationCredential *appCredential = nil;
    if ([self.customizationsDelegate respondsToSelector:@selector(applicationCredentialForActivityType:)]) {
        appCredential = [self.customizationsDelegate applicationCredentialForActivityType:activityType];
    }
#if DEBUG == 1
    else {
        // THESE ARE DEVELOPMENT CREDENTIALS ONLY, TO MAKE DEMOING OVERSHARE SIMPLE FOR US.
        // YOUR APP SHOULD OBTAIN AND PROVIDE YOUR OWN CREDENTIALS BEFORE SHIPPING!!!
        if ([activityType isEqualToString:OSKActivityType_iOS_Facebook]) {
            appCredential = [[OSKApplicationCredential alloc]
                             initWithOvershareApplicationKey:OSKApplicationCredential_Facebook_Key
                             applicationSecret:nil
                             appName:@"Overshare"];
        }
        else if ([activityType isEqualToString:OSKActivityType_API_AppDotNet]) {
            appCredential = [[OSKApplicationCredential alloc]
                             initWithOvershareApplicationKey:OSKApplicationCredential_AppDotNet_Dev
                             applicationSecret:nil
                             appName:@"Overshare"];
        }
        else if ([activityType isEqualToString:OSKActivityType_API_Pocket]) {
            appCredential = [[OSKApplicationCredential alloc]
                             initWithOvershareApplicationKey:OSKApplicationCredential_Pocket_iPhone_Dev
                             applicationSecret:nil
                             appName:@"Overshare"];
        }
        else if ([activityType isEqualToString:OSKActivityType_API_Readability]) {
            appCredential = [[OSKApplicationCredential alloc]
                             initWithOvershareApplicationKey:OSKApplicationCredential_Readability_Key
                             applicationSecret:OSKApplicationCredential_Readability_Secret
                             appName:@"Overshare"];
        }
        else if ([activityType isEqualToString:OSKActivityType_API_GooglePlus]) {
            appCredential = [[OSKApplicationCredential alloc]
                             initWithOvershareApplicationKey:OSKApplicationCredential_GooglePlus_Key
                             applicationSecret:nil
                             appName:@"Overshare"];
        }
    }
#endif
    return appCredential;
}

#pragma mark - In App Purchases

- (void)markActivityTypes:(NSArray *)types asRequiringPurchase:(BOOL)requirePurchase {
    if (requirePurchase) {
        [_activityTypesRequiringPurchase addObjectsFromArray:types];
    } else {
        NSSet *setToRemove = [NSSet setWithArray:types];
        [_activityTypesRequiringPurchase minusSet:setToRemove];
    }
}

- (BOOL)activityTypeRequiresPurchase:(NSString *)type {
    return [_activityTypesRequiringPurchase containsObject:type];
}

- (void)markActivityTypes:(NSArray *)types asAlreadyPurchased:(BOOL)purchased {
    if (purchased) {
        [_purchasedActivityTypes addObjectsFromArray:types];
        [self postMarkedAsPurchasedNotification:types];
    } else {
        NSSet *setToRemove = [NSSet setWithArray:types];
        [_purchasedActivityTypes minusSet:setToRemove];
        [self postMarkedAsUnpurchasedNotification:types];
    }
}

- (BOOL)activityTypeIsPurchased:(NSString *)type {
    BOOL isPurchased = YES;
    if ([self activityTypeRequiresPurchase:type]) {
     isPurchased = [_purchasedActivityTypes containsObject:type];
    }
    return isPurchased;
}

- (void)postMarkedAsPurchasedNotification:(NSArray *)activityTypes {
    [[NSNotificationCenter defaultCenter] postNotificationName:OSKActivitiesManagerDidMarkActivityTypesAsPurchasedNotification
                                                        object:self
                                                      userInfo:@{OSKActivitiesManagerActivityTypesKey:activityTypes}];
}

- (void)postMarkedAsUnpurchasedNotification:(NSArray *)activityTypes {
    [[NSNotificationCenter defaultCenter] postNotificationName:OSKActivitiesManagerDidMarkActivityTypesAsUnpurchasedNotification
                                                        object:self
                                                      userInfo:@{OSKActivitiesManagerActivityTypesKey:activityTypes}];
}

@end








