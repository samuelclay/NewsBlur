//
//  FeedChooserItem.m
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-23.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "FeedChooserItem.h"
#import "NewsBlurAppDelegate.h"

@interface FeedChooserItem ()

@property (nonatomic, strong) UIImage *icon;
@property (nonatomic, readonly) NewsBlurAppDelegate *appDelegate;

@end

@implementation FeedChooserItem

+ (instancetype)makeFolderWithTitle:(NSString *)title {
    return [self makeItemWithInfo:@{@"id" : [[NewsBlurAppDelegate sharedAppDelegate] extractFolderName:title], @"feed_title" : title}];
}

+ (instancetype)makeItemWithInfo:(NSDictionary *)info {
    FeedChooserItem *item = [self new];
    
    item.info = info;
    
    return item;
}

- (id)identifier {
    id identifier = self.info[@"id"];
    
    if ([identifier isEqual:@" "]) {
        return @"everything";
    } else {
        return identifier;
    }
}

- (NSString *)identifierString {
    return [NSString stringWithFormat:@"%@", self.identifier];
}

- (NSString *)title {
    NSString *title = self.info[@"feed_title"];
    
    if ([title isEqualToString:@" "] || [title isEqualToString:@"everything"]) {
        return @"";
    } else {
        return title;
    }
}

- (UIImage *)icon {
    if (!_icon) {
        if (!self.identifier) {
            self.icon = [UIImage imageNamed:@"g_icn_folder.png"];
        } else {
            self.icon = [self.appDelegate getFavicon:[self.identifier description] isSocial:NO isSaved:NO];
        }
    }
    
    return _icon;
}

- (void)addItemWithInfo:(NSDictionary *)info {
    if (!self.contents) {
        self.contents = [NSMutableArray array];
    }
    
    [self.contents addObject:[FeedChooserItem makeItemWithInfo:info]];
}

+ (NSString *)keyForSort:(FeedChooserSort)sort {
    switch (sort) {
        case FeedChooserSortName:
            return @"info.feed_title";
            break;
            
        case FeedChooserSortSubscribers:
            return @"info.num_subscribers";
            break;
            
        case FeedChooserSortFrequency:
            return @"info.average_stories_per_month";
            break;
            
        case FeedChooserSortRecency:
            return @"info.last_story_seconds_ago";
            break;
            
        default:
            return @"info.feed_opens";
            break;
    }
}

- (NSString *)detailForSort:(FeedChooserSort)sort {
    switch (sort) {
        case FeedChooserSortSubscribers:
            return [NSString localizedStringWithFormat:NSLocalizedString(@"%@ subscribers", @"number of subscribers"), self.info[@"num_subscribers"]];
            break;
            
        case FeedChooserSortFrequency:
            return [NSString localizedStringWithFormat:NSLocalizedString(@"%@ stories/month", @"average stories per month"), self.info[@"average_stories_per_month"]];
            break;
            
        case FeedChooserSortRecency:
        {
            static NSDateFormatter *dateFormatter = nil;
            static NSDateComponentsFormatter *componentsFormatter = nil;
            
            if (!dateFormatter) {
                dateFormatter = [NSDateFormatter new];
                dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
            }
            
            if (!componentsFormatter)
            {
                componentsFormatter = [NSDateComponentsFormatter new];
                
                componentsFormatter.unitsStyle = NSDateFormatterLongStyle;
                componentsFormatter.maximumUnitCount = 1;
                componentsFormatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
            }
            
            NSDate *date = [dateFormatter dateFromString:self.info[@"last_story_date"]];
            
            return [NSString stringWithFormat:@"%@ ago",  [componentsFormatter stringFromTimeInterval:-date.timeIntervalSinceNow]];
            break;
        }
        
        default:
            return [NSString localizedStringWithFormat:NSLocalizedString(@"%@ opens", @"number of feed opens"), self.info[@"feed_opens"]];
            break;
    }
}

- (NSString *)description {
    if (self.contents) {
        return [NSString stringWithFormat:@"%@ %@ (contains %@ items)", [super description], self.title, @(self.contents.count)];
    } else {
        return [NSString stringWithFormat:@"%@ %@ (%@)", [super description], self.title, self.identifier];
    }
}

- (NewsBlurAppDelegate *)appDelegate {
    return [NewsBlurAppDelegate sharedAppDelegate];
}

@end
