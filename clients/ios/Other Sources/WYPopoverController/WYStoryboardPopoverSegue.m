/*
 Version 0.2.2
 
 WYPopoverController is available under the MIT license.
 
 Copyright © 2013 Nicolas CHENG
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included
 in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "WYStoryboardPopoverSegue.h"


////////////////////////////////////////////////////////////////////////////

@interface WYStoryboardPopoverSegue()
{
    WYPopoverController *popoverController;
    id sender;
    WYPopoverArrowDirection arrowDirections;
    WYPopoverAnimationOptions options;
    BOOL animated;
}

@end

////////////////////////////////////////////////////////////////////////////

@implementation WYStoryboardPopoverSegue

- (void)perform
{
    if ([sender isKindOfClass:[UIBarButtonItem class]])
    {
        [popoverController presentPopoverFromBarButtonItem:(UIBarButtonItem*)sender
                                  permittedArrowDirections:arrowDirections
                                                  animated:animated
                                                   options:options];
    }
    else
    {
        UIView *view = (UIView *)sender;
        [popoverController presentPopoverFromRect:view.bounds
                                           inView:view
                         permittedArrowDirections:arrowDirections
                                         animated:animated
                                          options:options];
    }
}

- (WYPopoverController *)popoverControllerWithSender:(id)aSender
                            permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                                            animated:(BOOL)aAnimated
{
    return [self popoverControllerWithSender:aSender
                    permittedArrowDirections:aArrowDirections
                                    animated:aAnimated
                                     options:WYPopoverAnimationOptionFade];
}

- (WYPopoverController *)popoverControllerWithSender:(id)aSender
                            permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                                            animated:(BOOL)aAnimated
                                             options:(WYPopoverAnimationOptions)aOptions
{
    sender = aSender;
    arrowDirections = aArrowDirections;
    animated = aAnimated;
    options = aOptions;
    
    popoverController = [[WYPopoverController alloc] initWithContentViewController:self.destinationViewController];
    
    return popoverController;
}

- (void)dealloc
{
    sender = nil;
    popoverController = nil;
}

@end
