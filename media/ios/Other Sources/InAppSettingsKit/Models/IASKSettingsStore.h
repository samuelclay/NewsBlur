//
//  IASKSettingsStore.h
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

/** protocol that needs to be implemented from a settings store
 */
@protocol IASKSettingsStore <NSObject>
@required
- (void)setBool:(BOOL)value      forKey:(NSString*)key;
- (void)setFloat:(float)value    forKey:(NSString*)key;
- (void)setDouble:(double)value  forKey:(NSString*)key;
- (void)setInteger:(int)value    forKey:(NSString*)key;
- (void)setObject:(id)value      forKey:(NSString*)key;
- (BOOL)boolForKey:(NSString*)key;
- (float)floatForKey:(NSString*)key;
- (double)doubleForKey:(NSString*)key;
- (int)integerForKey:(NSString*)key;
- (id)objectForKey:(NSString*)key;
- (BOOL)synchronize; // Write settings to a permanant storage. Returns YES on success, NO otherwise
@end


/** abstract default implementation of IASKSettingsStore protocol

 helper to implement a store which maps all methods to setObject:forKey:
 and objectForKey:. Those 2 methods need to be overwritten.
 */
@interface IASKAbstractSettingsStore : NSObject <IASKSettingsStore>

/** default implementation raises an exception
 must be overridden by subclasses
 */
- (void)setObject:(id)value forKey:(NSString*)key;

/** default implementation raises an exception
 must be overridden by subclasses
 */
- (id)objectForKey:(NSString*)key;

/** default implementation does nothing and returns NO
 */
- (BOOL)synchronize;

@end
