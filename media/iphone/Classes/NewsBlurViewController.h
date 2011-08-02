//
//  NewsBlurViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@class NewsBlurAppDelegate;

@interface NewsBlurViewController : UIViewController 
		   <UITableViewDelegate, UITableViewDataSource> 
{
    NewsBlurAppDelegate *appDelegate;
    
	NSMutableData *responseData;
	NSDictionary * dictFolders;
    NSDictionary * dictFeeds;
    NSMutableArray * dictFoldersArray;
    NSMutableDictionary * activeFeedLocations;
    
	IBOutlet UITableView * feedTitlesTable;
	IBOutlet UIToolbar * feedViewToolbar;
    IBOutlet UISlider * feedScoreSlider;
    IBOutlet UIBarButtonItem * logoutButton;
    IBOutlet UISegmentedControl * intelligenceControl;
}

- (void)fetchFeedList;
- (IBAction)doLogoutButton;
- (NSString *)showUnreadCount:(NSDictionary *)feed;
- (IBAction)selectIntelligence;
- (void)calculateFeedLocations;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITableView *feedTitlesTable;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * logoutButton;
@property (nonatomic, retain) NSMutableArray *dictFoldersArray;
@property (nonatomic, retain) NSMutableDictionary *activeFeedLocations;
@property (nonatomic, retain) NSDictionary *dictFolders;
@property (nonatomic, retain) NSDictionary *dictFeeds;
@property (nonatomic, retain) NSMutableData *responseData;
@property (nonatomic, retain) IBOutlet UISegmentedControl * intelligenceControl;

@end


@interface LogoutDelegate : NSObject {
    NewsBlurAppDelegate *appDelegate;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;

@end