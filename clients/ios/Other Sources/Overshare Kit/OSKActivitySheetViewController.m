//
//  OSKActivitySheetViewController.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKActivitySheetViewController.h"

#import "OSKActivitySheetDelegate.h"
#import "OSKActivityCollectionViewController.h"
#import "OSKBorderedButton.h"
#import "OSKPresentationManager.h"
#import "NSString+OSK_UUID.h"
#import "OSKLogger.h"
#import "UIColor+OSKUtility.h"

static CGFloat OSKActivitySheetViewControllerSheetHeight_OneRow_Phone = 224.0f;
static CGFloat OSKActivitySheetViewControllerSheetHeight_TwoRows_Phone = 320.0f;
static CGFloat OSKActivitySheetViewControllerSheetHeight_ThreeRows_Phone = 416.0f;

static CGFloat OSKActivitySheetViewControllerSheetHeight_OneRow_Pad = 178.0f;
static CGFloat OSKActivitySheetViewControllerSheetHeight_TwoRows_Pad = 290.0f;
static CGFloat OSKActivitySheetViewControllerSheetHeight_ThreeRows_Pad = 402.0f;

static CGFloat OSKActivitySheetViewControllerSheetHeight_PaddingForPageControl = 13.0f;

static NSInteger OSKActivitySheetViewController_MaxItemsPerPageInPopover = 12;

static CGFloat OSKActivitySheetViewControllerCollectionViewHeight_OneRow_Phone = 96.0f;
static CGFloat OSKActivitySheetViewControllerCollectionViewHeight_TwoRows_Phone = 192.0f;
static CGFloat OSKActivitySheetViewControllerCollectionViewHeight_ThreeRows_Phone = 288.0f;

static CGFloat OSKActivitySheetViewControllerCollectionViewHeight_OneRow_Pad = 112.0f;
static CGFloat OSKActivitySheetViewControllerCollectionViewHeight_TwoRows_Pad = 224.0f;
static CGFloat OSKActivitySheetViewControllerCollectionViewHeight_ThreeRows_Pad = 336.0f;

@interface OSKActivitySheetViewController () <OSKActivityCollectionViewControllerDelegate>

@property (weak, nonatomic) IBOutlet UIView *sheetContainerView;
@property (weak, nonatomic) IBOutlet UIView *cancellationView;
@property (weak, nonatomic) IBOutlet UIView *topShadowLine;
@property (weak, nonatomic) IBOutlet UIView *collectionViewContainer;
@property (weak, nonatomic) IBOutlet UIPageControl *pageControl;
@property (weak, nonatomic) IBOutlet OSKBorderedButton *cancelButton;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@property (strong, nonatomic, readwrite) OSKSession *session;
@property (strong, nonatomic) OSKShareableContent *content;
@property (strong, nonatomic) NSArray *activities;
@property (strong, nonatomic) OSKActivityCollectionViewController *collectionViewController;
@property (weak, nonatomic, readwrite) id <OSKActivitySheetDelegate> delegate;
@property (assign, nonatomic) BOOL hidePageControl;
@property (assign, nonatomic) BOOL usePopoverLayout;

@end

@implementation OSKActivitySheetViewController

- (instancetype)initWithSession:(OSKSession *)session
                     activities:(NSArray *)activities
                       delegate:(id<OSKActivitySheetDelegate>)delegate
               usePopoverLayout:(BOOL)usePopoverLayout {
    
    self = [super initWithNibName:@"OSKActivitySheetViewController" bundle:nil];
    if (self) {
        _session = session;
        _delegate = delegate;
        _activities = activities.copy;
        _usePopoverLayout = usePopoverLayout;
    }
    return self;
}

