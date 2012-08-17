//
//  FeedsMenuViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/19/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FeedsMenuViewController.h"
#import "NewsBlurAppDelegate.h"
#import "MBProgressHUD.h"
#import "NBContainerViewController.h"
#import "NewsBlurViewController.h"

@implementation FeedsMenuViewController

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
    // Do any additional setup after loading the view from its nib.
    
    self.menuOptions = [[NSArray alloc]
                        initWithObjects:@"Find Friends", @"Logout", nil];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.menuOptions = nil;
    self.menuTableView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark -
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
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
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if (indexPath.row == 0) {
        [appDelegate showFindFriends];
    } if (indexPath.row == 1) {
        [appDelegate confirmLogout];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController hidePopover];
    } else {
        [appDelegate.feedsViewController.popoverController dismissPopoverAnimated:YES];
         appDelegate.feedsViewController.popoverController = nil;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

}

@end
