//
//  NSDate+OSK_ISO8601.h
//  Overshare Kit
//
//
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@interface NSDate (OSK_ISO8601)

+ (NSDate *)osk_dateFromISO8601string:(NSString *)iso8601string;
+ (NSDateFormatter *)osk_ISO8601stringDateFormatter;
+ (NSString *)osk_ISO8601stringFromDate:(NSDate *)date;

@end
