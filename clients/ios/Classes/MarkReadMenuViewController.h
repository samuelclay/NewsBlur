//
//  MarkReadMenuViewController.h
//  NewsBlur
//
//  Created by David Sinclair on 2015-11-13.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MarkReadMenuViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (weak) IBOutlet UITableView *menuTableView;

@property (nonatomic, strong) NSString *collectionTitle;
@property (nonatomic, strong) NSArray *feedIds;
@property (nonatomic) NSInteger visibleUnreadCount;
@property (nonatomic, copy) void (^completionHandler)(BOOL marked);

@end
