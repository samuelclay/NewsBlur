//
//  FeedChooserItem.m
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-23.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "FeedChooserItem.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

@interface FeedChooserItem ()

@property (nonatomic, strong) UIImage *icon;
@property (nonatomic, readonly) NewsBlurAppDelegate *appDelegate;

@end

@implementation FeedChooserItem

+ (instancetype)makeFolderWithIdentifier:(NSString *)identifier title:(NSString *)title {
    return [self makeItemWithInfo:@{@"id" : identifier, @"feed_title" : title} search:nil];
}

+ (instancetype)makeItemWithInfo:(NSDictionary *)info search:(NSString *)search {
    FeedChooserItem *item = [self new];
    
    item.info = info;
    item.search = search;
    
    return item;
}

- (id)identifier {
    id identifier = self.info[@"id"];
    
    if ([identifier isEqual:@" "]) {
        identifier = @"everything";
    }
    
    if (self.info[@"tag"] != nil) {
        identifier = [NSString stringWithFormat:@"saved:%@", identifier];
    }
    
    if (self.search != nil) {
        identifier = [NSString stringWithFormat:@"%@?%@", identifier, self.search];
    }
    
    return identifier;
}

- (NSString *)identifierString {
    return [NSString stringWithFormat:@"%@", self.identifier];
}

- (NSString *)title {
    NSString *title = self.info[@"feed_title"];
    
    if (self.search != nil) {
        return [NSString stringWithFormat:@"\"%@\" in %@", self.search, title];
    }
    
    if ([title isEqualToString:@" "] || [title isEqualToString:@"dashboard"] || [title isEqualToString:@"everything"] || [title isEqualToString:@"infrequent"]) {
        return @"";
    } else {
        return title;
    }
}

- (UIImage *)icon {
    if (!_icon) {
        if (!self.identifier) {
            // Check for custom folder icon
            NSString *folderName = self.info[@"feed_title"];
            NSDictionary *customIcon = self.appDelegate.dictFolderIcons[folderName];
            if (customIcon && ![customIcon[@"icon_type"] isEqualToString:@"none"]) {
                self.icon = [CustomIconRenderer renderIcon:customIcon size:CGSizeMake(20, 20)];
            }
            if (!self.icon) {
                self.icon = [UIImage imageNamed:@"folder-open"];
            }
        } else {
            NSString *identifier = self.identifierString;
            BOOL isSocial = [self.appDelegate isSocialFeed:identifier];
            BOOL isSaved = [self.appDelegate isSavedFeed:identifier];
            self.icon = [self.appDelegate getFavicon:identifier isSocial:isSocial isSaved:isSaved];
        }
    }

    return _icon;
}

- (void)addItem:(FeedChooserItem *)item {
    if (!self.contents) {
        self.contents = [NSMutableArray array];
    }
    
    [self.contents addObject:item];
}

- (void)addItemWithInfo:(NSDictionary *)info search:(NSString *)search {
    [self addItem:[FeedChooserItem makeItemWithInfo:info search:search]];
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
    if (self.info[@"active"] == nil) {
        return @"";
    }
    
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
                
                componentsFormatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
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
