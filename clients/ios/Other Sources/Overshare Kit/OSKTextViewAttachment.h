//
//  OSKTextViewAttachment.h
//  Overshare
//
//  Created by Jared on 3/20/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const CGFloat OSKTextViewAttachmentViewWidth_Phone;
extern const CGFloat OSKTextViewAttachmentViewWidth_Pad;

/// ------------------------------------------------------------
/// OSKTextViewAttachment
/// ------------------------------------------------------------

@interface OSKTextViewAttachment : NSObject

/**
 Derived from the `images` array passed in the init method. Will
 be a 1x1 ratio square image, but may contain non-opaque areas.
 */
@property (strong, nonatomic, readonly) UIImage *thumbnail;

/**
 The images passed as the `images` argument to the init method.
 */
@property (copy, nonatomic, readonly) NSArray *images;

/**
 Returns the expected size the image that would be produced for `count` images of a given cropped size.
 */
+ (CGSize)sizeNeededForThumbs:(NSUInteger)count ofIndividualSize:(CGSize)individualThumbnailSize;

/**
 Returns an attachment object that can be used to display an attachment view.
 */
- (instancetype)initWithImages:(NSArray *)images;

@end
