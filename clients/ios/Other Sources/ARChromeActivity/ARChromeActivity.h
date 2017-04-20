/*
  ARChromeActivity.h

  Copyright (c) 2012 Alex Robinson
  
  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */


#import <UIKit/UIKit.h>

@interface ARChromeActivity : UIActivity

/// Uses the "CFBundleName" from your Info.plist by default.
@property (strong, nonatomic) NSString *callbackSource;

/// The text beneath the icon. Defaults to "Chrome".
@property (strong, nonatomic) NSString *activityTitle;

/// Empty by default. Either set this in the initializer, or set this property. For iOS 9+, make sure you register the Chrome URL scheme in your Info.plist. See the demo project.
@property (strong, nonatomic) NSURL *callbackURL;

- (id)initWithCallbackURL:(NSURL *)callbackURL;

@end
