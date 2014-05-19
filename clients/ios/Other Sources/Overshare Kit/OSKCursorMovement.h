//
//  OSKCursorMovement.h
//  Cursory
//
//  Based on 'JTSCursorMovement` created by Jared Sinclair on 2/20/14.
//  Copyright (c) 2014 Jared Sinclair All rights reserved.
//

@import UIKit;

///-------------------------------------
/// OSKCursorSwipeRecognizer
///-------------------------------------

/**
 A vanilla subclass of UISwipeGestureRecognizer, OSKCursorSwipeRecognizer allows apps with complex gesture
 recognizer setups to more easily handle potential conflicts as they arise.
 */
@interface OSKCursorSwipeRecognizer : UISwipeGestureRecognizer

@end

///-------------------------------------
/// OSKCursorMovement
///-------------------------------------

@interface OSKCursorMovement : NSObject

/**
 The text view passed as the `textView` in the designated initializer.
 */
@property (weak, nonatomic, readonly) UITextView *textView;

/**
 Setting this will enable/disable OSKCursorMovement's gesture recognizers.
 */
@property (assign, nonatomic, readwrite) BOOL enabled;

/**
 Designated initializer. Performs all setup. This method is all you'll usually need to use.
 
 @param textView OSKCursorMovement keeps a weak reference to this text view.
 
 @return Returns a fully-prepared cursor movement instance. 
 
 @note You'll need to maintain a strong reference to a OSKCursorMovement instance.
 
 */
- (instancetype)initWithTextView:(UITextView *)textView;

@end

///-------------------------------------
/// OSKCursorMovement | Gesture Recognizers
///-------------------------------------

/**
 These gesture recognizers are added to the text view during initialization. They are 
 only exposed for those apps that might need to know about them. Handle them with care.
 */
@interface OSKCursorMovement (GestureRecognizers)

@property (strong, nonatomic, readonly) OSKCursorSwipeRecognizer *leftSwipeRecognizer;
@property (strong, nonatomic, readonly) OSKCursorSwipeRecognizer *rightSwipeRecognizer;
@property (strong, nonatomic, readonly) OSKCursorSwipeRecognizer *leftSwipeRecognizer_twoFingers;
@property (strong, nonatomic, readonly) OSKCursorSwipeRecognizer *rightSwipeRecognizer_twoFingers;
@property (strong, nonatomic, readonly) OSKCursorSwipeRecognizer *leftSwipeRecognizer_threeFingers;
@property (strong, nonatomic, readonly) OSKCursorSwipeRecognizer *rightSwipeRecognizer_threeFingers;

@end



