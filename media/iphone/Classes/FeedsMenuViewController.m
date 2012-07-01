//
//  FeedsMenuViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/19/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FeedsMenuViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ASIFormDataRequest.h"
#import "MBProgressHUD.h"

@implementation FeedsMenuViewController

@synthesize appDelegate;
@synthesize menuOptions;
@synthesize toolbar;
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
    
    self.menuOptions = [[[NSArray alloc]
                        initWithObjects:@"Find Friends", @"Add Site", @"Logout", nil] autorelease];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        toolbar.hidden = YES;
        menuTableView.frame = CGRectMake(0, 0, menuTableView.frame.size.width, menuTableView.frame.size.height + 44);
    }
}

- (void)viewDidUnload
{
    toolbar = nil;
    menuTableView = nil;

    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.menuOptions = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)dealloc {   
    [appDelegate release];
    [menuOptions release];
    [toolbar release];
    [menuTableView release];
    [super dealloc];
}

- (IBAction)tapCancelButton:(UIBarButtonItem *)sender {
    [appDelegate hideFeedsMenu];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 1) {
        if (buttonIndex == 0) {
            return;
        } else {
            NSLog(@"Logging out...");
            NSString *urlS = [NSString stringWithFormat:@"http://%@/reader/logout?api=1",
                              NEWSBLUR_URL];
            NSURL *url = [NSURL URLWithString:urlS];
            
            __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
            [request setDelegate:self];
            [request setResponseEncoding:NSUTF8StringEncoding];
            [request setDefaultResponseEncoding:NSUTF8StringEncoding];
            [request setFailedBlock:^(void) {
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                [self finishedWithError:request];
            }];
            [request setCompletionBlock:^(void) {
                NSLog(@"Logout successful");
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                [appDelegate showLogin];
            }];
            [request setTimeOutSeconds:30];
            [request startAsynchronous];
            
            [ASIHTTPRequest setSessionCookies:nil];
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            HUD.labelText = @"Logging out...";
        }
    }
}

- (void)finishedWithError:(ASIHTTPRequest *)request {    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSLog(@"Error %@", [request error]);
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
        cell = [[[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:CellIndentifier] autorelease];
    }
    
    cell.textLabel.text = [self.menuOptions objectAtIndex:[indexPath row]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if (indexPath.row == 0) {
        NSLog(@"Find Friends");
        [appDelegate showFindFriends];
    } else if (indexPath.row == 1) {
        NSLog(@"Add Site");
        [appDelegate showAdd];
    } else if (indexPath.row == 3) {
        // logout
        UIAlertView *logoutConfirm = [[UIAlertView alloc] initWithTitle:@"Positive?" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Logout", nil];
        [logoutConfirm show];
        [logoutConfirm setTag:1];
        [logoutConfirm release];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [appDelegate hideFeedsMenu];
}

@end
