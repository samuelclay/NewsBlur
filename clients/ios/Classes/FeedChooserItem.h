//
//  FeedChooserItem.h
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-23.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

@interface FeedChooserItem : NSObject

typedef NS_ENUM(NSUInteger, FeedChooserSort)
{
    FeedChooserSortName = 0,
    FeedChooserSortSubscribers,
    FeedChooserSortFrequency,
    FeedChooserSortRecency,
    FeedChooserSortOpens
};

@property (nonatomic, readonly) id identifier;
@property (nonatomic, readonly) NSString *identifierString;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) UIImage *icon;
@property (nonatomic, strong) NSDictionary *info;
@property (nonatomic, strong) NSMutableArray *contents;

+ (instancetype)makeFolderWithTitle:(NSString *)title;
+ (instancetype)makeItemWithInfo:(NSDictionary *)info;

- (void)addItemWithInfo:(NSDictionary *)info;

+ (NSString *)keyForSort:(FeedChooserSort)sort;
- (NSString *)detailForSort:(FeedChooserSort)sort;

@end
