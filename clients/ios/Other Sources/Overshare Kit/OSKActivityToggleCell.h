//
//  OSKActivityToggleCell.h
//  Overshare
//
//  Created by Jared Sinclair on 10/30/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const OSKActivityToggleCellIdentifier;

@interface OSKActivityToggleCell : UITableViewCell

@property (strong, nonatomic) Class activityClass;

@end
