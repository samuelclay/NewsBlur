/*
  ARChromeActivity.m

  Copyright (c) 2012 Alex Robinson
 
  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */


#import "ARChromeActivity.h"

@implementation ARChromeActivity {
	NSURL *_activityURL;
}

@synthesize callbackURL = _callbackURL;
@synthesize callbackSource = _callbackSource;
@synthesize activityTitle = _activityTitle;

- (void)commonInit {
    _callbackSource = [[NSBundle mainBundle]objectForInfoDictionaryKey:@"CFBundleName"];
    _activityTitle = @"Chrome";
}

- (id)init {
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCallbackURL:(NSURL *)callbackURL {
    self = [super init];
    if (self) {
        [self commonInit];
        _callbackURL = callbackURL;
    }
    return self;
}

- (UIImage *)activityImage {
    return [UIImage imageNamed:@"ARChromeActivity"];
}

- (NSString *)activityType {
    return NSStringFromClass([self class]);
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
	return [[activityItems lastObject] isKindOfClass:[NSURL class]] && [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"googlechrome-x-callback://"]];
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
	_activityURL = [activityItems lastObject];
}

- (void)performActivity {
	
    NSString *openingURL = [_activityURL.absoluteString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *callbackURL = [self.callbackURL.absoluteString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *sourceName = [self.callbackSource stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *activityURL = [NSURL URLWithString:
                          [NSString stringWithFormat:@"googlechrome-x-callback://x-callback-url/open/?url=%@&x-success=%@&x-source=%@",
                           openingURL,
                           callbackURL,
                           sourceName]];
    
	[[UIApplication sharedApplication] openURL:activityURL];
    
	[self activityDidFinish:YES];
}

@end
