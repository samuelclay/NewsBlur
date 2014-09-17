//
//  OSKCursorMovement.m
//  Cursory
//
//  Created by Jared Sinclair on 2/20/14.
//  Copyright (c) 2014 Jared Sinclair All rights reserved.
//

#import "OSKCursorMovement.h"

@implementation OSKCursorSwipeRecognizer

@end

@interface OSKCursorMovement ()

@property (weak, nonatomic, readwrite) UITextView *textView;
@property (strong, nonatomic, readwrite) OSKCursorSwipeRecognizer *leftSwipeRecognizer;
@property (strong, nonatomic, readwrite) OSKCursorSwipeRecognizer *rightSwipeRecognizer;
@property (strong, nonatomic, readwrite) OSKCursorSwipeRecognizer *leftSwipeRecognizer_twoFingers;
@property (strong, nonatomic, readwrite) OSKCursorSwipeRecognizer *rightSwipeRecognizer_twoFingers;
@property (strong, nonatomic, readwrite) OSKCursorSwipeRecognizer *leftSwipeRecognizer_threeFingers;
@property (strong, nonatomic, readwrite) OSKCursorSwipeRecognizer *rightSwipeRecognizer_threeFingers;

@end

@implementation OSKCursorMovement

#pragma mark - NSObject

- (void)dealloc {
    [_leftSwipeRecognizer.view removeGestureRecognizer:_leftSwipeRecognizer];
    [_rightSwipeRecognizer.view removeGestureRecognizer:_rightSwipeRecognizer];
    [_leftSwipeRecognizer_twoFingers.view removeGestureRecognizer:_leftSwipeRecognizer_twoFingers];
    [_rightSwipeRecognizer_twoFingers.view removeGestureRecognizer:_rightSwipeRecognizer_twoFingers];
    [_leftSwipeRecognizer_threeFingers.view removeGestureRecognizer:_leftSwipeRecognizer_threeFingers];
    [_rightSwipeRecognizer_threeFingers.view removeGestureRecognizer:_rightSwipeRecognizer_threeFingers];
}

#pragma mark - OSKCursorMovement

- (instancetype)initWithTextView:(UITextView *)textView {
    
    self = [super init];
    if (self) {
        _enabled = YES;
        _textView = textView;
        [self setupGestureRecognizersWithView:textView];
    }
    return self;
}

#pragma mark - Setup

- (void)setupGestureRecognizersWithView:(UITextView *)textView {
    
    // One Finger
    OSKCursorSwipeRecognizer *leftSwipeRecognizer = [[OSKCursorSwipeRecognizer alloc]
                                                     initWithTarget:self
                                                     action:@selector(swipedToTheLeft:)];
    OSKCursorSwipeRecognizer *rightSwipeRecognizer = [[OSKCursorSwipeRecognizer alloc]
                                                      initWithTarget:self
                                                      action:@selector(swipedToTheRight:)];
    
    // Two Fingers
    OSKCursorSwipeRecognizer *leftSwipeRecognizer_twoFingers = [[OSKCursorSwipeRecognizer alloc]
                                                                initWithTarget:self
                                                                action:@selector(twoFingerSwipedToTheLeft:)];
    OSKCursorSwipeRecognizer *rightSwipeRecognizer_twoFingers = [[OSKCursorSwipeRecognizer alloc]
                                                                 initWithTarget:self
                                                                 action:@selector(twoFingerSwipedToTheRight:)];
    
    // Three Fingers
    OSKCursorSwipeRecognizer *leftSwipeRecognizer_threeFingers = [[OSKCursorSwipeRecognizer alloc]
                                                                  initWithTarget:self
                                                                  action:@selector(threeFingerSwipedToTheLeft:)];
    OSKCursorSwipeRecognizer *rightSwipeRecognizer_threeFingers = [[OSKCursorSwipeRecognizer alloc]
                                                                   initWithTarget:self
                                                                   action:@selector(threeFingerSwipedToTheRight:)];
    
    // Directions and Touch Counts
    leftSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
    rightSwipeRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    leftSwipeRecognizer_twoFingers.direction = UISwipeGestureRecognizerDirectionLeft;
    rightSwipeRecognizer_twoFingers.direction = UISwipeGestureRecognizerDirectionRight;
    leftSwipeRecognizer_threeFingers.direction = UISwipeGestureRecognizerDirectionLeft;
    rightSwipeRecognizer_threeFingers.direction = UISwipeGestureRecognizerDirectionRight;
    leftSwipeRecognizer_twoFingers.numberOfTouchesRequired = 2;
    rightSwipeRecognizer_twoFingers.numberOfTouchesRequired = 2;
    leftSwipeRecognizer_threeFingers.numberOfTouchesRequired = 3;
    rightSwipeRecognizer_threeFingers.numberOfTouchesRequired = 3;
    
    [textView addGestureRecognizer:leftSwipeRecognizer];
    [textView addGestureRecognizer:rightSwipeRecognizer];
    [textView addGestureRecognizer:leftSwipeRecognizer_twoFingers];
    [textView addGestureRecognizer:rightSwipeRecognizer_twoFingers];
    [textView addGestureRecognizer:leftSwipeRecognizer_threeFingers];
    [textView addGestureRecognizer:rightSwipeRecognizer_threeFingers];
    
    [self setLeftSwipeRecognizer:leftSwipeRecognizer];
    [self setRightSwipeRecognizer:rightSwipeRecognizer];
    [self setLeftSwipeRecognizer_twoFingers:leftSwipeRecognizer_twoFingers];
    [self setRightSwipeRecognizer_twoFingers:rightSwipeRecognizer_twoFingers];
    [self setLeftSwipeRecognizer_threeFingers:leftSwipeRecognizer_threeFingers];
    [self setRightSwipeRecognizer_threeFingers:rightSwipeRecognizer_threeFingers];
}

