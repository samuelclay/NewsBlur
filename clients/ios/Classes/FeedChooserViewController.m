//
//  FeedChooserViewController.m
//  NewsBlur
//
//  Created by David Sinclair on 2016-01-22.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "FeedChooserViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NSObject+SBJSON.h"
#import "MenuViewController.h"
#import "FeedChooserTitleView.h"
#import "FeedChooserViewCell.h"
#import "FeedChooserItem.h"

static const CGFloat kTableViewRowHeight = 31.0;
static const CGFloat kFolderTitleHeight = 36.0;

@interface FeedChooserViewController () <FeedChooserTitleDelegate>

@property (nonatomic, strong) UIBarButtonItem *optionsItem;
@property (nonatomic, strong) UIBarButtonItem *moveItem;
@property (nonatomic, strong) UIBarButtonItem *deleteItem;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *indexTitles;
@property (nonatomic, strong) NSArray *folders;
@property (nonatomic, strong) NSDictionary *dictFolders;
@property (nonatomic, strong) NSDictionary *inactiveFeeds;
@property (nonatomic) FeedChooserSort sort;
@property (nonatomic) BOOL ascending;
@property (nonatomic) BOOL flat;
@property (nonatomic, strong) NSUserDefaults *groupDefaults;
@property (nonatomic, readonly) NSArray *widgetFeeds;

@end

@implementation FeedChooserViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (self.operation == FeedChooserOperationWidgetSites) {
        self.groupDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.newsblur.NewsBlur-Group"];
    }
    
    UIBarButtonItem *doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    self.optionsItem = [[UIBarButtonItem alloc] initWithImage:[Utilities imageNamed:@"settings" sized:30] style:UIBarButtonItemStylePlain target:self action:@selector(showOptionsMenu)];
    
    if (self.operation == FeedChooserOperationMuteSites) {
        UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
        
        self.navigationItem.leftBarButtonItem = cancelItem;
        self.navigationItem.rightBarButtonItems = @[doneItem, self.optionsItem];
        
        self.tableView.editing = NO;
    } else if (self.operation == FeedChooserOperationOrganizeSites) {
        self.moveItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"menu_icn_move.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showMoveMenu)];
        self.deleteItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"menu_icn_delete.png"] style:UIBarButtonItemStylePlain target:self action:@selector(deleteFeeds)];
        
        self.navigationItem.leftBarButtonItems = @[self.moveItem, self.deleteItem];
        self.navigationItem.rightBarButtonItems = @[doneItem, self.optionsItem];
        
        self.tableView.editing = YES;
    } else {
        self.navigationItem.leftBarButtonItems = nil;
        self.navigationItem.rightBarButtonItems = @[doneItem, self.optionsItem];
        
        self.tableView.editing = YES;
    }
    
    self.tableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.tableView.separatorColor = UIColorFromRGB(0xF0F0F0);
    self.tableView.sectionIndexColor = UIColorFromRGB(0x303030);
    self.tableView.sectionIndexBackgroundColor = UIColorFromRGB(0xDCDFD6);
    
    if (@available(iOS 15.0, *)) {
        self.tableView.sectionHeaderTopPadding = 0;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(finishedLoadingFeedsNotification:) name:@"FinishedLoadingFeedsNotification" object:nil];
    
    [self updateTitle];
    
    if (self.operation == FeedChooserOperationMuteSites) {
        [self performGetInactiveFeeds];
    } else if (self.operation == FeedChooserOperationOrganizeSites) {
        [self updateDictFolders];
        [self rebuildItemsAnimated:NO];
    } else {
        [self updateDictFolders];
        [self rebuildItemsAnimated:NO];
        [self updateSelectedWidgets];
    }
}

