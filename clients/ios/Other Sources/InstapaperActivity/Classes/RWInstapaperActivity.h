//
//  RWInstapaperActivity.h
//  InstapaperActivity
//
//  Created by Justin Ridgewell on 2/27/13.
//
//

#import <UIKit/UIKit.h>
#import "UIImage+ImageNamedExtension.h"
#import "ZYInstapaperActivityItem.h"
#import "ZYInstapaperAddRequestDelegate.h"

@interface RWInstapaperActivity : UIActivity <ZYInstapaperAddRequestDelegate>

@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSString *password;

+ (instancetype)instance;

@end
