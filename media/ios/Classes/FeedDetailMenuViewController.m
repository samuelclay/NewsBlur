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
    self.menuTableView.backgroundColor = UIColorFromRGB(0xF0FFF0);
    self.menuTableView.separatorColor = UIColorFromRGB(0x8AA378);
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
    [self.menuTableView reloadData];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *orderKey = [appDelegate orderKey];
    NSString *readFilterKey = [appDelegate readFilterKey];
    
    [orderSegmentedControl setSelectedSegmentIndex:0];
    if ([[userPreferences stringForKey:orderKey] isEqualToString:@"oldest"]) {
        [orderSegmentedControl setSelectedSegmentIndex:1];
    }
    
    [readFilterSegmentedControl setSelectedSegmentIndex:0];
    if ([[userPreferences stringForKey:readFilterKey] isEqualToString:@"unread"]) {
        [readFilterSegmentedControl setSelectedSegmentIndex:1];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (BOOL)automaticallyForwardAppearanceAndRotationMethodsToChildViewControllers {
    return YES;
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    return YES;
}

- (void)buildMenuOptions {    
    NSMutableArray *options = [NSMutableArray array];
    
    //    NSString *title = appDelegate.isRiverView ?
    //                        appDelegate.activeFolder :
    //                        [appDelegate.activeFeed objectForKey:@"feed_title"];
    
    NSString *deleteText = [NSString stringWithFormat:@"Delete %@",
                            appDelegate.isRiverView ?
                            @"this entire folder" :
                            @"this site"];
    [options addObject:[deleteText uppercaseString]];
    
    [options addObject:[@"Move to another folder" uppercaseString]];
    
    if (!appDelegate.isRiverView) {
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
    if (appDelegate.isRiverView || appDelegate.isSocialRiverView || appDelegate.isSocialView) {
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
        cell.imageView.image = [UIImage imageNamed:@"bin_closed"];
    } else if (indexPath.row == 1) {
        cell.imageView.image = [UIImage imageNamed:@"arrow_branch"];
    } else if (indexPath.row == 2) {
        cell.imageView.image = [UIImage imageNamed:@"bricks"];
    } else if (indexPath.row == 3) {
        cell.imageView.image = [UIImage imageNamed:@"car"];
    }
    
    return cell;
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
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
        [appDelegate.feedDetailViewController openTrainSite];
    } else if (indexPath.row == 3) {
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
    UIFont *font = [UIFont boldSystemFontOfSize:11.0f];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:UITextAttributeFont];
    
    orderSegmentedControl.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2,
                                             kMenuOptionHeight - 7*2);
    [orderSegmentedControl setTitle:[@"Newest first" uppercaseString] forSegmentAtIndex:0];
    [orderSegmentedControl setTitle:[@"Oldest" uppercaseString] forSegmentAtIndex:1];
    [orderSegmentedControl setTitleTextAttributes:attributes forState:UIControlStateNormal];
    [orderSegmentedControl setTintColor:UIColorFromRGB(0x738570)];
    
    [cell addSubview:orderSegmentedControl];
    
    return cell;
}

- (UITableViewCell *)makeReadFilterCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UIFont *font = [UIFont boldSystemFontOfSize:11.0f];
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:UITextAttributeFont];
    
    readFilterSegmentedControl.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2,
                                                  kMenuOptionHeight - 7*2);
    [readFilterSegmentedControl setTitle:[@"All stories" uppercaseString] forSegmentAtIndex:0];
    [readFilterSegmentedControl setTitle:[@"Unread only" uppercaseString] forSegmentAtIndex:1];
    [readFilterSegmentedControl setTitleTextAttributes:attributes forState:UIControlStateNormal];
    [readFilterSegmentedControl setTintColor:UIColorFromRGB(0x738570)];
    
    [cell addSubview:readFilterSegmentedControl];
    
    return cell;
}

- (IBAction)changeOrder:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];

    if ([sender selectedSegmentIndex] == 0) {
        [userPreferences setObject:@"newest" forKey:[appDelegate orderKey]];
    } else {
        [userPreferences setObject:@"oldest" forKey:[appDelegate orderKey]];
    }
    
    [userPreferences synchronize];
    
    [appDelegate.feedDetailViewController reloadPage];
}

- (IBAction)changeReadFilter:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([sender selectedSegmentIndex] == 0) {
        [userPreferences setObject:@"all" forKey:[appDelegate readFilterKey]];
    } else {
        [userPreferences setObject:@"unread" forKey:[appDelegate readFilterKey]];
    }
    
    [userPreferences synchronize];
    
    [appDelegate.feedDetailViewController reloadPage];
    
}

@end