- (void)performGetInactiveFeeds {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Loading...";
    
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    NSMutableArray *feedsByFolder = [NSMutableArray arrayWithCapacity:selection.count];
    
    for (NSIndexPath *indexPath in selection) {
        FeedChooserItem *fromFolder = self.sections[indexPath.section];
        FeedChooserItem *item = fromFolder.contents[indexPath.row];
        
        [feedsByFolder addObject:@[item.identifier, fromFolder.identifier]];
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/feeds?flat=true&update_counts=false&include_inactive=true", self.appDelegate.url];
    [appDelegate GET:urlString parameters:nil target:self success:@selector(finishLoadingInactiveFeeds:) failure:@selector(finishedWithError:)];
}

- (void)finishLoadingInactiveFeeds:(NSDictionary *)results {
    self.dictFolders = results[@"flat_folders_with_inactive"];
    self.inactiveFeeds = results[@"inactive_feeds"];
    
    [self rebuildItemsAnimated:NO];
    
    [self enumerateAllRowsUsingBlock:^(NSIndexPath *indexPath, FeedChooserItem *item) {
        if (![item.info[@"active"] boolValue]) {
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }];
    
    [self updateControls];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)finishedWithError:(NSError *)error {
    NSLog(@"informError: %@", error);
    NSString *errorMessage = [error localizedDescription];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [HUD setCustomView:[[UIImageView alloc]
                        initWithImage:[UIImage imageNamed:@"warning.gif"]]];
    [HUD setMode:MBProgressHUDModeCustomView];
    HUD.labelText = errorMessage;
    [HUD hide:YES afterDelay:1];
    
    [self rebuildItemsAnimated:YES];
}

- (void)rebuildItemsAnimated:(BOOL)animated {
    FeedChooserItem *section = nil;
    
    NSMutableArray *sections = [NSMutableArray array];
    NSMutableArray *indexTitles = [NSMutableArray array];
    NSMutableArray *folders = [NSMutableArray array];
    
    if (self.flat) {
        section = [FeedChooserItem makeFolderWithTitle:@""];
        [sections addObject:section];
    }
    
    NSArray *folderArray = [self.dictFolders.allKeys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    
    for (NSString *folderName in folderArray) {
        if (![folderName hasPrefix:@"river_"] && ![folderName isEqualToString:@"read_stories"] && ![folderName isEqualToString:@"saved_searches"] && ![folderName isEqualToString:@"saved_stories"]) {
            FeedChooserItem *folder = [FeedChooserItem makeFolderWithTitle:folderName];
            [folders addObject:folder];
            
            if (!self.flat) {
                section = folder;
            }
            
            for (id feedId in self.dictFolders[folderName]) {
                NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
                feedIdStr = [appDelegate feedIdWithoutSearchQuery:feedIdStr];
                NSDictionary *info = appDelegate.dictFeeds[feedIdStr];
                
                if (!info) {
                    info = self.inactiveFeeds[feedIdStr];
                }
                
                BOOL wantFeed = ![appDelegate isSocialFeed:feedIdStr] && ![appDelegate isSavedFeed:feedIdStr];
                
                if (wantFeed && self.operation == FeedChooserOperationWidgetSites && ![info[@"active"] boolValue]) {
                    wantFeed = NO;
                }
                
                if (wantFeed) {
                    [section addItemWithInfo:info];
                }
            }
            
            if (!self.flat && section.contents.count) {
                [sections addObject:section];
                [indexTitles addObject:section.title.length ? [section.title substringToIndex:1] : @"-"];
            }
        }
    }
    
    self.sections = sections;
    self.indexTitles = indexTitles;
    self.folders = folders;
    
    [self.tableView reloadData];
    [self sortItemsAnimated:animated];
    [self updateControls];
}

- (void)sortItemsAnimated:(BOOL)animated {
    [self.tableView beginUpdates];
    
    NSString *key = [FeedChooserItem keyForSort:self.sort];
    
    [self enumerateSectionsUsingBlock:^(NSUInteger section, FeedChooserItem *folder) {
        NSArray *oldItems = [NSArray arrayWithArray:folder.contents];
        
        if (self.sort == FeedChooserSortName) {
            [folder.contents sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:key ascending:self.ascending selector:@selector(caseInsensitiveCompare:)], [NSSortDescriptor sortDescriptorWithKey:@"info.feed_title" ascending:self.ascending selector:@selector(caseInsensitiveCompare:)]]];
        } else {
            [folder.contents sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:key ascending:self.ascending], [NSSortDescriptor sortDescriptorWithKey:@"info.feed_title" ascending:self.ascending selector:@selector(caseInsensitiveCompare:)]]];
        }
        
        if (animated) {
            [self enumerateRowsInSection:section usingBlock:^(NSUInteger row, FeedChooserItem *item) {
                NSUInteger newRow = [folder.contents indexOfObject:oldItems[row]];
                
                [self.tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section] toIndexPath:[NSIndexPath indexPathForRow:newRow inSection:section]];
            }];
        }
    }];
    
    [self.tableView endUpdates];
    
    if (!animated) {
        [self.tableView reloadData];
    }
}

