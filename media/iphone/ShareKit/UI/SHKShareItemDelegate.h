//  SHKShareItemDelegate.h
//  ShareKit
//
//  Created by Steve Troppoli on 7/12/11.

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//
#import <Foundation/Foundation.h>

#include "SHK.h"

@class SHKSharer;

@protocol SHKShareItemDelegate<NSObject>
@required
/** Called just before shareItem is called with this item on sharer. This gives you 
 a last minute chance to customize the data in the item before the share takes place.
 For example when posting a photo to a web service, there isn't any point in generating
 compressing and sending over the wire a 4000X4000 image if the max size for the service
 is 600X600.
 @param item - item that is being shared
 @param sharer - the sharer that will share the item
 @returns YES if the item should be shared by ShareKit, NO is the callee is going
 to handle it. This is useful if generating the image at the appropriate size for
 the service is an async process.*/
-(BOOL) aboutToShareItem:(SHKItem*)item withSharer:(SHKSharer*)sharer;
@end
