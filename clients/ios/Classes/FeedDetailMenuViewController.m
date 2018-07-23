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
@synthesize infrequentSegmentedControl;

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

    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    [self.fontSizeSegment
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];
    if([userPreferences stringForKey:@"feed_list_font_size"]){
        NSString *fontSize = [userPreferences stringForKey:@"feed_list_font_size"];
        if ([fontSize isEqualToString:@"xs"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:0];
        } else if ([fontSize isEqualToString:@"small"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:1];
        } else if ([fontSize isEqualToString:@"medium"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:2];
        } else if ([fontSize isEqualToString:@"large"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:3];
        } else if ([fontSize isEqualToString:@"xl"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:4];
        }
    }

    [self.infrequentSegmentedControl
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];
    if([userPreferences stringForKey:@"infrequent_stories_per_month"]){
        NSInteger storiesPerMonth = [userPreferences integerForKey:@"infrequent_stories_per_month"];
        if (storiesPerMonth == 5) {
            [self.infrequentSegmentedControl setSelectedSegmentIndex:0];
        } else if (storiesPerMonth == 15) {
            [self.infrequentSegmentedControl setSelectedSegmentIndex:1];
        } else if (storiesPerMonth == 30) {
            [self.infrequentSegmentedControl setSelectedSegmentIndex:2];
        } else if (storiesPerMonth == 60) {
            [self.infrequentSegmentedControl setSelectedSegmentIndex:3];
        } else if (storiesPerMonth == 90) {
            [self.infrequentSegmentedControl setSelectedSegmentIndex:4];
        }
    }
    
    NSString *theme = [ThemeManager themeManager].theme;
    if ([theme isEqualToString:@"sepia"]) {
        self.themeSegmentedControl.selectedSegmentIndex = 1;
    } else if ([theme isEqualToString:@"medium"]) {
        self.themeSegmentedControl.selectedSegmentIndex = 2;
    } else if ([theme isEqualToString:@"dark"]) {
        self.themeSegmentedControl.selectedSegmentIndex = 3;
    } else {
        self.themeSegmentedControl.selectedSegmentIndex = 0;
    }
    
    if ([self isInfrequent]) {
        self.infrequentSegmentedControl.hidden = NO;
    } else {
        self.infrequentSegmentedControl.hidden = YES;
    }
    
    NSInteger menuCount = self.menuOptions.count + ([self isRiver] ? 3 : 4) + ([self isInfrequent] ? 1 : 0);
    self.navigationController.preferredContentSize = CGSizeMake(260, 38 * menuCount);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSInteger menuCount = self.menuOptions.count + ([self isRiver] ? 3 : 4) + ([self isInfrequent] ? 1 : 0);
    self.navigationController.preferredContentSize = CGSizeMake(260, 38 * menuCount);
    self.menuTableView.scrollEnabled = self.navigationController.preferredContentSize.height > self.view.frame.size.height;
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)buildMenuOptions {
    BOOL everything = appDelegate.storiesCollection.isRiverView &&
                      [appDelegate.storiesCollection.activeFolder isEqualToString:@"everything"];
    BOOL infrequent = [self isInfrequent];
    BOOL read = appDelegate.storiesCollection.isReadView;
    BOOL saved = appDelegate.storiesCollection.isSavedView;

    NSMutableArray *options = [NSMutableArray array];
    
    //    NSString *title = appDelegate.storiesCollection.isRiverView ?
    //                        appDelegate.storiesCollection.activeFolder :
    //                        [appDelegate.storiesCollection.activeFeed objectForKey:@"feed_title"];
    
    if (!everything && !infrequent && !read && !saved) {
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
    
    if (!appDelegate.storiesCollection.isRiverView && !infrequent && !saved && !read) {
        [options addObject:[@"Rename this site" uppercaseString]];
        [options addObject:[@"Mute this site" uppercaseString]];
        [options addObject:[@"Train this site" uppercaseString]];
        [options addObject:[@"Notifications" uppercaseString]];
        [options addObject:[@"Insta-fetch stories" uppercaseString]];
    }

    self.menuOptions = options;
}

- (BOOL)isRiver {
    return appDelegate.storiesCollection.isSocialRiverView ||
    appDelegate.storiesCollection.isSocialView ||
    appDelegate.storiesCollection.isSavedView ||
    appDelegate.storiesCollection.isReadView;
}

- (BOOL)isInfrequent {
    return appDelegate.storiesCollection.isRiverView &&
           [appDelegate.storiesCollection.activeFolder isEqualToString:@"infrequent"];
}

#pragma mark -
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    [self buildMenuOptions];
    
    return [self.menuOptions count] + ([self isRiver] ? 3 : 4) + ([self isInfrequent] ? 1 : 0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIndentifier = @"Cell";
    
    if (indexPath.row == [self.menuOptions count]) {
        return [self makeOrderCell];
    } else if ([self isInfrequent]) {
        if (indexPath.row == [self.menuOptions count] + 1) {
            return [self makeReadFilterCell];
        } else if (indexPath.row == [self.menuOptions count] + 2) {
            return [self makeFontSizeTableCell];
        } else if (indexPath.row == [self.menuOptions count] + 3) {
            return [self makeInfrequentTableCell];
        } else if (indexPath.row == [self.menuOptions count] + 4) {
            return [self makeThemeTableCell];
        }
    } else if (![self isRiver]) {
        if (indexPath.row == [self.menuOptions count] + 1) {
            return [self makeReadFilterCell];
        } else if (indexPath.row == [self.menuOptions count] + 2) {
            return [self makeFontSizeTableCell];
        } else if (indexPath.row == [self.menuOptions count] + 3) {
            return [self makeThemeTableCell];
        }
    } else if ([self isRiver]) {
        if (indexPath.row == [self.menuOptions count] + 1) {
            return [self makeFontSizeTableCell];
        } else if (indexPath.row == [self.menuOptions count] + 2) {
            return [self makeThemeTableCell];
        }
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
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_mute.png"];
    } else if (indexPath.row == 4) {
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_train.png"];
    } else if (indexPath.row == 5) {
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_notifications.png"];
    } else if (indexPath.row == 6) {
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
    BOOL shouldHide = YES;
    
    if (indexPath.row == 0) {
        [appDelegate.feedDetailViewController confirmDeleteSite];
        shouldHide = NO;
    } else if (indexPath.row == 1) {
        [appDelegate.feedDetailViewController openMoveView];
        shouldHide = NO;
    } else if (indexPath.row == 2) {
        [appDelegate.feedDetailViewController openRenameSite];
    } else if (indexPath.row == 3) {
        [appDelegate.feedDetailViewController confirmMuteSite];
        shouldHide = NO;
    } else if (indexPath.row == 4) {
        [appDelegate.feedDetailViewController openTrainSite];
    } else if (indexPath.row == 5) {
        [appDelegate.feedDetailViewController
         openNotificationsWithFeed:[NSString stringWithFormat:@"%@", [appDelegate.storiesCollection.activeFeed objectForKey:@"id"]]];
    } else if (indexPath.row == 6) {
        [appDelegate.feedDetailViewController instafetchFeed];
    }
    
    if (shouldHide) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.appDelegate hidePopover];
        } else {
            [self.appDelegate hidePopoverAnimated:YES];
        }
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (UITableViewCell *)makeOrderCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    orderSegmentedControl.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2,
                                             kMenuOptionHeight - 7*2);
    [orderSegmentedControl setTitle:[@"Newest first" uppercaseString] forSegmentAtIndex:0];
    [orderSegmentedControl setTitle:[@"Oldest" uppercaseString] forSegmentAtIndex:1];
    self.orderSegmentedControl.backgroundColor = UIColorFromRGB(0xeeeeee);
    
    [cell addSubview:orderSegmentedControl];
    
    return cell;
}

