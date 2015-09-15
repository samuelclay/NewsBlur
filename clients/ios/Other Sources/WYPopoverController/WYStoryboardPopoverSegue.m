/*
 Version 0.3.6
 
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
  WYPopoverController *_popoverController;
  id _sender;
  WYPopoverArrowDirection _arrowDirections;
  WYPopoverAnimationOptions _options;
  BOOL _animated;
}

@end

////////////////////////////////////////////////////////////////////////////

@implementation WYStoryboardPopoverSegue

- (void)perform
{
  if ([_sender isKindOfClass:[UIBarButtonItem class]])
  {
    [_popoverController presentPopoverFromBarButtonItem:(UIBarButtonItem*)_sender
                               permittedArrowDirections:_arrowDirections
                                               animated:_animated
                                                options:_options];
  }
  else
  {
    UIView *view = (UIView *)_sender;
    [_popoverController presentPopoverFromRect:view.bounds
                                        inView:view
                      permittedArrowDirections:_arrowDirections
                                      animated:_animated
                                       options:_options];
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
  _sender = aSender;
  _arrowDirections = aArrowDirections;
  _animated = aAnimated;
  _options = aOptions;
  
  _popoverController = [[WYPopoverController alloc] initWithContentViewController:self.destinationViewController];
  
  return _popoverController;
}

- (void)dealloc
{
  _sender = nil;
  _popoverController = nil;
}

@end
