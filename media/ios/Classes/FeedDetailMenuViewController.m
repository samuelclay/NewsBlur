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

@implementation FeedDetailMenuViewController

@synthesize appDelegate;
@synthesize menuOptions;
@synthesize menuTableView;

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
        [options addObject:[@"Insta-fetch stories" uppercaseString]];
    }
    
    self.menuOptions = options;
}

#pragma mark -
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    [self buildMenuOptions];
    
    return [self.menuOptions count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIndentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:CellIndentifier];
    }
    
    cell.textLabel.text = [self.menuOptions objectAtIndex:[indexPath row]];
    cell.contentView.backgroundColor = UIColorFromRGB(0xBAE3A8);
    cell.textLabel.backgroundColor = UIColorFromRGB(0xBAE3A8);
    cell.textLabel.textColor = UIColorFromRGB(0x303030);
    cell.textLabel.shadowColor = UIColorFromRGB(0xF0FFF0);
    cell.textLabel.shadowOffset = CGSizeMake(0, 1);
    cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0];
    
    if (cell.selected) {
        cell.contentView.backgroundColor = UIColorFromRGB(0x639510);
        cell.textLabel.backgroundColor = UIColorFromRGB(0x639510);
        cell.selectedBackgroundView.backgroundColor = UIColorFromRGB(0x639510);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    if (indexPath.row == 0) {
        cell.imageView.image = [UIImage imageNamed:@"bin_closed"];
    } else if (indexPath.row == 1) {
        cell.imageView.image = [UIImage imageNamed:@"arrow_branch"];
    } else if (indexPath.row == 2) {
        cell.imageView.image = [UIImage imageNamed:@"car"];
    }
    
    return cell;
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 38;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        [appDelegate.feedDetailViewController confirmDeleteSite];
    } else if (indexPath.row == 1) {
        [appDelegate.feedDetailViewController openMoveView];
    } else if (indexPath.row == 2) {
        [appDelegate.feedDetailViewController instafetchFeed];
        [appDelegate.feedDetailViewController.popoverController dismissPopoverAnimated:YES];
    }
    
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//        [appDelegate.masterContainerViewController hidePopover];
//    } else {
//        [appDelegate.feedDetailViewController.popoverController dismissPopoverAnimated:YES];
//        appDelegate.feedDetailViewController.popoverController = nil;
//    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}

@end
