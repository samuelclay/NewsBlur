//
//  UIDevice+OSKHardware
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//
//  Based on code by InderKumarRathmore at https://github.com/InderKumarRathore/UIDevice-Hardware
//

@import UIKit;

#define IS_OSKHardwareType_iPad (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad)
#define DEVICE_IOS_VERSION [[UIDevice currentDevice].systemVersion floatValue]

#define DEVICE_HARDWARE_BETTER_THAN(i) [[UIDevice currentDevice] osk_isCurrentDeviceHardwareBetterThan:i]

typedef NS_ENUM(NSInteger, OSKHardwareType) {
    OSKHardwareType_NotAvailable,
    
    OSKHardwareType_iPhone_2G,
    OSKHardwareType_iPhone_3G,
    OSKHardwareType_iPhone_3GS,
    OSKHardwareType_iPhone_4,
    OSKHardwareType_iPhone_4_CDMA,
    OSKHardwareType_iPhone_4S,
    OSKHardwareType_iPhone_5,
    OSKHardwareType_iPhone_5_CDMA_GSM,
    OSKHardwareType_iPhone_5C,
    OSKHardwareType_iPhone_5C_CDMA_GSM,
    OSKHardwareType_iPhone_5S,
    OSKHardwareType_iPhone_5S_CDMA_GSM,
    
    OSKHardwareType_iPodTouch_1G,
    OSKHardwareType_iPodTouch_2G,
    OSKHardwareType_iPodTouch_3G,
    OSKHardwareType_iPodTouch_4G,
    OSKHardwareType_iPodTouch_5G,
    
    OSKHardwareType_iPad,
    OSKHardwareType_iPad_2,
    OSKHardwareType_iPad_2_WIFI,
    OSKHardwareType_iPad_2_CDMA,
    OSKHardwareType_iPad_3,
    OSKHardwareType_iPad_3G,
    OSKHardwareType_iPad_3_WIFI,
    OSKHardwareType_iPad_3_WIFI_CDMA,
    OSKHardwareType_iPad_4,
    OSKHardwareType_iPad_4_WIFI,
    OSKHardwareType_iPad_4_GSM_CDMA,
    OSKHardwareType_iPad_Air_WIFI,
    OSKHardwareType_iPad_Air_CELLULAR,
    
    OSKHardwareType_iPad_Mini,
    OSKHardwareType_iPad_Mini_WIFI,
    OSKHardwareType_iPad_Mini_WIFI_CDMA,
    OSKHardwareType_iPad_Mini_2G_WIFI,
    OSKHardwareType_iPad_Mini_2G_CELLULAR,
    
    OSKHardwareType_Simulator
};


@interface UIDevice (OSKHardware)

- (NSString *)osk_hardwareDisplayName;

- (OSKHardwareType)osk_hardwareType;

- (BOOL)osk_airDropIsAvailable;

@end