- (FeedChooserItem *)itemForIndexPath:(NSIndexPath *)indexPath {
    FeedChooserItem *folder = self.sections[indexPath.section];
    
    return folder.contents[indexPath.row];
}

- (NSIndexPath *)indexPathForItem:(FeedChooserItem *)item {
    __block NSIndexPath *indexPath = nil;
    
    [self enumerateAllRowsUsingBlock:^(NSIndexPath *localIndexPath, FeedChooserItem *localItem) {
        if ([item.identifierString isEqualToString:localItem.identifierString]) {
            indexPath = localIndexPath;
        }
    }];
    
    return indexPath;
}

- (NewsBlurAppDelegate *)appDelegate {
    return [NewsBlurAppDelegate sharedAppDelegate];
}

- (void)enumerateSectionsUsingBlock:(void (^)(NSUInteger section, FeedChooserItem *folder))block {
    if (!block) {
        return;
    }
    
    for (NSUInteger section = 0; section < self.sections.count; section++) {
        FeedChooserItem *folder = self.sections[section];
        
        block(section, folder);
    }
}

- (void)enumerateRowsInSection:(NSUInteger)section usingBlock:(void (^)(NSUInteger row, FeedChooserItem *item))block {
    if (!block) {
        return;
    }
    
    FeedChooserItem *folder = self.sections[section];
    
    for (NSUInteger row = 0; row < folder.contents.count; row++) {
        FeedChooserItem *item = folder.contents[row];
        
        block(row, item);
    }
}

- (void)enumerateAllRowsUsingBlock:(void (^)(NSIndexPath *indexPath, FeedChooserItem *item))block {
    if (!block) {
        return;
    }
    
    [self enumerateSectionsUsingBlock:^(NSUInteger section, FeedChooserItem *folder) {
        [self enumerateRowsInSection:section usingBlock:^(NSUInteger row, FeedChooserItem *item) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
            
            block(indexPath, item);
        }];
    }];
}

- (BOOL)isSelectionInSection:(NSUInteger)section {
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    
    for (NSIndexPath *indexPath in selection) {
        if (indexPath.section == section) {
            return YES;
        }
    }
    
    return NO;
}

- (NSArray *)selectedItemIdentifiers {
    NSMutableArray *identifiers = [NSMutableArray array];
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    
    for (NSIndexPath *indexPath in selection) {
        [identifiers addObject:[self itemForIndexPath:indexPath].identifier];
    }
    
    return identifiers;
}

- (void)selectItemsWithIdentifiers:(NSArray *)itemIdentifiers animated:(BOOL)animated {
    [self enumerateAllRowsUsingBlock:^(NSIndexPath *indexPath, FeedChooserItem *item) {
        if ([itemIdentifiers containsObject:item.identifier]) {
            [self.tableView selectRowAtIndexPath:indexPath animated:animated scrollPosition:UITableViewScrollPositionNone];
        } else {
            [self.tableView deselectRowAtIndexPath:indexPath animated:animated];
        }
    }];
    
    [self updateControls];
}

- (void)deselectRowsOutsideSection:(NSUInteger)section {
    [self enumerateSectionsUsingBlock:^(NSUInteger thisSection, FeedChooserItem *folder) {
        if (thisSection != section) {
            [self select:NO section:thisSection isSelectAll:NO];
        }
    }];
}

- (void)select:(BOOL)select section:(NSUInteger)section isSelectAll:(BOOL)isSelectAll {
    if (select && !isSelectAll && self.operation == FeedChooserOperationWidgetSites) {
        [self deselectRowsOutsideSection:section];
    }
    
    [self enumerateRowsInSection:section usingBlock:^(NSUInteger row, FeedChooserItem *item) {
        if (select) {
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section] animated:YES scrollPosition:UITableViewScrollPositionNone];
        } else {
            [self.tableView deselectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section] animated:YES];
        }
        
        if (self.operation == FeedChooserOperationWidgetSites) {
            [self setWidgetIncludes:select item:item];
        }
    }];
    
    [self updateControls];
}

