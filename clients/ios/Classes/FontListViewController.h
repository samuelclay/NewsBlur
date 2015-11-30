//
//  FontListViewController.h
//  NewsBlur
//
//  Created by David Sinclair on 2015-10-30.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FontListViewController : UIViewController

@property (weak) IBOutlet UITableView *fontTableView;

@property (nonatomic, strong) NSArray *fonts;

@end
