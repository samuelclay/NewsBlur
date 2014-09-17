//
//  SSWDirectionalPanGestureRecognizer.h
//
//  Created by Arkadiusz Holko http://holko.pl on 01-06-14.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, SSWPanDirection) {
    SSWPanDirectionRight,
    SSWPanDirectionDown,
    SSWPanDirectionLeft,
    SSWPanDirectionUp
};

/**
 *  `SSWDirectionalPanGestureRecognizer` is a subclass of `UIPanGestureRecognizer`. It adds `direction` property and checks if the pan gesture started in the correct direction; it fails otherwise.
 */
@interface SSWDirectionalPanGestureRecognizer : UIPanGestureRecognizer

@property (nonatomic) SSWPanDirection direction;

@end
