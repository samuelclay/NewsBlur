//
//  MarkReadMenuViewController.m
//  NewsBlur
//
//  Created by David Sinclair on 2015-11-13.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "MarkReadMenuViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "FeedDetailViewController.h"
#import "StoriesCollection.h"
#import "MenuTableViewCell.h"

NSString * const MarkReadMenuTitle = @"title";
NSString * const MarkReadMenuIcon = @"icon";
NSString * const MarkReadMenuDays = @"days";
NSString * const MarkReadMenuOlderNewer = @"olderNewer";
NSString * const MarkReadMenuHandler = @"handler";

typedef NS_ENUM(NSUInteger, MarkReadMenuOlderNewerMode)
{
    MarkReadMenuOlderNewerModeOlder = -1,
    MarkReadMenuOlderNewerModeToggle = 0,
    MarkReadMenuOlderNewerModeNewer = 1
};


@interface MarkReadMenuViewController ()

@property (nonatomic, strong, readonly) NewsBlurAppDelegate *appDelegate;
@property (nonatomic, strong) NSMutableArray *menuOptions;
@property (nonatomic) BOOL marked;

@end

@implementation MarkReadMenuViewController

#define kMenuOptionHeight 38

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.menuTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.menuTableView.separatorColor = UIColorFromRGB(0x909090);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self buildMenuOptions];
    
    [self.menuTableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (self.completionHandler) {
        self.completionHandler(self.marked);
    }
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (CGSize)preferredContentSize {
    CGSize size = CGSizeMake(300.0, 190.0);
    
    if (self.olderNewerStoriesCollection) {
        size = CGSizeMake(300.0, 114.0);
    } else if (self.visibleUnreadCount) {
        size = CGSizeMake(300.0, 228.0);
    }
    
    size.height = size.height + (self.extraItems.count * 38.0);
    
    return size;
}

- (void)buildMenuOptions {
    self.marked = NO;
    self.menuOptions = [NSMutableArray array];
    
    if (self.olderNewerStoriesCollection) {
        [self.olderNewerStoriesCollection calculateStoryLocations];
        
        if ([self.olderNewerStoriesCollection isStoryUnread:self.olderNewerStory]) {
            [self addTitle:@"Mark as read" iconName:@"menu_icn_markread.png" olderNewerMode:MarkReadMenuOlderNewerModeToggle];
        } else {
            [self addTitle:@"Mark as unread" iconName:@"menu_icn_markread.png" olderNewerMode:MarkReadMenuOlderNewerModeToggle];
        }
        
        if ([self.olderNewerStoriesCollection.activeOrder isEqualToString:@"newest"]) {
            [self addTitle:@"Mark newer stories read" iconName:@"menu_icn_markread.png" olderNewerMode:MarkReadMenuOlderNewerModeNewer];
            [self addTitle:@"Mark older stories read" iconName:@"menu_icn_markread.png" olderNewerMode:MarkReadMenuOlderNewerModeOlder];
        } else {
            [self addTitle:@"Mark older stories read" iconName:@"menu_icn_markread.png" olderNewerMode:MarkReadMenuOlderNewerModeOlder];
            [self addTitle:@"Mark newer stories read" iconName:@"menu_icn_markread.png" olderNewerMode:MarkReadMenuOlderNewerModeNewer];
        }
    } else {
        [self addTitle:[NSString stringWithFormat:@"Mark %@ as read", self.collectionTitle] iconName:@"menu_icn_markread.png" days:0];
        
        if (self.visibleUnreadCount) {
            NSString *stories = self.visibleUnreadCount == 1 ? @"Mark this story as read" : [NSString stringWithFormat:@"Mark these %@ stories read", @(self.visibleUnreadCount)];
            
            [self addTitle:stories iconName:@"menu_icn_markread.png" days:-1];
        }
        
        // Might want different icons for each
        [self addTitle:@"Mark read older than 1 day" iconName:@"menu_icn_markread.png" days:1];
        [self addTitle:@"Mark read older than 3 days" iconName:@"menu_icn_markread.png" days:3];
        [self addTitle:@"Mark read older than 7 days" iconName:@"menu_icn_markread.png" days:7];
        [self addTitle:@"Mark read older than 14 days" iconName:@"menu_icn_markread.png" days:14];
    }
    
    for (NSDictionary *item in self.extraItems) {
        [self addTitle:item[MarkReadMenuTitle] iconName:item[MarkReadMenuIcon] handler:item[MarkReadMenuHandler]];
    }
}

- (void)addTitle:(NSString *)title iconName:(NSString *)iconName olderNewerMode:(MarkReadMenuOlderNewerMode)mode {
    [self.menuOptions addObject:@{MarkReadMenuTitle : title.uppercaseString, MarkReadMenuIcon : [UIImage imageNamed:iconName], MarkReadMenuOlderNewer : @(mode)}];
}

- (void)addTitle:(NSString *)title iconName:(NSString *)iconName days:(NSInteger)days {
    [self.menuOptions addObject:@{MarkReadMenuTitle : title.uppercaseString, MarkReadMenuIcon : [UIImage imageNamed:iconName], MarkReadMenuDays : @(days)}];
}

- (void)addTitle:(NSString *)title iconName:(NSString *)iconName handler:(void (^)(void))handler {
    [self.menuOptions addObject:@{MarkReadMenuTitle : title.uppercaseString, MarkReadMenuIcon : [UIImage imageNamed:iconName], MarkReadMenuHandler : handler}];
}

#pragma mark -
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.menuOptions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIndentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (cell == nil) {
        cell = [[MenuTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIndentifier];
    }
    
    NSDictionary *options = self.menuOptions[indexPath.row];
    
    cell.textLabel.text = options[MarkReadMenuTitle];
    cell.imageView.image = options[MarkReadMenuIcon];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kMenuOptionHeight;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= self.menuOptions.count) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    self.marked = YES;
    
    NSDictionary *options = self.menuOptions[indexPath.row];
    
    if (options[MarkReadMenuHandler]) {
        void (^handler)(void) = options[MarkReadMenuHandler];
        
        [self dismissViewControllerAnimated:YES completion:^{
            handler();
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }];
        
        return;
    }
    else if (self.olderNewerStoriesCollection) {
        MarkReadMenuOlderNewerMode mode = [options[MarkReadMenuOlderNewer] integerValue];
        
        if (mode == MarkReadMenuOlderNewerModeToggle) {
            [self.olderNewerStoriesCollection toggleStoryUnread];
        } else {
            NSInteger timestamp = [[self.olderNewerStory objectForKey:@"story_timestamp"] integerValue];
            BOOL older = mode == MarkReadMenuOlderNewerModeOlder;
            
            [self.appDelegate.feedDetailViewController markFeedsReadFromTimestamp:timestamp andOlder:older];
        }
    } else {
        NSInteger days = [options[MarkReadMenuDays] integerValue];
        
        if (days < 0) {
            [self.appDelegate.feedsViewController markVisibleStoriesRead];
        } else {
            [self.appDelegate.feedsViewController markFeedsRead:self.feedIds cutoffDays:days];
        }
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NewsBlurAppDelegate *)appDelegate {
    return [NewsBlurAppDelegate sharedAppDelegate];
}

@end
