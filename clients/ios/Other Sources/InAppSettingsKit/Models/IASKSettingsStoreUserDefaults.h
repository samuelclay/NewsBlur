//
//  IASKSettingsStoreUserDefaults.h
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2010:
//  Luc Vandal, Edovia Inc., http://www.edovia.com
//  Ortwin Gentz, FutureTap GmbH, http://www.futuretap.com
//  Marc-Etienne M.Léveillé, Edovia Inc., http://www.edovia.com
//  All rights reserved.
// 
//  It is appreciated but not required that you give credit to Luc Vandal and Ortwin Gentz, 
//  as the original authors of this code. You can give credit in a blog post, a tweet or on 
//  a info page of your app. Also, the original authors appreciate letting them know if you use this code.
//
//  This code is licensed under the BSD license that is available at: http://www.opensource.org/licenses/bsd-license.php
//

#import <Foundation/Foundation.h>
#import "IASKSettingsStore.h"

/** implementation of IASKSettingsStore that uses NSUserDefaults
 */
@interface IASKSettingsStoreUserDefaults : NSObject<IASKSettingsStore>

///designated initializer
- (id) initWithUserDefaults:(NSUserDefaults*) defaults;

///calls initWithUserDefaults: with [NSUserDefaults standardUserDefaults]
- (id) init;

@property (nonatomic, retain, readonly) NSUserDefaults* defaults;

@end
