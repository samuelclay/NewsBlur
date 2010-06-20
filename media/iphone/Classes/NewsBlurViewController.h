//
//  NewsBlurViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NewsBlurViewController : UIViewController 
		   <UITableViewDelegate, UITableViewDataSource> 
{
	NSMutableArray * feedTitleList;
	NSDictionary * dictFolders;
    NSMutableArray * dictFoldersArray;
    
	UITableView * viewTableFeedTitles;
	UIToolbar * feedViewToolbar;
}

-(void)fetchFeedList;

@property (nonatomic, retain) IBOutlet UITableView *viewTableFeedTitles;
@property (nonatomic, retain) IBOutlet UIToolbar *feedViewToolbar;
@property (nonatomic, retain) NSMutableArray *feedTitleList;
@property (nonatomic, retain) NSMutableArray *dictFoldersArray;
@property (nonatomic, retain) NSDictionary *dictFolders;

@end

