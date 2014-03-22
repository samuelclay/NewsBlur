//
//  NSDate+OSK_ISO8601.M
//  Overshare Kit
//
//
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "NSDate+OSK_ISO8601.h"

@implementation NSDate (OSK_ISO8601)

+ (NSDateFormatter *)osk_sharedDateFormatter {
    static NSDateFormatter *unr_sharedDateFormatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        unr_sharedDateFormatter = [NSDate osk_ISO8601stringDateFormatter];
    });
    return unr_sharedDateFormatter;
}

+ (NSDate *)osk_dateFromISO8601string:(NSString *)iso8601string {
    NSDate *date = nil;
    date = [self osk_dateFromISO8601stringWithoutUsingFormatter:iso8601string];
    return date;
}

// 2014-09-26THH:MM:SSZ
// 012345678901234567890
// 0         1         2

+ (NSDate *)osk_dateFromISO8601stringWithoutUsingFormatter:(NSString *)iso8601string {
    NSString *yearString = [iso8601string substringWithRange:NSMakeRange(0, 4)];
    NSString *monthString = [iso8601string substringWithRange:NSMakeRange(5, 2)];
    NSString *dayString = [iso8601string substringWithRange:NSMakeRange(8, 2)];
    NSString *hourString = [iso8601string substringWithRange:NSMakeRange(11, 2)];
    NSString *minString = [iso8601string substringWithRange:NSMakeRange(14, 2)];
    NSString *secString = [iso8601string substringWithRange:NSMakeRange(17, 2)];
    
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    [comps setYear:[yearString intValue]];
    [comps setMonth:[monthString intValue]];
    [comps setDay:[dayString intValue]];
    [comps setHour:[hourString intValue]];
    [comps setMinute:[minString intValue]];
    [comps setSecond:[secString intValue]];
    NSDate *theDate = [[NSCalendar currentCalendar] dateFromComponents:comps];
    return theDate;
}

+ (NSDateFormatter *)osk_ISO8601stringDateFormatter {
    // Fixes 12 hour pref in 24 hour locale bug, and possibly others.
    // See: http://developer.apple.com/library/ios/#qa/qa1480/_index.html
    NSDateFormatter *aFormatter = [[NSDateFormatter alloc] init];
    NSLocale *twelveHourLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    aFormatter.locale = twelveHourLocale;
    aFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    [aFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    return aFormatter;
}

+ (NSString *)osk_ISO8601stringFromDate:(NSDate *)date {
    NSString *string = nil;
    NSDateFormatter *formatter = [NSDate osk_sharedDateFormatter];
    @synchronized(formatter) {
        string = [formatter stringFromDate:date];
    }
    return string;
}

@end








