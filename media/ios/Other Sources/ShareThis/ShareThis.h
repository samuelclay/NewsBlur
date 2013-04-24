/* Copyright 2012 IGN Entertainment, Inc. */

#import <Foundation/Foundation.h>

typedef enum {
    STServiceTypeFacebook,
    STServiceTypeTwitter,
    STServiceTypeMail,
    STServiceTypeMessage,
    STServiceTypeInstapaper,
    STServiceTypePocket,
    STServiceTypeReadability,
    STServiceTypeServiceCount
} STServiceType;

// The type of content to show sharing options for
// For example, video contents will not show read later services
typedef enum {
    STContentTypeAll,
    STContentTypeArticle,
    STContentTypeVideo
} STContentType;

extern NSString *const AppDidBecomeActiveNotificationName;
extern NSString *const AppWillTerminateNotificationName;

@protocol STService <NSObject>

@required
+ (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController;

@end

@interface ShareThis : NSObject
@property (nonatomic, strong) NSString *pocketAPIKey;
@property (nonatomic, strong) NSString *readabilityKey;
@property (nonatomic, strong) NSString *readabilitySecret;

+ (ShareThis *)sharedManager;
+ (void)shareURL:(NSURL *)url title:(NSString *)title image:(UIImage *)image withService:(STServiceType)service onViewController:(UIViewController *)viewController;
+ (void)showShareOptionsToShareUrl:(NSURL *)url title:(NSString *)title image:(UIImage *)image onViewController:(UIViewController *)viewController;
+ (void)showShareOptionsToShareUrl:(NSURL *)url title:(NSString *)title image:(UIImage *)image onViewController:(UIViewController *)viewController forTypeOfContent:(STContentType)contentType;
+ (void)startSessionWithFacebookURLSchemeSuffix:(NSString *)suffix
                                      pocketAPI:(NSString *)pocketAPI
                                 readabilityKey:(NSString *)readabilityKey
                              readabilitySecret:(NSString *)readabilitySecret;
+ (BOOL)handleFacebookOpenUrl:(NSURL *)url;
+ (BOOL)isSocialAvailable;
@end
