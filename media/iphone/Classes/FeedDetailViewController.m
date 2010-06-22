//
//  FeedDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "FeedDetailViewController.h"
#import "NewsBlurAppDelegate.h"


@implementation FeedDetailViewController

@synthesize storyTitlesTable, feedViewToolbar, feedScoreSlider;
@synthesize activeFeed;
@synthesize appDelegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		[appDelegate showNavigationBar:YES];
    }
    return self;
}

- (void)viewDidLoad {
    NSLog(@"Loaded Feed view: %@", self.activeFeed);
    [appDelegate showNavigationBar:YES];
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [appDelegate showNavigationBar:YES];
    
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [appDelegate hideNavigationBar:YES];
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)dealloc {
    [activeFeed release];
    [appDelegate release];
    [super dealloc];
}

#pragma mark Feed view



#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {

	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *SimpleTableIdentifier = @"SimpleTableIdentifier";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SimpleTableIdentifier];
	if (cell == nil) {
		
		cell = [[[UITableViewCell alloc] 
				 initWithStyle:UITableViewCellStyleDefault
				 reuseIdentifier:SimpleTableIdentifier] autorelease];
	}
//	
//	int section_index = 0;
//	for (id f in self.dictFoldersArray) {
//		// NSLog(@"Cell: %i: %@", section_index, f);
//		if (section_index == indexPath.section) {
//			NSArray *feeds = [self.dictFolders objectForKey:f];
//			// NSLog(@"Cell: %i: %@: %@", section_index, f, [feeds objectAtIndex:indexPath.row]);
//			cell.textLabel.text = [[feeds objectAtIndex:indexPath.row] 
//								   objectForKey:@"feed_title"];
//			return cell;
//		}
//		section_index++;
//	}
//	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	
}

@end