#pragma mark - Enabling

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [self.leftSwipeRecognizer setEnabled:_enabled];
    [self.rightSwipeRecognizer setEnabled:_enabled];
    [self.leftSwipeRecognizer_twoFingers setEnabled:_enabled];
    [self.rightSwipeRecognizer_twoFingers setEnabled:_enabled];
    [self.leftSwipeRecognizer_threeFingers setEnabled:_enabled];
    [self.rightSwipeRecognizer_threeFingers setEnabled:_enabled];
}

#pragma mark - Swipe Actions

- (void)swipedToTheRight:(id)sender {
    if ([self currentWritingDirection:self.textView] == UITextWritingDirectionRightToLeft) {
        [self goBackwardOneCharacter];
    } else {
        [self goForwardOneCharacter];
    }
}

- (void)swipedToTheLeft:(id)sender {
    if ([self currentWritingDirection:self.textView] == UITextWritingDirectionRightToLeft) {
        [self goForwardOneCharacter];
    } else {
        [self goBackwardOneCharacter];
    }
}

- (void)twoFingerSwipedToTheRight:(id)sender {
    if ([self currentWritingDirection:self.textView] == UITextWritingDirectionRightToLeft) {
        [self goBackwardOneWord];
    } else {
        [self goForwardOneWord];
    }
}

- (void)twoFingerSwipedToTheLeft:(id)sender {
    if ([self currentWritingDirection:self.textView] == UITextWritingDirectionRightToLeft) {
        [self goForwardOneWord];
    } else {
        [self goBackwardOneWord];
    }
}

- (void)threeFingerSwipedToTheRight:(id)sender {
    if ([self currentWritingDirection:self.textView] == UITextWritingDirectionRightToLeft) {
        [self goBackwardOneParagraph];
    } else {
        [self goForwardOneParagraph];
    }
}

- (void)threeFingerSwipedToTheLeft:(id)sender {
    if ([self currentWritingDirection:self.textView] == UITextWritingDirectionRightToLeft) {
        [self goForwardOneParagraph];
    } else {
        [self goBackwardOneParagraph];
    }
}

#pragma mark - Direction Logic

- (UITextWritingDirection)currentWritingDirection:(id <UITextInput>)textInputObject {
    UITextWritingDirection writingDirection;
    @try {
        writingDirection = [textInputObject
                            baseWritingDirectionForPosition:textInputObject.selectedTextRange.start
                            inDirection:UITextStorageDirectionBackward];
    }
    @catch (NSException *exception) {
        writingDirection = UITextWritingDirectionLeftToRight;
    }
    @finally {
        //
    }
    return writingDirection;
}

- (void)goForwardOneCharacter {
    NSRange selectedRange = self.textView.selectedRange;
    if (selectedRange.location < self.textView.textStorage.string.length) {
        NSInteger location = [self indexOfNextCharacter];
        self.textView.selectedRange = NSMakeRange(location, 0);
    }
}

- (void)goForwardOneWord {
    NSInteger targetIndex = [self indexOfFirstSubsequentSpace];
    self.textView.selectedRange = NSMakeRange(targetIndex, 0);
}

- (void)goForwardOneParagraph {
    NSInteger targetIndex = [self indexOfFirstSubsequentLine];
    self.textView.selectedRange = NSMakeRange(targetIndex, 0);
}