- (UITableViewCell *)makeReadFilterCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    readFilterSegmentedControl.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2,
                                                  kMenuOptionHeight - 7*2);
    [readFilterSegmentedControl setTitle:[@"All stories" uppercaseString] forSegmentAtIndex:0];
    [readFilterSegmentedControl setTitle:[@"Unread only" uppercaseString] forSegmentAtIndex:1];
    self.readFilterSegmentedControl.backgroundColor = UIColorFromRGB(0xeeeeee);
    
    [cell addSubview:readFilterSegmentedControl];
    
    return cell;
}

- (UITableViewCell *)makeFontSizeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    self.fontSizeSegment.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2, kMenuOptionHeight - 7*2);
    [self.fontSizeSegment setTitle:@"XS" forSegmentAtIndex:0];
    [self.fontSizeSegment setTitle:@"S" forSegmentAtIndex:1];
    [self.fontSizeSegment setTitle:@"M" forSegmentAtIndex:2];
    [self.fontSizeSegment setTitle:@"L" forSegmentAtIndex:3];
    [self.fontSizeSegment setTitle:@"XL" forSegmentAtIndex:4];
    self.fontSizeSegment.backgroundColor = UIColorFromRGB(0xeeeeee);
    [self.fontSizeSegment setTitleTextAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica-Bold" size:11.0f]} forState:UIControlStateNormal];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:2];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:3];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:4];
    
    [cell addSubview:self.fontSizeSegment];
    
    return cell;
}

