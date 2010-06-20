//
//  NewsBlurAppDelegate.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import <UIKit/UIKit.h>

@class NewsBlurViewController;

@interface NewsBlurAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    NewsBlurViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet NewsBlurViewController *viewController;

@end