- (void)updateTitle {
    if (self.operation == FeedChooserOperationMuteSites) {
        NSUInteger count = self.tableView.indexPathsForSelectedRows.count;
        
        if (count == 0) {
            self.navigationItem.title = @"Mute Sites";
        } else if (count == 1) {
            self.navigationItem.title = @"Mute 1 Site";
        } else {
            self.navigationItem.title = [NSString stringWithFormat:@"Mute %@ Sites", @(count)];
        }
    } else if (self.operation == FeedChooserOperationOrganizeSites) {
        self.navigationItem.title = @"Organize Sites";
    } else {
        NSUInteger count = self.tableView.indexPathsForSelectedRows.count;
        
        if (count == 0) {
            self.navigationItem.title = @"No Widget Sites";
        } else if (count == 1) {
            self.navigationItem.title = @"1 Widget Site";
        } else {
            self.navigationItem.title = [NSString stringWithFormat:@"%@ Widget Sites", @(count)];
        }
    }
}

- (void)updateControls {
    BOOL hasSelection = self.tableView.indexPathsForSelectedRows.count > 0;
    
    self.moveItem.enabled = hasSelection;
    self.deleteItem.enabled = hasSelection;
    
    [self updateTitle];
}

- (NSArray *)widgetFeeds {
    NSMutableArray *feeds = [self.groupDefaults objectForKey:@"widget:feeds_array"];
    
    if (feeds == nil) {
        feeds = [NSMutableArray array];
        
        [self enumerateAllRowsUsingBlock:^(NSIndexPath *indexPath, FeedChooserItem *item) {
            [feeds addObject:[self widgetFeedForItem:item]];
        }];
        
        [self.groupDefaults setObject:feeds forKey:@"widget:feeds_array"];
    }
    
    return feeds;
}

- (NSDictionary *)widgetFeedForItem:(FeedChooserItem *)item {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"id"] = item.identifierString;
    dict[@"feed_title"] = item.title;
    
    if (item.info[@"favicon_fade"] != [NSNull null]) {
        dict[@"favicon_fade"] = item.info[@"favicon_fade"];
    }
    
    if (item.info[@"favicon_color"] != [NSNull null]) {
        dict[@"favicon_color"] = item.info[@"favicon_color"];
    }
    
    return dict;
}

- (NSInteger)widgetIndexOfFeed:(NSString *)feedId {
    return [self.widgetFeeds indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        return [obj[@"id"] isEqualToString:feedId];
    }];
}

- (void)setWidgetIncludes:(BOOL)include item:(FeedChooserItem *)item {
    NSMutableArray *feeds = [self.widgetFeeds mutableCopy];
    NSInteger feedIndex = [self widgetIndexOfFeed:item.identifierString];
    
    if (include) {
        if (feedIndex == NSNotFound) {
            [feeds addObject:[self widgetFeedForItem:item]];
        }
    } else {
        if (feedIndex != NSNotFound) {
            [feeds removeObjectAtIndex:feedIndex];
        }
    }
    
    [self.groupDefaults setObject:feeds forKey:@"widget:feeds_array"];
}

- (void)setWidgetIncludes:(BOOL)include itemForIndexPath:(NSIndexPath *)indexPath {
    [self setWidgetIncludes:include item:[self itemForIndexPath:indexPath]];
}

#pragma mark - Title delegate methods

- (void)didSelectTitleView:(UIButton *)sender {
    NSUInteger section = sender.tag;
    BOOL select = ![self isSelectionInSection:section];
    
    [self enumerateRowsInSection:section usingBlock:^(NSUInteger row, FeedChooserItem *item) {
        [self select:select section:section isSelectAll:NO];
    }];
    
    if (self.operation == FeedChooserOperationWidgetSites) {
        FeedChooserItem *folderItem = self.sections[section];
        
        [self.groupDefaults setObject:folderItem.identifierString forKey:@"widget:show_folder"];
    }
}

#pragma mark - Target/action methods

- (NSString *)sortIconName {
    if (self.ascending) {
        return @"barbutton_sort_asc.png";
    } else {
        return @"barbutton_sort_desc.png";
    }
}

- (void)sort:(FeedChooserSort)sort {
    NSArray *identifiers = [self selectedItemIdentifiers];
    
    // Rebuild to get the new info values (which also quietly sorts in the old order), then sort with animation:
    [self rebuildItemsAnimated:NO];
    self.sort = sort;
    [self sortItemsAnimated:YES];
    
    [self selectItemsWithIdentifiers:identifiers animated:NO];
}

