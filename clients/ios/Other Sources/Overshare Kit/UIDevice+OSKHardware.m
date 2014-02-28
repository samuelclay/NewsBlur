//
//  UIDevice+OSKHardware
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//
//  Based on code by InderKumarRathmore at https://github.com/InderKumarRathore/UIDevice-Hardware
//

#import "UIDevice+OSKHardware.h"
#include <sys/types.h>
#include <sys/sysctl.h>

@implementation UIDevice (OSKHardware)

- (NSString*)osk_hardwareString {
    size_t size = 100;
    char *hw_machine = malloc(size);
    int name[] = {CTL_HW,HW_MACHINE};
    sysctl(name, 2, hw_machine, &size, NULL, 0);
    NSString *hardware = [NSString stringWithUTF8String:hw_machine];
    free(hw_machine);
    return hardware;
}

- (OSKHardwareType)osk_hardwareType {
    NSString *hardware = [self osk_hardwareString];
    
    if ([hardware isEqualToString:@"iPhone1,1"])    return OSKHardwareType_iPhone_2G;
    if ([hardware isEqualToString:@"iPhone1,2"])    return OSKHardwareType_iPhone_3G;
    if ([hardware isEqualToString:@"iPhone2,1"])    return OSKHardwareType_iPhone_3GS;
    if ([hardware isEqualToString:@"iPhone3,1"])    return OSKHardwareType_iPhone_4;
    if ([hardware isEqualToString:@"iPhone3,2"])    return OSKHardwareType_iPhone_4;
    if ([hardware isEqualToString:@"iPhone3,3"])    return OSKHardwareType_iPhone_4_CDMA;
    if ([hardware isEqualToString:@"iPhone4,1"])    return OSKHardwareType_iPhone_4S;
    if ([hardware isEqualToString:@"iPhone5,1"])    return OSKHardwareType_iPhone_5;
    if ([hardware isEqualToString:@"iPhone5,2"])    return OSKHardwareType_iPhone_5_CDMA_GSM;
    if ([hardware isEqualToString:@"iPhone5,3"])    return OSKHardwareType_iPhone_5C;
    if ([hardware isEqualToString:@"iPhone5,4"])    return OSKHardwareType_iPhone_5C_CDMA_GSM;
    if ([hardware isEqualToString:@"iPhone6,1"])    return OSKHardwareType_iPhone_5S;
    if ([hardware isEqualToString:@"iPhone6,2"])    return OSKHardwareType_iPhone_5S_CDMA_GSM;
    
    if ([hardware isEqualToString:@"iPod1,1"])      return OSKHardwareType_iPodTouch_1G;
    if ([hardware isEqualToString:@"iPod2,1"])      return OSKHardwareType_iPodTouch_2G;
    if ([hardware isEqualToString:@"iPod3,1"])      return OSKHardwareType_iPodTouch_3G;
    if ([hardware isEqualToString:@"iPod4,1"])      return OSKHardwareType_iPodTouch_4G;
    if ([hardware isEqualToString:@"iPod5,1"])      return OSKHardwareType_iPodTouch_5G;
    
    if ([hardware isEqualToString:@"iPad1,1"])      return OSKHardwareType_iPad;
    if ([hardware isEqualToString:@"iPad1,2"])      return OSKHardwareType_iPad_3G;
    if ([hardware isEqualToString:@"iPad2,1"])      return OSKHardwareType_iPad_2_WIFI;
    if ([hardware isEqualToString:@"iPad2,2"])      return OSKHardwareType_iPad_2;
    if ([hardware isEqualToString:@"iPad2,3"])      return OSKHardwareType_iPad_2_CDMA;
    if ([hardware isEqualToString:@"iPad2,4"])      return OSKHardwareType_iPad_2;
    if ([hardware isEqualToString:@"iPad2,5"])      return OSKHardwareType_iPad_Mini_WIFI;
    if ([hardware isEqualToString:@"iPad2,6"])      return OSKHardwareType_iPad_Mini;
    if ([hardware isEqualToString:@"iPad2,7"])      return OSKHardwareType_iPad_Mini_WIFI_CDMA;
    if ([hardware isEqualToString:@"iPad3,1"])      return OSKHardwareType_iPad_3_WIFI;
    if ([hardware isEqualToString:@"iPad3,2"])      return OSKHardwareType_iPad_3_WIFI_CDMA;
    if ([hardware isEqualToString:@"iPad3,3"])      return OSKHardwareType_iPad_3;
    if ([hardware isEqualToString:@"iPad3,4"])      return OSKHardwareType_iPad_4_WIFI;
    if ([hardware isEqualToString:@"iPad3,5"])      return OSKHardwareType_iPad_4;
    if ([hardware isEqualToString:@"iPad3,6"])      return OSKHardwareType_iPad_4_GSM_CDMA;
    if ([hardware isEqualToString:@"iPad4,1"])      return OSKHardwareType_iPad_Air_WIFI;
    if ([hardware isEqualToString:@"iPad4,2"])      return OSKHardwareType_iPad_Air_CELLULAR;
    if ([hardware isEqualToString:@"iPad4,4"])      return OSKHardwareType_iPad_Mini_2G_WIFI;
    if ([hardware isEqualToString:@"iPad4,5"])      return OSKHardwareType_iPad_Mini_2G_CELLULAR;
    
    if ([hardware isEqualToString:@"i386"])         return OSKHardwareType_Simulator;
    if ([hardware isEqualToString:@"x86_64"])       return OSKHardwareType_Simulator;
    
    return OSKHardwareType_NotAvailable;
}

