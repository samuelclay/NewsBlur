//
//  MarkReadMenuViewController.h
//  NewsBlur
//
//  Created by David Sinclair on 2015-11-13.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "StoriesCollection.h"

@interface MarkReadMenuViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (weak) IBOutlet UITableView *menuTableView;

@property (nonatomic, strong) NSString *collectionTitle;
@property (nonatomic, strong) NSArray *feedIds;
@property (nonatomic) NSInteger visibleUnreadCount;
@property (nonatomic, strong) StoriesCollection *olderNewerStoriesCollection;
@property (nonatomic, strong) NSDictionary *olderNewerStory;
@property (nonatomic, strong) NSArray *extraItems;
@property (nonatomic, copy) void (^completionHandler)(BOOL marked);

@end