- (void)showOptionsMenu {
    MenuViewController *viewController = [MenuViewController new];
    BOOL isMute = self.operation == FeedChooserOperationMuteSites;
    
    [viewController addTitle:@"Name" iconTemplateName:[self sortIconName] selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortName];
    }];
    
    [viewController addTitle:@"Subscribers" iconTemplateName:[self sortIconName] selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortSubscribers];
    }];
    
    [viewController addTitle:@"Stories per Month" iconTemplateName:[self sortIconName] selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortFrequency];
    }];
    
    [viewController addTitle:@"Most Recent Story" iconTemplateName:[self sortIconName] selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortRecency];
    }];
    
    [viewController addTitle:@"Number of Opens" iconTemplateName:[self sortIconName] selectionShouldDismiss:YES handler:^{
        [self sort:FeedChooserSortOpens];
    }];
    
    viewController.checkedRow = self.sort;
    
    [viewController addSegmentedControlWithTitles:@[@"Ascending", @"Descending"] selectIndex:self.ascending ? 0 : 1 selectionShouldDismiss:YES handler:^(NSUInteger selectedIndex) {
        NSArray *identifiers = [self selectedItemIdentifiers];
        self.ascending = selectedIndex == 0;
        [self sortItemsAnimated:YES];
        [self selectItemsWithIdentifiers:identifiers animated:NO];
    }];
    
    [viewController addSegmentedControlWithTitles:@[@"Nested", @"Flat"] selectIndex:self.flat ? 1 : 0 selectionShouldDismiss:YES handler:^(NSUInteger selectedIndex) {
        NSArray *identifiers = [self selectedItemIdentifiers];
        self.flat = selectedIndex == 1;
        [self rebuildItemsAnimated:YES];
        [self selectItemsWithIdentifiers:identifiers animated:NO];
    }];
    
    MenuItemHandler selectAllHandler = ^{
        [self enumerateSectionsUsingBlock:^(NSUInteger section, FeedChooserItem *folder) {
            [self select:YES section:section isSelectAll:YES];
        }];
        
        if (self.operation == FeedChooserOperationWidgetSites) {
            [self.groupDefaults setObject:@"everything" forKey:@"widget:show_folder"];
        }
    }, selectNoneHandler = ^{
        [self enumerateSectionsUsingBlock:^(NSUInteger section, FeedChooserItem *folder) {
            [self select:NO section:section isSelectAll:NO];
        }];
        
        if (self.operation == FeedChooserOperationWidgetSites) {
            [self.groupDefaults setObject:@"everything" forKey:@"widget:show_folder"];
        }
    };
    
    if (isMute) {
        [viewController addTitle:@"Mute All" iconName:@"mute_feed_off.png" selectionShouldDismiss:YES handler:selectAllHandler];
        [viewController addTitle:@"Unmute All" iconName:@"mute_feed_on.png" selectionShouldDismiss:YES handler:selectNoneHandler];
    } else {
        [viewController addTitle:@"Select All" iconTemplateName:@"barbutton_selection.png" selectionShouldDismiss:YES handler:selectAllHandler];
        [viewController addTitle:@"Select None" iconTemplateName:@"barbutton_selection_off.png" selectionShouldDismiss:YES handler:selectNoneHandler];
    }

    [viewController showFromNavigationController:self.navigationController barButtonItem:self.optionsItem];
}

- (void)performMoveToFolder:(FeedChooserItem *)toFolder {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Moving...";
    
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    NSMutableArray *feedsByFolder = [NSMutableArray arrayWithCapacity:selection.count];
    
    for (NSIndexPath *indexPath in selection) {
        FeedChooserItem *fromFolder = self.sections[indexPath.section];
        FeedChooserItem *item = fromFolder.contents[indexPath.row];
        
        [feedsByFolder addObject:@[item.identifier, fromFolder.identifier]];
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/move_feeds_by_folder_to_folder", self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:feedsByFolder.JSONRepresentation forKey:@"feeds_by_folder"];
    [params setObject:toFolder.identifier forKey:@"to_folder"];
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        HUD.labelText = @"Reloading...";
        [self.appDelegate reloadFeedsView:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self finishedWithError:error];
    }];
    
}