- (BOOL)shouldAutomaticallyForwardAppearanceMethods {
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.pageControl addTarget:self action:@selector(pageControlChanged:) forControlEvents:UIControlEventValueChanged];
    [self setupGestureRecognizers];
    [self setupCollectionViews];
    [self adjustFonts];
    [self updateColors];
    [self.titleLabel setText:self.title];
    [self setupLocalizationAndAccessibility];
    [self.collectionViewController.collectionView setClipsToBounds:NO];
    [self.collectionViewContainer setClipsToBounds:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.collectionViewController viewDidAppear:animated];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.titleLabel);
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.collectionViewController viewDidDisappear:animated];
}

- (void)viewDidLayoutSubviews {
    [self osk_updateLayout];
}

- (void)osk_updateLayout {
    if (self.usePopoverLayout) {
        self.topShadowLine.hidden = YES;
        self.cancelButton.hidden = YES;
        self.cancellationView.hidden = YES;
        
        [self.sheetContainerView setFrame:self.view.bounds];
        
        CGRect collectionViewContainerFrame = self.collectionViewContainer.frame;
        collectionViewContainerFrame.size.height = [self collectionViewHeightForCurrentLayout];
        [self.collectionViewContainer setFrame:collectionViewContainerFrame];
        
        CGFloat pageControlCenterX = roundf(self.view.bounds.size.width/2.0f);
        CGFloat pageControlCenterY = roundf(self.view.bounds.size.height - OSKActivitySheetViewControllerSheetHeight_PaddingForPageControl*1.5f)+0.5f; // default page control height is odd
        [self.pageControl setCenter:CGPointMake(pageControlCenterX, pageControlCenterY)];
    }
    else {
        CGFloat targetSheetHeight = [self visibleSheetHeightForCurrentLayout];
        CGRect sheetFrame = self.sheetContainerView.frame;
        sheetFrame.size.height = targetSheetHeight;
        sheetFrame.origin.y = self.view.bounds.size.height - targetSheetHeight;
        [self.sheetContainerView setFrame:sheetFrame];
        
        CGRect collectionViewContainerFrame = self.collectionViewContainer.frame;
        collectionViewContainerFrame.size.height = [self collectionViewHeightForCurrentLayout];
        [self.collectionViewContainer setFrame:collectionViewContainerFrame];
        
        CGRect cancellationViewFrame = self.cancellationView.frame;
        cancellationViewFrame.size.height = self.sheetContainerView.frame.origin.y;
        [self.cancellationView setFrame:cancellationViewFrame];
        
        [self.collectionViewController osk_invalidateLayout];
        
        CGRect shadowLineFrame = self.topShadowLine.frame;
        CGFloat lineThickness = ([[UIScreen mainScreen] scale] > 1) ? 0.5f : 1.0f;
        shadowLineFrame.origin.y = -lineThickness;
        shadowLineFrame.size.height = lineThickness;
        [self.topShadowLine setFrame:shadowLineFrame];
    }
}

- (void)setupGestureRecognizers {
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] init];
    [tapRecognizer addTarget:self action:@selector(dismissGestureRecognized:)];
    [self.cancellationView addGestureRecognizer:tapRecognizer];
    
    UISwipeGestureRecognizer *swipeDownRecognizer = [[UISwipeGestureRecognizer alloc] init];
    swipeDownRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    [swipeDownRecognizer addTarget:self action:@selector(dismissGestureRecognized:)];
    [self.cancellationView addGestureRecognizer:swipeDownRecognizer];
}

- (void)setupCollectionViews {
    OSKActivityCollectionViewController *collectionViewController = nil;
    collectionViewController = [[OSKActivityCollectionViewController alloc] initWithActivities:self.activities delegate:self];
    [self addChildViewController:collectionViewController];
    [collectionViewController.view setFrame:self.collectionViewContainer.bounds];
    [self.collectionViewContainer addSubview:collectionViewController.view];
    [collectionViewController didMoveToParentViewController:self];
    [self setCollectionViewController:collectionViewController];
}

