//
//  FeedDetailCollectionCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "NBSwipeableCell.h"

typedef NS_ENUM(NSUInteger, FeedDetailTextSize)
{
    FeedDetailTextSizeTitleOnly = 0,
    FeedDetailTextSizeShort,
    FeedDetailTextSizeMedium,
    FeedDetailTextSizeLong
};

@class FeedDetailSwipableCell, FeedDetailContentView;

@interface FeedDetailCollectionCell : UICollectionViewCell

@property (nonatomic) NewsBlurAppDelegate *appDelegate;

@property (nonatomic) NSString *siteTitle;
@property (nonatomic) UIImage *siteFavicon;

@property (readwrite) int storyScore;
@property (nonatomic, readwrite) BOOL isSaved;
@property (readwrite) BOOL isShared;

@property (nonatomic) NSString *storyTitle;
@property (nonatomic) NSString *storyAuthor;
@property (nonatomic) NSString *storyDate;
@property (nonatomic) NSString *storyContent;
@property (nonatomic) NSString *storyHash;
@property (nonatomic) UIImage *storyImage;
@property (nonatomic) NSInteger storyTimestamp;

@property (nonatomic) UIColor *feedColorBar;
@property (nonatomic) UIColor *feedColorBarTopBorder;

@property (readwrite) BOOL isRead;
@property (readwrite) BOOL isReadAvailable;
@property (readwrite) BOOL isShort;
@property (readwrite) BOOL isRiverOrSocial;
@property (readwrite) BOOL hasAlpha;

@property (nonatomic) FeedDetailTextSize textSize;

@property (nonatomic, strong) FeedDetailSwipableCell *swipableCell;
@property (nonatomic, strong) FeedDetailContentView *cellContent;

- (void)setupGestures;

@end

@interface FeedDetailSwipableCell : NBSwipeableCell

@end

@interface FeedDetailContentView : UIView

@property (nonatomic) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) FeedDetailCollectionCell *cell;
@property (nonatomic, strong) UIImage *storyImage;

@end