- (BOOL)osk_airDropIsAvailable {
    BOOL isAvailable = NO;
    OSKHardwareType hardwareType = [self osk_hardwareType];
    if (OSKHardwareType_NotAvailable) {
        isAvailable = YES;
    } else {
        NSString *hardwareString = [self osk_hardwareString];
        if ([hardwareString hasPrefix:@"iPhone"]) {
            isAvailable = (hardwareType >= OSKHardwareType_iPhone_5);
        }
        else if ([hardwareString hasPrefix:@"iPad"]) {
            isAvailable = (hardwareType >= OSKHardwareType_iPad_4_WIFI);
        }
        else if ([hardwareString hasPrefix:@"iPod"]) {
            isAvailable = (hardwareType >= OSKHardwareType_iPodTouch_5G);
        }
    }
    return isAvailable;
}

- (NSString *)osk_hardwareDisplayName {
    
    NSString *hardware = [self osk_hardwareString];
    
    if ([hardware isEqualToString:@"iPhone1,1"])    return @"iPhone";
    if ([hardware isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([hardware isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    if ([hardware isEqualToString:@"iPhone3,1"])    return @"iPhone 4";
    if ([hardware isEqualToString:@"iPhone3,2"])    return @"iPhone 4";
    if ([hardware isEqualToString:@"iPhone3,3"])    return @"iPhone 4 CDMA";
    if ([hardware isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    if ([hardware isEqualToString:@"iPhone5,1"])    return @"iPhone 5";
    if ([hardware isEqualToString:@"iPhone5,2"])    return @"iPhone 5 CDMA GSM";
    if ([hardware isEqualToString:@"iPhone5,3"])    return @"iPhone 5C";
    if ([hardware isEqualToString:@"iPhone5,4"])    return @"iPhone 5C CDMA GSM";
    if ([hardware isEqualToString:@"iPhone6,1"])    return @"iPhone 5S";
    if ([hardware isEqualToString:@"iPhone6,2"])    return @"iPhone 5S CDMA GSM";
    
    if ([hardware isEqualToString:@"iPod1,1"])      return @"iPodTouch 1G";
    if ([hardware isEqualToString:@"iPod2,1"])      return @"iPodTouch 2G";
    if ([hardware isEqualToString:@"iPod3,1"])      return @"iPodTouch 3G";
    if ([hardware isEqualToString:@"iPod4,1"])      return @"iPodTouch 4G";
    if ([hardware isEqualToString:@"iPod5,1"])      return @"iPodTouch 5G";
    
    if ([hardware isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([hardware isEqualToString:@"iPad1,2"])      return @"iPad 3G";
    if ([hardware isEqualToString:@"iPad2,1"])      return @"iPad 2 WIFI";
    if ([hardware isEqualToString:@"iPad2,2"])      return @"iPad 2";
    if ([hardware isEqualToString:@"iPad2,3"])      return @"iPad 2 CDMA";
    if ([hardware isEqualToString:@"iPad2,4"])      return @"iPad 2";
    if ([hardware isEqualToString:@"iPad2,5"])      return @"iPad Mini WIFI";
    if ([hardware isEqualToString:@"iPad2,6"])      return @"iPad Mini";
    if ([hardware isEqualToString:@"iPad2,7"])      return @"iPad Mini WIFI CDMA";
    if ([hardware isEqualToString:@"iPad3,1"])      return @"iPad 3 WIFI";
    if ([hardware isEqualToString:@"iPad3,2"])      return @"iPad 3 WIFI CDMA";
    if ([hardware isEqualToString:@"iPad3,3"])      return @"iPad 3";
    if ([hardware isEqualToString:@"iPad3,4"])      return @"iPad 4 WIFI";
    if ([hardware isEqualToString:@"iPad3,5"])      return @"iPad 4";
    if ([hardware isEqualToString:@"iPad3,6"])      return @"iPad 4 GSM CDMA";
    if ([hardware isEqualToString:@"iPad4,1"])      return @"iPad Air WIFI";
    if ([hardware isEqualToString:@"iPad4,2"])      return @"iPad Air CELLULAR";
    if ([hardware isEqualToString:@"iPad4,4"])      return @"iPad Mini 2G WIFI";
    if ([hardware isEqualToString:@"iPad4,5"])      return @"iPad Mini 2G CELLULAR";
    
    if ([hardware isEqualToString:@"i386"])         return @"Simulator";
    if ([hardware isEqualToString:@"x86_64"])       return @"Simulator";
    
    return @"";
}

@end


