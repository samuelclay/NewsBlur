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
	NSMutableArray * feedTitleList;
	NSDictionary * dictFolders;
    NSMutableArray * dictFoldersArray;
    
	IBOutlet UITableView * viewTableFeedTitles;
	IBOutlet UIToolbar * feedViewToolbar;
    IBOutlet UISlider * feedScoreSlider;
    IBOutlet UIBarButtonItem * logoutButton;
    IBOutlet UILabel * toolbarTitle;
    
    
}

- (void)fetchFeedList;
- (IBAction)doLogoutButton;
- (void)setTitle:(NSString *)title;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITableView *viewTableFeedTitles;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic, retain) IBOutlet UIBarButtonItem * logoutButton;
@property (nonatomic, retain) IBOutlet UILabel * toolbarTitle;
@property (nonatomic, retain) NSMutableArray *feedTitleList;
@property (nonatomic, retain) NSMutableArray *dictFoldersArray;
@property (nonatomic, retain) NSDictionary *dictFolders;
@property (nonatomic, retain) NSMutableData *responseData;

@end


@interface LogoutDelegate : NSObject {
    NewsBlurAppDelegate *appDelegate;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connectionDidFinishLoading:(NSURLConnection *)connection;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;

@end