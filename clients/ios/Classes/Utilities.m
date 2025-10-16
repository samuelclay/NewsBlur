//
//  Utilities.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/17/11.
//  Copyright (c) 2011 NewsBlur. All rights reserved.
//

#import "Utilities.h"
#import <CommonCrypto/CommonCrypto.h>

void drawLinearGradient(CGContextRef context, CGRect rect, CGColorRef startColor, 
                        CGColorRef  endColor) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = { 0.0, 1.0 };
    
    NSArray *colors = [NSArray arrayWithObjects:(__bridge id)startColor, (__bridge id)endColor, nil];
    
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, 
                                                        (__bridge CFArrayRef) colors, locations);
    
    CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
    
    CGContextSaveGState(context);
    CGContextAddRect(context, rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

@implementation Utilities

+ (void)drawLinearGradientWithRect:(CGRect)rect startColor:(CGColorRef)startColor endColor:(CGColorRef)endColor {
    CGContextRef context = UIGraphicsGetCurrentContext(); 
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGFloat locations[] = { 0.0, 1.0 };
    
    NSArray *colors = [NSArray arrayWithObjects:(__bridge id)startColor, (__bridge id)endColor, nil];
    
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, 
                                                        (__bridge CFArrayRef) colors, locations);
    
    CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
    
    CGContextSaveGState(context);
    CGContextAddRect(context, rect);
    CGContextClip(context);
    
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);
    
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

+ (UIImage *)roundCorneredImage:(UIImage*)orig radius:(CGFloat)r {
    return [self roundCorneredImage:orig radius:r convertToSize:orig.size];
}

+ (UIImage *)roundCorneredImage:(UIImage*)orig radius:(CGFloat)r convertToSize:(CGSize)size {
    if (!orig) return nil;
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [[UIBezierPath bezierPathWithRoundedRect:(CGRect){CGPointZero, size}
                                cornerRadius:r] addClip];
    [orig drawInRect:(CGRect){CGPointZero, size}];
    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

+ (UIImage *)templateImageNamed:(NSString *)imageName sized:(CGFloat)size {
    UIImage *image = [self imageWithImage:[UIImage imageNamed:imageName] convertToSize:CGSizeMake(size, size)];
    
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    
    return image;
}

+ (UIImage *)imageNamed:(NSString *)imageName sized:(CGFloat)size {
    return [self imageWithImage:[UIImage imageNamed:imageName] convertToSize:CGSizeMake(size, size)];
}

+ (UIImage *)imageWithImage:(UIImage *)image convertToSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *destImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return destImage;
}

// These methods were an experiment in replacing the offline image filenames while tracing the images not appearing; an improvement, but skip for now; keep for future consideration.

//+ (NSString *)removeIllegalCharactersForFilename:(NSString *)filename {
//    NSCharacterSet *illegalCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"\\/:"];
//    NSString *cleanedFilename = [[filename componentsSeparatedByCharactersInSet:illegalCharacterSet] componentsJoinedByString:@"-"];
//    
//    return cleanedFilename;
//}
//
//+ (NSUInteger)checksum:(NSString *)string {
//    NSUInteger base = string.length;
//    NSUInteger result = base * base;
//    
//    for (NSUInteger i = 0; i < string.length; i++) {
//        result = (result + ([string characterAtIndex:i] * (i + 34)) + (732 * i) + (base * (i + 83))) % 999999999;
//    }
//    
//    return result;
//}
//
//+ (NSString *)md5:(NSString *)string storyHash:(NSString *)storyHash {
//    NSUInteger checksum = [self checksum:string];
//    NSString *cleanedStoryHash = [self removeIllegalCharactersForFilename:storyHash];
//    return [NSString stringWithFormat:@"%@-%@-%@", cleanedStoryHash, @(checksum), [self md5:string]];
//}

+ (NSString *)md5:(NSString *)string {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    const char *cStr = [string UTF8String];
    unsigned char result[16];
    CC_MD5( cStr, (CC_LONG)strlen(cStr), result ); // This is the md5 call
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];  
#pragma GCC diagnostic pop
}

