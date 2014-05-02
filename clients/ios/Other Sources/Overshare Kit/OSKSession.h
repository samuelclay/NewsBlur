//
//  OSKSession.h
//  unread
//
//  Created by Jared Sinclair on 11/22/13.
//  Copyright (c) 2013 Nice Boy LLC. All rights reserved.
//

@import Foundation;

#import "OSKActivity.h"

typedef NS_ENUM(NSInteger, OSKPresentationEnding) {
    OSKPresentationEnding_Cancelled,
    OSKPresentationEnding_ProceededWithActivity,
};

typedef void(^OSKPresentationEndingHandler)(OSKPresentationEnding presentationEnding, OSKActivity *activityOrNil);

/**
 Represents a single sharing "session," i.e., the series of events beginning with the presentation
 of an activity sheet and ending with either a) an activity being performed successully, b) an
 activity failing, or c) the user cancelling without selecting an activity.
 
 Because there are multiple basis paths, we can't count on the OSKActivitySheetViewController or
 an OSKSessionController alone to keep track of completion blocks and session identifiers. Thus,
 a single OSKSession object is created per session, and is shared by both the activity sheet and
 the session controller. The activity sheet presents an assortment of activities, and the session
 controller takes over after the user selects an activity. They each retain a strong reference to 
 the same `<OSKSession>`, so that the OSKPresentationManager can keep track of multiple concurrent
 sessions (a long-running network operation may finish while the user is already sharing something 
 else).
 */
@interface OSKSession : NSObject

/**
 A GUID that identifies the session.
 */
@property (copy, nonatomic, readonly) NSString *sessionIdentifier;

/**
 A completion block to be called after all OvershareKit view controllers have been dismissed.
 
 The last view controller to be dismissed could be an activity sheet, or some other view controller,
 depending on the current user interface idiom and other factors.
 
 This block is called without respect to the state of the selected activity (if any).
 
 The `OSKPresentationEnding` block argument refers to the manner in which OvershareKit view controllers
 were dismissed: either by cancellation, or by the selection of an activity.
 */
@property (copy, nonatomic, readonly) OSKPresentationEndingHandler presentationEndingHandler;

/**
 A completion block to be called upon the success/failure of the selected activity for the session.
 
 This block is called without respect to the user interface state of OvershareKit view controllers.
 
 As of this writing, only one activity can be selected per session, but future versions of OvershareKit
 may support multiple selected activities per session. For now, this completion block will only be
 executed once, but it might be called multiple times in future releases.
 */
@property (copy, nonatomic, readonly) OSKActivityCompletionHandler activityCompletionHandler;

/**
 The designated initializer.
 */
- (instancetype)initWithPresentationEndingHandler:(OSKPresentationEndingHandler)endingHandler
                        activityCompletionHandler:(OSKActivityCompletionHandler)activityHandler;

@end




