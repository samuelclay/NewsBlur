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
	NSArray *feed_list;
	UITableView *feed_table;
}

@property (nonatomic, retain) IBOutlet UITableView *feed_table;
@property (nonatomic, retain) NSArray *feed_list;;

@end

