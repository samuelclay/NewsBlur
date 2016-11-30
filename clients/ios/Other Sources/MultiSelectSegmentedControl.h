//
//  MultiSelectSegmentedControl.h
//
//  Created by Yonat Sharon on 19/4/13.
//
//  Multiple-Selection Segmented Control
//  No need for images - works with the builtin styles of UISegmentedControl.
//  To get/set multiple segments programmatically, use the property
//  myControl.selectedSegmentIndexes instead of myControl.selectedSegmentIndex
//

#import <UIKit/UIKit.h>

@class MultiSelectSegmentedControl;

@protocol MultiSelectSegmentedControlDelegate <NSObject>
-(void)multiSelect:(MultiSelectSegmentedControl*) multiSelecSegmendedControl didChangeValue:(BOOL) value atIndex: (NSUInteger) index;
@end

@interface MultiSelectSegmentedControl : UISegmentedControl

@property (nonatomic, assign) NSIndexSet *selectedSegmentIndexes;
@property (nonatomic, weak) id<MultiSelectSegmentedControlDelegate> delegate;
@property (nonatomic, readonly) NSArray *selectedSegmentTitles;
@property (nonatomic, assign) BOOL hideSeparatorBetweenSelectedSegments;

- (void)selectAllSegments:(BOOL)select; // pass NO to deselect all

@end
