//
//  FeedDetailMenuViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FeedDetailMenuViewController.h"
#import "NewsBlurAppDelegate.h"
#import "MBProgressHUD.h"
#import "NBContainerViewController.h"
#import "FeedDetailViewController.h"
#import "MenuTableViewCell.h"
#import "StoriesCollection.h"

@implementation FeedDetailMenuViewController

#define kMenuOptionHeight 38

@synthesize appDelegate;
@synthesize menuOptions;
@synthesize menuTableView;
@synthesize orderSegmentedControl;
@synthesize readFilterSegmentedControl;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.menuTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.menuTableView.separatorColor = UIColorFromRGB(0x909090);
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.menuOptions = nil;
    self.menuTableView = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.menuTableView reloadData];
    
    [orderSegmentedControl
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];
    [orderSegmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [orderSegmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    [orderSegmentedControl setSelectedSegmentIndex:0];
    if ([appDelegate.storiesCollection.activeOrder isEqualToString:@"oldest"]) {
        [orderSegmentedControl setSelectedSegmentIndex:1];
    }
    
    [readFilterSegmentedControl
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];
    [readFilterSegmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [readFilterSegmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    [readFilterSegmentedControl setSelectedSegmentIndex:0];
    if ([appDelegate.storiesCollection.activeReadFilter isEqualToString:@"unread"]) {
        [readFilterSegmentedControl setSelectedSegmentIndex:1];
    }
}

- (void)buildMenuOptions {
    BOOL everything = appDelegate.storiesCollection.isRiverView &&
                      [appDelegate.storiesCollection.activeFolder isEqualToString:@"everything"];
    BOOL read = appDelegate.storiesCollection.isReadView;
    BOOL saved = appDelegate.storiesCollection.isSavedView;

    NSMutableArray *options = [NSMutableArray array];
    
    //    NSString *title = appDelegate.storiesCollection.isRiverView ?
    //                        appDelegate.storiesCollection.activeFolder :
    //                        [appDelegate.storiesCollection.activeFeed objectForKey:@"feed_title"];
    
    if (!everything && !read && !saved) {
        NSString *deleteText = [NSString stringWithFormat:@"Delete %@",
                                appDelegate.storiesCollection.isRiverView ?
                                @"this entire folder" :
                                @"this site"];
        [options addObject:[deleteText uppercaseString]];
        [options addObject:[@"Move to another folder" uppercaseString]];
        if (appDelegate.storiesCollection.isRiverView) {
            [options addObject:[@"Rename this folder" uppercaseString]];
        }
    }
    
    if (!appDelegate.storiesCollection.isRiverView && !saved && !read) {
        [options addObject:[@"Rename this site" uppercaseString]];
        [options addObject:[@"Train this site" uppercaseString]];
        [options addObject:[@"Insta-fetch stories" uppercaseString]];
    }
    
    self.menuOptions = options;
}

#pragma mark -
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    [self buildMenuOptions];
    int filterOptions = 2;
    if (appDelegate.storiesCollection.isSocialRiverView ||
        appDelegate.storiesCollection.isSocialView ||
        appDelegate.storiesCollection.isSavedView ||
        appDelegate.storiesCollection.isReadView) {
        filterOptions = 1;
    }
    
    return [self.menuOptions count] + filterOptions;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIndentifier = @"Cell";
    
    if (indexPath.row == [self.menuOptions count]) {
        return [self makeOrderCell];
    } else if (indexPath.row == [self.menuOptions count] + 1) {
        return [self makeReadFilterCell];
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (cell == nil) {
        cell = [[MenuTableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:CellIndentifier];
    }
    
    cell.textLabel.text = [self.menuOptions objectAtIndex:[indexPath row]];

    if (indexPath.row == 0) {
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_delete.png"];
    } else if (indexPath.row == 1) {
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_move.png"];
    } else if (indexPath.row == 2) {
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_rename.png"];
    } else if (indexPath.row == 3) {
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_train.png"];
    } else if (indexPath.row == 4) {
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_fetch.png"];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kMenuOptionHeight;
}


- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [menuOptions count]) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        [appDelegate.feedDetailViewController confirmDeleteSite];
    } else if (indexPath.row == 1) {
        [appDelegate.feedDetailViewController openMoveView];
    } else if (indexPath.row == 2) {
        [appDelegate.feedDetailViewController openRenameSite];
    } else if (indexPath.row == 3) {
        [appDelegate.feedDetailViewController openTrainSite];
    } else if (indexPath.row == 4) {
        [appDelegate.feedDetailViewController instafetchFeed];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController hidePopover];
    } else {
        [appDelegate.feedDetailViewController.popoverController dismissPopoverAnimated:YES];
        appDelegate.feedDetailViewController.popoverController = nil;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}

- (UITableViewCell *)makeOrderCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    
    orderSegmentedControl.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2,
                                             kMenuOptionHeight - 7*2);
    [orderSegmentedControl setTitle:[@"Newest first" uppercaseString] forSegmentAtIndex:0];
    [orderSegmentedControl setTitle:[@"Oldest" uppercaseString] forSegmentAtIndex:1];
    
    [cell addSubview:orderSegmentedControl];
    
    return cell;
}

- (UITableViewCell *)makeReadFilterCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    
    readFilterSegmentedControl.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2,
                                                  kMenuOptionHeight - 7*2);
    [readFilterSegmentedControl setTitle:[@"All stories" uppercaseString] forSegmentAtIndex:0];
    [readFilterSegmentedControl setTitle:[@"Unread only" uppercaseString] forSegmentAtIndex:1];
    
    [cell addSubview:readFilterSegmentedControl];
    
    return cell;
}

- (IBAction)changeOrder:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];

    if ([sender selectedSegmentIndex] == 0) {
        [userPreferences setObject:@"newest" forKey:[appDelegate.storiesCollection orderKey]];
    } else {
        [userPreferences setObject:@"oldest" forKey:[appDelegate.storiesCollection orderKey]];
    }
    
    [userPreferences synchronize];
    
    [appDelegate.feedDetailViewController reloadStories];
}

- (IBAction)changeReadFilter:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([sender selectedSegmentIndex] == 0) {
        [userPreferences setObject:@"all" forKey:[appDelegate.storiesCollection readFilterKey]];
    } else {
        [userPreferences setObject:@"unread" forKey:[appDelegate.storiesCollection readFilterKey]];
    }
    
    [userPreferences synchronize];
    
    [appDelegate.feedDetailViewController reloadStories];
    
}

@end
