//
//  EventWindow.m
//  NewsBlur
//
//  Created by Samuel Clay on 9/17/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "EventWindow.h"

@implementation EventWindow

@synthesize tapDetectingView;

- (void)tapAndHoldAction:(NSTimer*)timer {
    contextualMenuTimer = nil;
    NSDictionary *coord = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithFloat:tapLocation.x],@"x",
                           [NSNumber numberWithFloat:tapLocation.y],@"y",nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TapAndHoldNotification" object:coord];
}
- (void)tapAction {
    contextualMenuTimer = nil;
    NSDictionary *coord = [NSDictionary dictionaryWithObjectsAndKeys:
                           [NSNumber numberWithFloat:tapLocation.x],@"x",
                           [NSNumber numberWithFloat:tapLocation.y],@"y",nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"TapNotification" object:coord];
}

- (void)sendEvent:(UIEvent *)event {
    [super sendEvent:event];    // Call super to make sure the event is processed as usual
    
    if (!tapDetectingView) return;

    NSSet *touches = [event touchesForWindow:self];
    
    if ([touches count] == 1) { // We're only interested in one-finger events
        UITouch *touch = [touches anyObject];
        
        if (touch.view != nil && ![touch.view isDescendantOfView:tapDetectingView]) {
            return;
        }
        
        switch ([touch phase]) {
            case UITouchPhaseBegan:  // A finger touched the screen
                tapLocation = [touch locationInView:self];
                [contextualMenuTimer invalidate];
                unmoved = YES;
                contextualMenuTimer = [NSTimer scheduledTimerWithTimeInterval:0.7
                                                                       target:self selector:@selector(tapAndHoldAction:)
                                                                     userInfo:nil repeats:NO];
                break;
                
            case UITouchPhaseStationary:
                break;
                
            case UITouchPhaseEnded:
                [contextualMenuTimer invalidate];
                contextualMenuTimer = nil;
                if (unmoved) {
                    [self tapAction];
                }
                break;

            case UITouchPhaseMoved: // Changes in force are also "moves"
                if (CGPointEqualToPoint([touch locationInView:self], tapLocation)) {
                    
                    if ([touch respondsToSelector:@selector(force)] && (touch.force / touch.maximumPossibleForce) > 0.75) {
                        [contextualMenuTimer invalidate];
                        contextualMenuTimer = nil;
                        [self tapAndHoldAction:nil];
                    }
                    break;
                }
            case UITouchPhaseCancelled:
                unmoved = NO;
                [contextualMenuTimer invalidate];
                contextualMenuTimer = nil;
                break;
        }
    } else {                    // Multiple fingers are touching the screen
        unmoved = NO;
        [contextualMenuTimer invalidate];
        contextualMenuTimer = nil;
    }
}

@end