- (void)goBackwardOneCharacter {
    NSRange selectedRange = self.textView.selectedRange;
    if (selectedRange.location > 0) {
        NSInteger location = [self indexOfPreviousCharacter];
        self.textView.selectedRange = NSMakeRange(location, 0);
    }
}

- (void)goBackwardOneWord {
    NSInteger targetIndex = [self indexOfFirstPreviousSpace];
    self.textView.selectedRange = NSMakeRange(targetIndex, 0);
}

- (void)goBackwardOneParagraph {
    NSInteger targetIndex = [self indexOfFirstPreviousLine];
    self.textView.selectedRange = NSMakeRange(targetIndex, 0);
}

#pragma mark - Index Logic

- (NSInteger)indexOfPreviousCharacter {
    
    __block NSInteger indexOfSpace = 0;
    
    [self.textView.textStorage.string
     enumerateSubstringsInRange:NSMakeRange(0, self.textView.selectedRange.location)
     options:NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences
     usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
         
         indexOfSpace = substringRange.location;
         *stop = YES;
         
     }];
    
    return indexOfSpace;
}

- (NSInteger)indexOfNextCharacter {
    
    __block BOOL nextCharacterReached = NO;
    __block BOOL indexChanged = NO;
    __block NSInteger indexOfSpace = self.textView.selectedRange.location;
    NSInteger length = self.textView.textStorage.string.length - self.textView.selectedRange.location;
    NSRange range = NSMakeRange(self.textView.selectedRange.location, length);
    
    [self.textView.textStorage.string
     enumerateSubstringsInRange:range
     options:NSStringEnumerationByComposedCharacterSequences
     usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
         
         if (nextCharacterReached) {
             indexChanged = YES;
             indexOfSpace = substringRange.location;
             *stop = YES;
         }
         nextCharacterReached = YES;
     }];
    
    if (indexChanged == NO) {
        indexOfSpace = self.textView.textStorage.string.length;
    }
    
    return indexOfSpace;
}

- (NSInteger)indexOfFirstPreviousSpace {
    
    __block NSInteger indexOfSpace = 0;
    
    [self.textView.textStorage.string
     enumerateSubstringsInRange:NSMakeRange(0, self.textView.selectedRange.location)
     options:NSStringEnumerationByWords | NSStringEnumerationReverse | NSStringEnumerationByComposedCharacterSequences
     usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
         
         indexOfSpace = substringRange.location;
         *stop = YES;
         
     }];
    
    return indexOfSpace;
}

- (NSInteger)indexOfFirstSubsequentSpace {
    
    __block BOOL firstWordFound = NO;
    __block BOOL indexChanged = NO;
    __block NSInteger indexOfSpace = self.textView.selectedRange.location;
    NSInteger length = self.textView.textStorage.string.length - self.textView.selectedRange.location;
    NSRange range = NSMakeRange(self.textView.selectedRange.location, length);
    
    [self.textView.textStorage.string
     enumerateSubstringsInRange:range
     options:NSStringEnumerationByWords
     usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
         
         if (firstWordFound) {
             indexChanged = YES;
             indexOfSpace = substringRange.location;
             *stop = YES;
         }
         firstWordFound = YES;
         
     }];
    
    if (indexChanged == NO) {
        indexOfSpace = self.textView.textStorage.string.length;
    }
    
    return indexOfSpace;
}

- (NSInteger)indexOfFirstPreviousLine {
    
    __block NSInteger indexOfSpace = 0;
    
    [self.textView.textStorage.string
     enumerateSubstringsInRange:NSMakeRange(0, self.textView.selectedRange.location)
     options:NSStringEnumerationByLines | NSStringEnumerationReverse
     usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
         
         indexOfSpace = substringRange.location;
         *stop = YES;
         
     }];
    
    return indexOfSpace;
}

- (NSInteger)indexOfFirstSubsequentLine {
    
    __block BOOL firstWordFound = NO;
    __block BOOL indexChanged = NO;
    __block NSInteger indexOfSpace = self.textView.selectedRange.location;
    
    NSInteger length = self.textView.textStorage.string.length - self.textView.selectedRange.location;
    NSRange range = NSMakeRange(self.textView.selectedRange.location, length);
    
    [self.textView.textStorage.string
     enumerateSubstringsInRange:range
     options:NSStringEnumerationByLines
     usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
         
         if (firstWordFound) {
             indexChanged = YES;
             indexOfSpace = substringRange.location;
             *stop = YES;
         }
         firstWordFound = YES;
     }];
    
    if (indexChanged == NO) {
        indexOfSpace = self.textView.textStorage.string.length;
    }
    
    return indexOfSpace;
}

@end


