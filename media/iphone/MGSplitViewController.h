//
//  MGSplitViewController.h
//  MGSplitView
//
//  Created by Matt Gemmell on 26/07/2010.
//  Copyright 2010 Instinctive Code.
//

#import <UIKit/UIKit.h>

typedef enum _MGSplitViewDividerStyle {
	// These names have been chosen to be conceptually similar to those of NSSplitView on Mac OS X.
	MGSplitViewDividerStyleThin			= 0, // Thin divider, like UISplitViewController (default).
	MGSplitViewDividerStylePaneSplitter	= 1  // Thick divider, drawn with a grey gradient and a grab-strip.
} MGSplitViewDividerStyle;

@class MGSplitDividerView;
@protocol MGSplitViewControllerDelegate;
@interface MGSplitViewController : UIViewController <UIPopoverControllerDelegate> {
	BOOL _showsMasterInPortrait;
	BOOL _showsMasterInLandscape;
	float _splitWidth;
	id _delegate;
	BOOL _vertical;
	BOOL _masterBeforeDetail;
	NSMutableArray *_viewControllers;
	UIBarButtonItem *_barButtonItem; // To be compliant with wacky UISplitViewController behaviour.
    UIPopoverController *_hiddenPopoverController; // Popover used to hold the master view if it's not always visible.
	MGSplitDividerView *_dividerView; // View that draws the divider between the master and detail views.
	NSArray *_cornerViews; // Views to draw the inner rounded corners between master and detail views.
	float _splitPosition;
	BOOL _reconfigurePopup;
	MGSplitViewDividerStyle _dividerStyle; // Meta-setting which configures several aspects of appearance and behaviour.
}

@property (nonatomic, assign) IBOutlet id <MGSplitViewControllerDelegate> delegate;
@property (nonatomic, assign) BOOL showsMasterInPortrait; // applies to both portrait orientations (default NO)
@property (nonatomic, assign) BOOL showsMasterInLandscape; // applies to both landscape orientations (default YES)
@property (nonatomic, assign, getter=isVertical) BOOL vertical; // if NO, split is horizontal, i.e. master above detail (default YES)
@property (nonatomic, assign, getter=isMasterBeforeDetail) BOOL masterBeforeDetail; // if NO, master view is below/right of detail (default YES)
@property (nonatomic, assign) float splitPosition; // starting position of split in pixels, relative to top/left (depending on .isVertical setting) if masterBeforeDetail is YES, else relative to bottom/right.
@property (nonatomic, assign) float splitWidth; // width of split in pixels.
@property (nonatomic, assign) BOOL allowsDraggingDivider; // whether to let the user drag the divider to alter the split position (default NO).

@property (nonatomic, copy) NSArray *viewControllers; // array of UIViewControllers; master is at index 0, detail is at index 1.
@property (nonatomic, retain) IBOutlet UIViewController *masterViewController; // convenience.
@property (nonatomic, retain) IBOutlet UIViewController *detailViewController; // convenience.
@property (nonatomic, retain) MGSplitDividerView *dividerView; // the view which draws the divider/split between master and detail.
@property (nonatomic, assign) MGSplitViewDividerStyle dividerStyle; // style (and behaviour) of the divider between master and detail.

@property (nonatomic, readonly, getter=isLandscape) BOOL landscape; // returns YES if this view controller is in either of the two Landscape orientations, else NO.

// Actions
- (IBAction)toggleSplitOrientation:(id)sender; // toggles split axis between vertical (left/right; default) and horizontal (top/bottom).
- (IBAction)toggleMasterBeforeDetail:(id)sender; // toggles position of master view relative to detail view.
- (IBAction)toggleMasterView:(id)sender; // toggles display of the master view in the current orientation.
- (IBAction)showMasterPopover:(id)sender; // shows the master view in a popover spawned from the provided barButtonItem, if it's currently hidden.
- (void)notePopoverDismissed; // should rarely be needed, because you should not change the popover's delegate. If you must, then call this when it's dismissed.

// Conveniences for you, because I care.
- (BOOL)isShowingMaster;
- (void)setSplitPosition:(float)posn animated:(BOOL)animate; // Allows for animation of splitPosition changes. The property's regular setter is not animated.
/* Note:	splitPosition is the width (in a left/right split, or height in a top/bottom split) of the master view.
			It is relative to the appropriate side of the splitView, which can be any of the four sides depending on the values in isMasterBeforeDetail and isVertical:
				isVertical = YES, isMasterBeforeDetail = YES: splitPosition is relative to the LEFT edge. (Default)
				isVertical = YES, isMasterBeforeDetail = NO: splitPosition is relative to the RIGHT edge.
 				isVertical = NO, isMasterBeforeDetail = YES: splitPosition is relative to the TOP edge.
 				isVertical = NO, isMasterBeforeDetail = NO: splitPosition is relative to the BOTTOM edge.

			This implementation was chosen so you don't need to recalculate equivalent splitPositions if the user toggles masterBeforeDetail themselves.
 */
- (void)setDividerStyle:(MGSplitViewDividerStyle)newStyle animated:(BOOL)animate; // Allows for animation of dividerStyle changes. The property's regular setter is not animated.
- (NSArray *)cornerViews;
/*
 -cornerViews returns an NSArray of two MGSplitCornersView objects, used to draw the inner corners.
 The first view is the "leading" corners (top edge of screen for left/right split, left edge of screen for top/bottom split).
 The second view is the "trailing" corners (bottom edge of screen for left/right split, right edge of screen for top/bottom split).
 Do NOT modify them, except to:
	1. Change their .cornerBackgroundColor
	2. Change their .cornerRadius
 */

@end


@protocol MGSplitViewControllerDelegate

@optional

// Called when a button should be added to a toolbar for a hidden view controller.
- (void)splitViewController:(MGSplitViewController*)svc 
	 willHideViewController:(UIViewController *)aViewController 
		  withBarButtonItem:(UIBarButtonItem*)barButtonItem 
	   forPopoverController: (UIPopoverController*)pc;

// Called when the master view is shown again in the split view, invalidating the button and popover controller.
- (void)splitViewController:(MGSplitViewController*)svc 
	 willShowViewController:(UIViewController *)aViewController 
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem;

// Called when the master view is shown in a popover, so the delegate can take action like hiding other popovers.
- (void)splitViewController:(MGSplitViewController*)svc 
		  popoverController:(UIPopoverController*)pc 
  willPresentViewController:(UIViewController *)aViewController;

// Called when the split orientation will change (from vertical to horizontal, or vice versa).
- (void)splitViewController:(MGSplitViewController*)svc willChangeSplitOrientationToVertical:(BOOL)isVertical;

// Called when split position will change to the given pixel value (relative to left if split is vertical, or to top if horizontal).
- (void)splitViewController:(MGSplitViewController*)svc willMoveSplitToPosition:(float)position;

// Called before split position is changed to the given pixel value (relative to left if split is vertical, or to top if horizontal).
// Note that viewSize is the current size of the entire split-view; i.e. the area enclosing the master, divider and detail views.
- (float)splitViewController:(MGSplitViewController *)svc constrainSplitPosition:(float)proposedPosition splitViewSize:(CGSize)viewSize;

@end
