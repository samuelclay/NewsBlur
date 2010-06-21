//
//  NewsBlurViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurAppDelegate;

@interface NewsBlurViewController : UIViewController 
		   <UITableViewDelegate, UITableViewDataSource> 
{
    NewsBlurAppDelegate *appDelegate;
    
	NSMutableArray * feedTitleList;
	NSDictionary * dictFolders;
    NSMutableArray * dictFoldersArray;
    
	UITableView * viewTableFeedTitles;
	UIToolbar * feedViewToolbar;
    UISlider * feedScoreSlider;
    
}

-(void)fetchFeedList;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITableView *viewTableFeedTitles;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) IBOutlet UISlider * feedScoreSlider;
@property (nonatomic, retain) NSMutableArray *feedTitleList;
@property (nonatomic, retain) NSMutableArray *dictFoldersArray;
@property (nonatomic, retain) NSDictionary *dictFolders;

@end

