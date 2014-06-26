//
//  OSKSaveToCameraRollActivity.m
//  Pods
//
//  Created by Konstadinos Karayannis on 22/2/14.
//
//

#import "OSKSaveToCameraRollActivity.h"
#import "OSKShareableContentItem.h"

@interface OSKSaveToCameraRollActivity ()

@property (strong, nonatomic, readonly) OSKPhotoSharingContentItem *photoSharingItem;

@end

@implementation OSKSaveToCameraRollActivity

- (instancetype)initWithContentItem:(OSKShareableContentItem *)item {
    self = [super initWithContentItem:item];
    if (self) {
        //
    }
    return self;
}

#pragma mark - Methods for OSKActivity Subclasses

+ (NSString *)supportedContentItemType {
    return OSKShareableContentItemType_PhotoSharing;
}

+ (BOOL)isAvailable {
    return YES;
}

+ (NSString *)activityType {
    return OSKActivityType_iOS_SaveToCameraRoll;
}

+ (NSString *)activityName {
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]){
        return @"Camera Roll";
    }
    else{
        return @"Saved Photos";
    }
}

+ (UIImage *)iconForIdiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if (idiom == UIUserInterfaceIdiomPhone) {
        image = [UIImage imageNamed:@"osk-photosIcon-60.png"];
    } else {
        image = [UIImage imageNamed:@"osk-photosIcon-76.png"];
    }
    return image;
}


+ (OSKAuthenticationMethod)authenticationMethod {
    return OSKAuthenticationMethod_None;
}

+ (BOOL)requiresApplicationCredential {
    return NO;
}

+ (OSKPublishingMethod)publishingMethod {
    return OSKPublishingMethod_None;
}

- (BOOL)isReadyToPerform {
    return (self.photoSharingItem.images ? YES : NO);
}

- (void)performActivity:(OSKActivityCompletionHandler)completion {
    for (UIImage* image in self.photoSharingItem.images){
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }
    if (completion) {
        __weak OSKSaveToCameraRollActivity *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(weakSelf, YES, nil);
        });
    }
}

+ (BOOL)canPerformViaOperation {
    return NO;
}

- (OSKActivityOperation *)operationForActivityWithCompletion:(OSKActivityCompletionHandler)completion {
    return nil;
}

#pragma mark - Convenience

- (OSKPhotoSharingContentItem *)photoSharingItem {
    return (OSKPhotoSharingContentItem *)self.contentItem;
}

@end