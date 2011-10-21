//
//  TestFlight.h
//  libTestFlight
//
//  Created by Jonathan Janzen on 06/11/11.
//  Copyright 2011 TestFlight. All rights reserved.

#import <Foundation/Foundation.h>
#define TESTFLIGHT_SDK_VERSION @"0.7.2"

@interface TestFlight : NSObject {

}

/**
 Add custom environment information
 If you want to track a user name from your application you can add it here
 */
+ (void)addCustomEnvironmentInformation:(NSString *)information forKey:(NSString*)key;

/**
 Starts a TestFlight session
 */
+ (void)takeOff:(NSString *)teamToken;

/**
 Sets custom options
    Option                      Accepted Values                 Description
    reinstallCrashHandlers      [NSNumber numberWithBool:YES]   Reinstalls crash handlers, to be used if a third party 
                                                                library installs crash handlers overtop of the TestFlight Crash Handlers
 */
+ (void)setOptions:(NSDictionary*)options;

/**
 Track when a user has passed a checkpoint after the flight has taken off. Eg. passed level 1, posted high score
 */
+ (void)passCheckpoint:(NSString *)checkpointName;

/**
 Opens a feeback window that is not attached to a checkpoint
 */
+ (void)openFeedbackView;

@end