- (void)showMoveMenu {
    MenuViewController *viewController = [MenuViewController new];
    
    for (FeedChooserItem *folder in self.folders) {
        NSString *title = folder.title;
        NSString *iconName = @"menu_icn_move.png";
        
        if (!title.length) {
            title = @"Top Level";
            iconName = @"menu_icn_all.png";
        } else {
            NSArray *components = [title componentsSeparatedByString:@" ▸ "];
            title = components.lastObject;
            for (NSUInteger idx = 0; idx < components.count; idx++) {
                title = [@"\t" stringByAppendingString:title];
            }
        }
        
        [viewController addTitle:title iconName:iconName selectionShouldDismiss:YES handler:^{
            [self performMoveToFolder:folder];
        }];
    }
    
    [viewController showFromNavigationController:self.navigationController barButtonItem:self.moveItem];
}

- (void)performDeleteFeeds {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting...";
    
    NSArray *selection = self.tableView.indexPathsForSelectedRows;
    NSMutableArray *feedsByFolder = [NSMutableArray arrayWithCapacity:selection.count];
    
    for (NSIndexPath *indexPath in selection) {
        FeedChooserItem *fromFolder = self.sections[indexPath.section];
        FeedChooserItem *item = fromFolder.contents[indexPath.row];
        
        [feedsByFolder addObject:@[item.identifier, fromFolder.identifier]];
    }
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/delete_feeds_by_folder", self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:feedsByFolder.JSONRepresentation forKey:@"feeds_by_folder"];
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        HUD.labelText = @"Reloading...";
        [self.appDelegate reloadFeedsView:YES];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self finishedWithError:error];
    }];
}

- (void)deleteFeeds {
    MenuViewController *viewController = [MenuViewController new];
    NSUInteger count = self.tableView.indexPathsForSelectedRows.count;
    NSString *title = count == 1 ? @"Delete selected site?" : [NSString stringWithFormat:@"Delete %@ sites?", @(count)];
    
    [viewController addTitle:title iconName:@"menu_icn_delete.png" destructive:YES selectionShouldDismiss:YES handler:^{
        [self performDeleteFeeds];
    }];
    
    [viewController showFromNavigationController:self.navigationController barButtonItem:self.deleteItem];
}

- (void)finishedLoadingFeedsNotification:(NSNotification *)note {
    if (self.operation != FeedChooserOperationMuteSites) {
        [self updateDictFolders];
    }
    
    [self rebuildItemsAnimated:YES];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (void)updateDictFolders {
    NSMutableDictionary *folders = [self.appDelegate.dictFolders mutableCopy];
    if ([folders objectForKey:@"everything"]) {
        NSDictionary *everything = folders[@"everything"];
    
        [folders removeObjectForKey:@"everything"];
        [folders setObject:everything forKey:@" "];
    }
    
    self.dictFolders = folders;
}

- (void)updateSelectedWidgets {
    NSMutableArray *identifiers = [NSMutableArray array];
    
    [self enumerateAllRowsUsingBlock:^(NSIndexPath *indexPath, FeedChooserItem *item) {
        if ([self widgetIndexOfFeed:item.identifierString] != NSNotFound) {
            [identifiers addObject:item.identifier];
        }
    }];
    
    [self selectItemsWithIdentifiers:identifiers animated:NO];
}

- (void)performSaveActiveFeeds {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Updating...";
    
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/save_feed_chooser", self.appDelegate.url];
    NSArray *mutedIndexPaths = self.tableView.indexPathsForSelectedRows;
    NSMutableArray *feeds = [NSMutableArray array];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    [self enumerateAllRowsUsingBlock:^(NSIndexPath *indexPath, FeedChooserItem *item) {
        if (![mutedIndexPaths containsObject:indexPath]) {
            [feeds addObject:item.identifier];
        }
    }];
    
    [params setObject:feeds forKey:@"approved_feeds"];
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self.appDelegate reloadFeedsView:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self finishedWithError:error];
    }];
}

- (BOOL)didChangeActiveFeeds {
    __block BOOL didChange = NO;
    NSArray *inactiveFeedsIdentifiers = self.inactiveFeeds.allKeys;
    NSArray *selectedIndexPaths = self.tableView.indexPathsForSelectedRows;
    
    [self enumerateAllRowsUsingBlock:^(NSIndexPath *indexPath, FeedChooserItem *item) {
        BOOL wasInactive = [inactiveFeedsIdentifiers containsObject:item.identifierString];
        BOOL isInactive = [selectedIndexPaths containsObject:indexPath];
        
        if (wasInactive != isInactive) {
            didChange = YES;
        }
    }];
    
    return didChange;
}