+ (NSString *)formatLongDateFromTimestamp:(NSInteger)timestamp {
    if (!timestamp) timestamp = [[NSDate date] timeIntervalSince1970];
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(double)timestamp];
    
    static NSCalendar *calendar = nil;
    static NSDateFormatter *todayFormatter = nil;
    static NSDateFormatter *otherFormatter = nil;
    
    if (!calendar || !todayFormatter || !otherFormatter) {
        calendar = [NSCalendar currentCalendar];
        
        todayFormatter = [NSDateFormatter new];
        todayFormatter.dateStyle = NSDateFormatterNoStyle;
        todayFormatter.timeStyle = NSDateFormatterShortStyle;
        
        otherFormatter = [NSDateFormatter new];
        otherFormatter.dateStyle = NSDateFormatterLongStyle;
        otherFormatter.timeStyle = NSDateFormatterShortStyle;
        otherFormatter.doesRelativeDateFormatting = YES;
    }
    
    return [otherFormatter stringFromDate:date];
    
    
    
    
    
    /*
    static NSDateFormatter *dateFormatter = nil;
    static NSDateFormatter *todayFormatter = nil;
    static NSDateFormatter *yesterdayFormatter = nil;
    static NSDateFormatter *formatterPeriod = nil;
    
    NSDate *today = [NSDate date];
    NSDateComponents *components = [[NSCalendar currentCalendar]
                                    components:NSIntegerMax
                                    fromDate:today];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    NSDate *midnight = [[NSCalendar currentCalendar] dateFromComponents:components];
    NSDate *yesterday = [NSDate dateWithTimeInterval:-60*60*24 sinceDate:midnight];
    
    if (!dateFormatter || !todayFormatter || !yesterdayFormatter || !formatterPeriod) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"EEEE, MMMM d'Sth', y h:mm"];
        todayFormatter = [[NSDateFormatter alloc] init];
        [todayFormatter setDateFormat:@"'Today', MMMM d'Sth' h:mm"];
        yesterdayFormatter = [[NSDateFormatter alloc] init];
        [yesterdayFormatter setDateFormat:@"'Yesterday', MMMM d'Sth' h:mm"];
        formatterPeriod = [[NSDateFormatter alloc] init];
        [formatterPeriod setDateFormat:@"a"];
    }
    
    NSString *dateString;
    if ([date compare:midnight] == NSOrderedDescending) {
        dateString = [NSString stringWithFormat:@"%@%@",
                      [todayFormatter stringFromDate:date],
                      [[formatterPeriod stringFromDate:date] lowercaseString]];
    } else if ([date compare:yesterday] == NSOrderedDescending) {
        dateString = [NSString stringWithFormat:@"%@%@",
                      [yesterdayFormatter stringFromDate:date],
                      [[formatterPeriod stringFromDate:date] lowercaseString]];
    } else {
        dateString = [NSString stringWithFormat:@"%@%@",
                      [dateFormatter stringFromDate:date],
                      [[formatterPeriod stringFromDate:date] lowercaseString]];
    }
    dateString = [dateString stringByReplacingOccurrencesOfString:@"Sth"
                                                       withString:[Utilities suffixForDayInDate:date]];

    return dateString;
     */
}

+ (NSString *)formatShortDateFromTimestamp:(NSInteger)timestamp {
    if (!timestamp) timestamp = [[NSDate date] timeIntervalSince1970];
    
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:(double)timestamp];
    
    static NSCalendar *calendar = nil;
    static NSDateFormatter *todayFormatter = nil;
    static NSDateFormatter *otherFormatter = nil;
    
    if (!calendar || !todayFormatter || !otherFormatter) {
        calendar = [NSCalendar currentCalendar];
        
        todayFormatter = [NSDateFormatter new];
        todayFormatter.dateStyle = NSDateFormatterNoStyle;
        todayFormatter.timeStyle = NSDateFormatterShortStyle;
        
        otherFormatter = [NSDateFormatter new];
        otherFormatter.dateStyle = NSDateFormatterMediumStyle;
        otherFormatter.timeStyle = NSDateFormatterShortStyle;
        otherFormatter.doesRelativeDateFormatting = YES;
    }
    
    if ([calendar isDateInToday:date]) {
        return [todayFormatter stringFromDate:date];
    } else {
        return [otherFormatter stringFromDate:date];
    }
    
    /*
    static NSDateFormatter *dateFormatter = nil;
    static NSDateFormatter *todayFormatter = nil;
    static NSDateFormatter *yesterdayFormatter = nil;
    static NSDateFormatter *formatterPeriod = nil;
    
    NSDate *today = [NSDate date];
    NSDateComponents *components = [[NSCalendar currentCalendar]
                                    components:NSIntegerMax
                                    fromDate:today];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    NSDate *midnight = [[NSCalendar currentCalendar] dateFromComponents:components];
    NSDate *yesterday = [NSDate dateWithTimeInterval:-60*60*24 sinceDate:midnight];
    
    if (!dateFormatter || !todayFormatter || !yesterdayFormatter || !formatterPeriod) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"dd LLL y, h:mm"];
        todayFormatter = [[NSDateFormatter alloc] init];
        [todayFormatter setDateFormat:@"h:mm"];
        yesterdayFormatter = [[NSDateFormatter alloc] init];
        [yesterdayFormatter setDateFormat:@"'Yesterday', h:mm"];
        formatterPeriod = [[NSDateFormatter alloc] init];
        [formatterPeriod setDateFormat:@"a"];
    }

    NSString *dateString;
    if ([date compare:midnight] == NSOrderedDescending) {
        dateString = [NSString stringWithFormat:@"%@%@",
                      [todayFormatter stringFromDate:date],
                      [[formatterPeriod stringFromDate:date] lowercaseString]];
    } else if ([date compare:yesterday] == NSOrderedDescending) {
        dateString = [NSString stringWithFormat:@"%@%@",
                      [yesterdayFormatter stringFromDate:date],
                      [[formatterPeriod stringFromDate:date] lowercaseString]];
    } else {
        dateString = [NSString stringWithFormat:@"%@%@",
                      [dateFormatter stringFromDate:date],
                      [[formatterPeriod stringFromDate:date] lowercaseString]];
    }
    
    return dateString;
     */
}

/*
+ (NSString *)suffixForDayInDate:(NSDate *)date {
    NSInteger day = [[[[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian]
                      components:NSCalendarUnitDay fromDate:date] day];
    if (day == 11 || day == 12 || day == 13) {
        return @"th";
    } else if (day % 10 == 1) {
        return @"st";
    } else if (day % 10 == 2) {
        return @"nd";
    } else if (day % 10 == 3) {
        return @"rd";
    } else {
        return @"th";
    }
}
*/

@end


static __weak id currentFirstResponder;

@implementation UIResponder (FirstResponder)

/**
 This is primarily as a debugging aid.
*/

+(id)currentFirstResponder {
    currentFirstResponder = nil;
    [[UIApplication sharedApplication] sendAction:@selector(findFirstResponder:) to:nil from:nil forEvent:nil];
    return currentFirstResponder;
}

-(void)findFirstResponder:(id)sender {
    currentFirstResponder = self;
}

@end

