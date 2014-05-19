//
//  OSKActivityIconButton.h
//  Overshare
//
//  Created by Jared Sinclair on 10/13/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKActivity;

@interface OSKActivityIcon : UIButton

- (void)setBackgroundImage:(UIImage *)image forActivityType:(NSString *)type displayString:(NSString *)displayString;

@end