- (void)setupLocalizationAndAccessibility {
    OSKPresentationManager *presManager = [OSKPresentationManager sharedInstance];
    
    NSString *cancelTitle = [presManager localizedText_Cancel];
    [self.cancelButton setTitle:cancelTitle forState:UIControlStateNormal];
}

- (void)adjustFonts {
    UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
    if (descriptor) {
        [self.titleLabel setFont:[UIFont fontWithDescriptor:descriptor size:14]];
        [self.cancelButton.titleLabel setFont:[UIFont fontWithDescriptor:descriptor size:19]];
    }
}

- (void)updateColors {
    OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
    
    UIColor *currentPageDot = [presentationManager color_pageIndicatorColor_current];
    UIColor *otherPageDot = [presentationManager color_pageIndicatorColor_other];
    UIColor *textColor = [presentationManager color_text];
    UIColor *actionColor = [presentationManager color_action];
    UIColor *shadowColor = [presentationManager color_activitySheetTopLine];
    
    [self.pageControl setCurrentPageIndicatorTintColor:currentPageDot];
    [self.pageControl setPageIndicatorTintColor:otherPageDot];
    [self.cancelButton setTintColor:actionColor];
    [self.titleLabel setTextColor:textColor];
    [self.topShadowLine setBackgroundColor:shadowColor];
    
    if (self.usePopoverLayout) {
        self.sheetContainerView.backgroundColor = [UIColor clearColor];
    } else {
        UIColor *bgColor = [presentationManager color_translucentBackground];
        self.sheetContainerView.backgroundColor = bgColor;
    }
}

- (CGSize)preferredContentSize {
    CGFloat width = (self.usePopoverLayout) ? 384.0f : 320.0f;
    return CGSizeMake(width, [self visibleSheetHeightForCurrentLayout]);
}

- (CGFloat)visibleSheetHeightForCurrentLayout {
    CGFloat height;
    NSInteger maxNumberOfRows = [self maxNumberOfRowsForCurrentLayout];
    if (self.usePopoverLayout) {
        switch (maxNumberOfRows) {
            case 1: {
                height = OSKActivitySheetViewControllerSheetHeight_OneRow_Pad;
            } break;
            case 2: {
                height = OSKActivitySheetViewControllerSheetHeight_TwoRows_Pad;
            } break;
            case 3: {
                height = OSKActivitySheetViewControllerSheetHeight_ThreeRows_Pad;
            } break;
            default:
                height = OSKActivitySheetViewControllerSheetHeight_ThreeRows_Pad;
                break;
        }
        if (self.activities.count > OSKActivitySheetViewController_MaxItemsPerPageInPopover) {
            height += OSKActivitySheetViewControllerSheetHeight_PaddingForPageControl;
        }
    } else {
        switch (maxNumberOfRows) {
            case 1: {
                height = OSKActivitySheetViewControllerSheetHeight_OneRow_Phone;
            } break;
            case 2: {
                height = OSKActivitySheetViewControllerSheetHeight_TwoRows_Phone;
            } break;
            case 3: {
                height = OSKActivitySheetViewControllerSheetHeight_ThreeRows_Phone;
            } break;
            default:
                height = OSKActivitySheetViewControllerSheetHeight_ThreeRows_Phone;
                break;
        }
    }
    
    if (self.hidePageControl) {
        height -= OSKActivitySheetViewControllerSheetHeight_PaddingForPageControl;
    }
    
    return height;
}

