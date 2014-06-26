//
//  OSKLogger.h
//  
//
//  Created by Jared Sinclair on October 10, 2013.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

#if DEBUG == 1
#define OSKLog(format, ...) NSLog((@"%s [Line %d]\n" format @"\n\n"), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define OSKLog(...)
#endif