- (void)done {
    if (self.operation == FeedChooserOperationMuteSites && [self didChangeActiveFeeds]) {
        [self performSaveActiveFeeds];
    } else {
        if (self.operation == FeedChooserOperationWidgetSites) {
            [self.appDelegate.storyPagesViewController reloadWidget];
        }
        
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.appDelegate.hasNoSites) {
        return 0;
    } else {
        return self.sections.count;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    FeedChooserItem *item = self.sections[section];
    return item.title;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    FeedChooserItem *item = self.sections[section];
    NSArray *contents = item.contents;
    return contents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIndentifier = @"FeedChooserCell";
    FeedChooserViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (!cell) {
        cell = [[FeedChooserViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIndentifier];
    }
    
    FeedChooserItem *item = [self itemForIndexPath:indexPath];
    
    cell.isMuteOperation = self.operation == FeedChooserOperationMuteSites;
    cell.textLabel.text = item.title;
    cell.detailTextLabel.text = [item detailForSort:self.sort];
    cell.isFaded = [[cell.detailTextLabel.text substringToIndex:2] isEqualToString:@"0 "];
    cell.imageView.image = item.icon;
    
    if (self.operation == FeedChooserOperationMuteSites) {
        UIImage *image = [UIImage imageNamed:@"mute_feed_on.png"];
        UIImage *highlightedImage = [UIImage imageNamed:@"mute_feed_off.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image highlightedImage:highlightedImage];
        imageView.highlighted = [tableView.indexPathsForSelectedRows containsObject:indexPath];
        cell.accessoryView = imageView;
    } else {
        cell.accessoryView = nil;
    }
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    CGRect rect = CGRectMake(0.0, 0.0, tableView.frame.size.width, kFolderTitleHeight);
    FeedChooserTitleView *titleView = [[FeedChooserTitleView alloc] initWithFrame:rect];
    FeedChooserItem *item = self.sections[section];
    
    titleView.delegate = self;
    titleView.section = section;
    titleView.title = item.title;
    
    return titleView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    FeedChooserItem *item = self.sections[section];
    
    return !item.title.length ? 0.0 : kFolderTitleHeight;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kTableViewRowHeight;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)theTableView {
    return self.indexTitles;
}

- (NSInteger)tableView:(UITableView *)theTableView sectionForSectionIndexTitle:(NSString *)indexTitle atIndex:(NSInteger)indexIndex {
    return indexIndex;
}

#if TARGET_OS_MACCATALYST
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSIndexPath *> *selectedRows = [tableView indexPathsForSelectedRows];
    if ([selectedRows containsObject:indexPath]) {
        [tableView deselectRowAtIndexPath:indexPath animated:false];
        return nil;
    }
    
    return indexPath;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSIndexPath *> *selectedRows = [tableView indexPathsForSelectedRows];
    if ([selectedRows containsObject:indexPath]) {
        return nil;
    }
    
    return indexPath;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSIndexPath *> *selectedRows = [tableView indexPathsForSelectedRows];
    for (NSIndexPath *index in selectedRows) {
        [[tableView cellForRowAtIndexPath:index] setHighlighted:YES];
    }
    
    return YES;
}
#endif

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.operation == FeedChooserOperationWidgetSites) {
        [self deselectRowsOutsideSection:indexPath.section];
        [self setWidgetIncludes:YES itemForIndexPath:indexPath];
        
        FeedChooserItem *folderItem = self.sections[indexPath.section];
        
        [self.groupDefaults setObject:folderItem.identifierString forKey:@"widget:show_folder"];
    }
    
    UIImageView *imageView = (UIImageView *)[tableView cellForRowAtIndexPath:indexPath].accessoryView;
    
    imageView.highlighted = YES;
    
    [self updateControls];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.operation == FeedChooserOperationWidgetSites) {
        [self setWidgetIncludes:NO itemForIndexPath:indexPath];
    }
    
    UIImageView *imageView = (UIImageView *)[tableView cellForRowAtIndexPath:indexPath].accessoryView;
    
    imageView.highlighted = NO;
    
    [self updateControls];
}

@end