- (CGFloat)collectionViewHeightForCurrentLayout {
    CGFloat height;
    NSInteger maxNumberOfRows = [self maxNumberOfRowsForCurrentLayout];
    
    if (self.usePopoverLayout) {
        switch (maxNumberOfRows) {
            case 1: {
                height = OSKActivitySheetViewControllerCollectionViewHeight_OneRow_Pad;
            } break;
            case 2: {
                height = OSKActivitySheetViewControllerCollectionViewHeight_TwoRows_Pad;
            } break;
            case 3: {
                height = OSKActivitySheetViewControllerCollectionViewHeight_ThreeRows_Pad;
            } break;
            default:
                height = OSKActivitySheetViewControllerCollectionViewHeight_ThreeRows_Pad;
                break;
        }
    } else {
        switch (maxNumberOfRows) {
            case 1: {
                height = OSKActivitySheetViewControllerCollectionViewHeight_OneRow_Phone;
            } break;
            case 2: {
                height = OSKActivitySheetViewControllerCollectionViewHeight_TwoRows_Phone;
            } break;
            case 3: {
                height = OSKActivitySheetViewControllerCollectionViewHeight_ThreeRows_Phone;
            } break;
            default:
                height = OSKActivitySheetViewControllerCollectionViewHeight_ThreeRows_Phone;
                break;
        }
    }
    
    return height;
}

- (NSInteger)maxNumberOfRowsForCurrentLayout {
    NSInteger rows = 3;
    CGFloat myHeight = self.view.bounds.size.height;
    
    if (self.usePopoverLayout) {
        if (myHeight >= OSKActivitySheetViewControllerSheetHeight_ThreeRows_Pad) {
            rows = 3;
        }
        else if (myHeight >= OSKActivitySheetViewControllerSheetHeight_TwoRows_Pad) {
            rows = 2;
        }
        else {
            rows = 1;
        }
    } else {
        // Preserve some space above the sheet.
        myHeight -= 44.0f;
        
        if (myHeight >= OSKActivitySheetViewControllerSheetHeight_ThreeRows_Phone) {
            rows = 3;
        }
        else if (myHeight >= OSKActivitySheetViewControllerSheetHeight_TwoRows_Phone) {
            rows = 2;
        }
        else {
            rows = 1;
        }
    }
    
    NSInteger numberOfActivitiesPerRow = [self.collectionViewController numberOfVisibleActivitiesPerRow];
    NSInteger actualRows = ceil((self.activities.count*1.0f) / (numberOfActivitiesPerRow*1.0f));
    
    if (actualRows < rows) {
        rows = actualRows;
    }
    
    return rows;
}

- (IBAction)cancelButtonPressed:(id)sender {
    [self dismissActivitySheet];
}

- (void)dismissGestureRecognized:(UIGestureRecognizer *)recognizer {
    CGPoint location = [recognizer locationInView:self.view];
    if (CGRectContainsPoint(self.sheetContainerView.frame, location) == NO) {
        [self dismissActivitySheet];
    }
}

- (void)dismissActivitySheet {
    [self.delegate activitySheetDidCancel:self];
}

#pragma mark - Page Control Taps 

- (void)pageControlChanged:(UIPageControl *)control {
    NSInteger newIndex = [control currentPage];
    [self.collectionViewController scrollToPage:newIndex];
}

#pragma mark - Hiding Page Control

- (void)setHidePageControl:(BOOL)hidePageControl {
    if (_hidePageControl != hidePageControl) {
        _hidePageControl = hidePageControl;
        self.pageControl.hidden = _hidePageControl;
        [self osk_updateLayout];
    }
}

#pragma mark - Collection View Delegate

- (void)activityCollection:(OSKActivityCollectionViewController *)viewController didSelectActivity:(OSKActivity *)activity {
    [self.delegate activitySheet:self didSelectActivity:activity];
}

- (void)activityCollection:(OSKActivityCollectionViewController *)viewController didScrollToPageIndex:(NSInteger)pageIndex {
    [self.pageControl setCurrentPage:pageIndex];
}

- (void)activityCollection:(OSKActivityCollectionViewController *)viewController didChangeNumberOfPages:(NSInteger)numberOfPages {
    [self.pageControl setNumberOfPages:[self.collectionViewController numberOfPages]];
    [self setHidePageControl:(numberOfPages <= 1)];
}

@end