- (UITableViewCell *)makeInfrequentTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    self.infrequentSegmentedControl.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2, kMenuOptionHeight - 7*2);
    [self.infrequentSegmentedControl setTitle:@"5" forSegmentAtIndex:0];
    [self.infrequentSegmentedControl setTitle:@"15" forSegmentAtIndex:1];
    [self.infrequentSegmentedControl setTitle:@"30" forSegmentAtIndex:2];
    [self.infrequentSegmentedControl setTitle:@"60" forSegmentAtIndex:3];
    [self.infrequentSegmentedControl setTitle:@"90" forSegmentAtIndex:4];
    self.infrequentSegmentedControl.backgroundColor = UIColorFromRGB(0xeeeeee);
    [self.infrequentSegmentedControl setTitleTextAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica-Bold" size:11.0f]} forState:UIControlStateNormal];
    [self.infrequentSegmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [self.infrequentSegmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    [self.infrequentSegmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:2];
    [self.infrequentSegmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:3];
    [self.infrequentSegmentedControl setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:4];
    
    [cell addSubview:self.infrequentSegmentedControl];
    
    return cell;
}

- (UITableViewCell *)makeThemeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    UIImage *lightImage = [self themeImageWithName:@"theme_color_light" selected:self.themeSegmentedControl.selectedSegmentIndex == 0];
    UIImage *sepiaImage = [self themeImageWithName:@"theme_color_sepia" selected:self.themeSegmentedControl.selectedSegmentIndex == 1];
    UIImage *mediumImage = [self themeImageWithName:@"theme_color_medium" selected:self.themeSegmentedControl.selectedSegmentIndex == 2];
    UIImage *darkImage = [self themeImageWithName:@"theme_color_dark" selected:self.themeSegmentedControl.selectedSegmentIndex == 3];
    
    self.themeSegmentedControl.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    [self.themeSegmentedControl setImage:lightImage forSegmentAtIndex:0];
    [self.themeSegmentedControl setImage:sepiaImage forSegmentAtIndex:1];
    [self.themeSegmentedControl setImage:mediumImage forSegmentAtIndex:2];
    [self.themeSegmentedControl setImage:darkImage forSegmentAtIndex:3];
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, self.themeSegmentedControl.frame.size.height), NO, 0.0);
    UIImage *blankImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self.themeSegmentedControl setDividerImage:blankImage forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    self.themeSegmentedControl.tintColor = [UIColor clearColor];
    self.themeSegmentedControl.backgroundColor = [UIColor clearColor];
    
    [cell addSubview:self.themeSegmentedControl];
    
    return cell;
}

- (UIImage *)themeImageWithName:(NSString *)name selected:(BOOL)selected {
    if (selected) {
        name = [name stringByAppendingString:@"-sel"];
    }
    
    return [[UIImage imageNamed:name] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
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

- (IBAction)changeFontSize:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [userPreferences setObject:@"xs" forKey:@"feed_list_font_size"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [userPreferences setObject:@"small" forKey:@"feed_list_font_size"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [userPreferences setObject:@"medium" forKey:@"feed_list_font_size"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [userPreferences setObject:@"large" forKey:@"feed_list_font_size"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [userPreferences setObject:@"xl" forKey:@"feed_list_font_size"];
    }
    [userPreferences synchronize];
    
    [appDelegate resizeFontSize];
}

- (IBAction)changeInfrequent:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [userPreferences setObject:[NSNumber numberWithInteger:5] forKey:@"infrequent_stories_per_month"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [userPreferences setObject:[NSNumber numberWithInteger:15] forKey:@"infrequent_stories_per_month"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [userPreferences setObject:[NSNumber numberWithInteger:30] forKey:@"infrequent_stories_per_month"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [userPreferences setObject:[NSNumber numberWithInteger:60] forKey:@"infrequent_stories_per_month"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [userPreferences setObject:[NSNumber numberWithInteger:90] forKey:@"infrequent_stories_per_month"];
    }
    [userPreferences synchronize];
    
    [appDelegate.feedDetailViewController reloadStories];
    [appDelegate.feedDetailViewController flashInfrequentStories];
}

- (IBAction)changeTheme:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *theme = ThemeStyleLight;
    switch ([sender selectedSegmentIndex]) {
        case 1:
            theme = ThemeStyleSepia;
            break;
        case 2:
            theme = ThemeStyleMedium;
            break;
        case 3:
            theme = ThemeStyleDark;
            break;
            
        default:
            break;
    }
    [ThemeManager themeManager].theme = theme;
    
    self.menuTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.menuTableView.separatorColor = UIColorFromRGB(0x909090);
    [self.menuTableView reloadData];
    [userPreferences synchronize];
}

@end
