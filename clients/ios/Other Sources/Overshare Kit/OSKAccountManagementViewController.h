//
//  OSKAccountManagementViewController.h
//  Overshare
//
//  Created by Jared Sinclair on 10/29/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OSKAccountManagementViewController : UITableViewController

- (instancetype)initWithIgnoredActivityClasses:(NSArray *)ignoredActivityClasses
                optionalBespokeActivityClasses:(NSArray *)arrayOfClasses;

@end
