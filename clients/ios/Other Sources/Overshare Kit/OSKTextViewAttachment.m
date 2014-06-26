//
//  OSKTextViewAttachment.m
//  Overshare
//
//  Created by Jared on 3/20/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import "OSKTextViewAttachment.h"

const CGFloat OSKTextViewAttachmentViewWidth_Phone = 78.0f; // 2 points larger than visual appearance, due to anti-aliasing technique
const CGFloat OSKTextViewAttachmentViewWidth_Pad = 96.0f; // 2 points larger than visual appearance, due to anti-aliasing technique

// OSKTextViewAttachment ============================================================

@interface OSKTextViewAttachment ()

@property (strong, nonatomic, readwrite) UIImage *thumbnail; // displayed cropped to 1:1, roughly square
@property (copy, nonatomic, readwrite) NSArray *images;

@end

@implementation OSKTextViewAttachment

+ (CGSize)sizeNeededForThumbs:(NSUInteger)count ofIndividualSize:(CGSize)individualThumbnailSize {
    CGSize sizeNeeded;
    
    if (count == 1) {
        sizeNeeded = individualThumbnailSize;
    } else {
        CGFloat oneDegreeInRadians = M_PI / 180.0f;
        CGFloat maxAngle = 12.0f * oneDegreeInRadians;
        CGFloat widestOffset = sinf(maxAngle) * individualThumbnailSize.height;
        sizeNeeded = CGSizeMake(individualThumbnailSize.width + widestOffset,
                                individualThumbnailSize.height + widestOffset);
    }
    return CGSizeMake(ceilf(sizeNeeded.width), ceilf(sizeNeeded.width));
}

- (instancetype)initWithImages:(NSArray *)images {
    self = [super init];
    if (self) {
        _images = images.copy;
        CGFloat width;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            width = OSKTextViewAttachmentViewWidth_Phone;
        } else {
            width = OSKTextViewAttachmentViewWidth_Pad;
        }
        __weak OSKTextViewAttachment *weakSelf = self;
        [self scaleImages:images toThumbmailsOfSize:CGSizeMake(width, width) completion:^(UIImage *thumbnail) {
            [weakSelf setThumbnail:thumbnail];
        }];
    }
    return self;
}

- (void)scaleImages:(NSArray *)images toThumbmailsOfSize:(CGSize)individualThumbnailSize completion:(void(^)(UIImage *thumbnail))completion {
    __weak OSKTextViewAttachment *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        CGSize sizeNeeded = [OSKTextViewAttachment sizeNeededForThumbs:images.count ofIndividualSize:individualThumbnailSize];
        
        UIGraphicsBeginImageContextWithOptions(sizeNeeded, NO, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        for (NSUInteger index = 0; index < images.count; index++) {
            UIImage *image = images.reverseObjectEnumerator.allObjects[index];
            
            CGContextSaveGState (context);
            
            CGFloat rotationAngle = [weakSelf attachmentRotationForPosition:index totalCount:images.count];
            CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(rotationAngle);
            CGContextConcatCTM(context, rotationTransform);
            
            if (rotationAngle != 0) {
                CGFloat offset = (sinf(rotationAngle) * sizeNeeded.width) / 2.0f;
                CGAffineTransform translation = CGAffineTransformMakeTranslation(offset, offset * -1.0f);
                CGContextConcatCTM(context, translation);
            }
            
            CGFloat nativeWidth = image.size.width;
            CGFloat nativeHeight = image.size.height;
            CGFloat targetWidth;
            CGFloat targetHeight;
            if (nativeHeight > nativeWidth) {
                targetWidth = individualThumbnailSize.width;
                targetHeight = (nativeHeight / nativeWidth) * targetWidth;
            } else {
                targetHeight = individualThumbnailSize.height;
                targetWidth = (nativeWidth / nativeHeight) * targetHeight;
            }
            CGFloat xOrigin = (sizeNeeded.width/2.0f) - (targetWidth/2.0f);
            CGFloat yOrigin = (sizeNeeded.height/2.0f) - (targetHeight/2.0f);
            CGRect rect = CGRectMake(xOrigin, yOrigin, targetWidth, targetHeight);
            
            CGRect clippingRect = CGRectMake(roundf(sizeNeeded.width - individualThumbnailSize.width)/2.0f,
                                             roundf(sizeNeeded.height - individualThumbnailSize.height)/2.0f,
                                             individualThumbnailSize.width,
                                             individualThumbnailSize.height);
            UIBezierPath *clippingPath  = [UIBezierPath bezierPathWithRect:clippingRect];
            [clippingPath addClip];
            [image drawInRect:rect];
            
            CGContextRestoreGState (context);
        }
        
        UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion){
                completion(thumbnail);
            }
        });
    });
}

- (CGFloat)attachmentRotationForPosition:(NSInteger)position totalCount:(NSInteger)count {
    CGFloat rotation;
    if (position > 2 || position == count-1) {
        rotation = 0;
    } else {
        CGFloat oneDegreeInRadians = M_PI / 180.0f;
        CGFloat degrees = (3.0f - position) * 4.0f;
        degrees = (position % 2 == 0) ? degrees : degrees*-1.0;
        rotation = degrees * oneDegreeInRadians;
    }
    return rotation;
}

@end


