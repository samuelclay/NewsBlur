//
//  StoryPageControl.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "StoryPageControl.h"
#import "StoryDetailViewController.h"
#import "PagerViewController.h"

@implementation StoryPageControl

@synthesize appDelegate;
@synthesize currentPage, nextPage;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
	currentPage = [[StoryDetailViewController alloc] initWithNibName:@"StoryDetailViewController" bundle:nil];
	nextPage = [[StoryDetailViewController alloc] initWithNibName:@"StoryDetailViewController" bundle:nil];
    currentPage.appDelegate = appDelegate;
    nextPage.appDelegate = appDelegate;
	[self.scrollView addSubview:currentPage.view];
	[self.scrollView addSubview:nextPage.view];
    [self.scrollView setPagingEnabled:YES];
	[self.scrollView setScrollEnabled:YES];
	[self.scrollView setShowsHorizontalScrollIndicator:NO];
	[self.scrollView setShowsVerticalScrollIndicator:NO];
//    [self.scrollView setDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated {
    NSInteger widthCount = self.appDelegate.originalStoryCount;
	if (widthCount == 0) {
		widthCount = 1;
	}
    
    currentPage.view.frame = self.scrollView.frame;
    nextPage.view.frame = self.scrollView.frame;
    
    self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width
                                             * widthCount,
                                             self.scrollView.frame.size.height);
	self.scrollView.contentOffset = CGPointMake(0, 0);
    
	[self applyNewIndex:0 pageController:currentPage];
	[self applyNewIndex:1 pageController:nextPage];
}

- (void)applyNewIndex:(NSInteger)newIndex pageController:(StoryDetailViewController *)pageController
{
	NSInteger pageCount = appDelegate.originalStoryCount;
	BOOL outOfBounds = newIndex >= pageCount || newIndex < 0;
    
	if (!outOfBounds) {
		CGRect pageFrame = pageController.view.frame;
		pageFrame.origin.y = 0;
		pageFrame.origin.x = self.scrollView.frame.size.width * newIndex;
		pageController.view.frame = pageFrame;
	} else {
		CGRect pageFrame = pageController.view.frame;
		pageFrame.origin.y = self.scrollView.frame.size.height;
		pageController.view.frame = pageFrame;
	}
    
	pageController.pageIndex = newIndex;
    
    appDelegate.activeStory = [[appDelegate activeFeedStories] objectAtIndex:pageController.pageIndex];
    [pageController setActiveStory];
    [pageController initStory];
}

- (void)scrollViewDidScroll:(UIScrollView *)sender
{
    [sender setContentOffset:CGPointMake(sender.contentOffset.x, 0)];
    CGFloat pageWidth = self.scrollView.frame.size.width;
    float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
	
	NSInteger lowerNumber = floor(fractionalPage);
	NSInteger upperNumber = lowerNumber + 1;
	
//    NSLog(@"Scroll to %@", NSStringFromCGPoint(sender.contentOffset));
    
	if (lowerNumber == currentPage.pageIndex)
	{
		if (upperNumber != nextPage.pageIndex)
		{
			[self applyNewIndex:upperNumber pageController:nextPage];
		}
	}
	else if (upperNumber == currentPage.pageIndex)
	{
		if (lowerNumber != nextPage.pageIndex)
		{
			[self applyNewIndex:lowerNumber pageController:nextPage];
		}
	}
	else
	{
		if (lowerNumber == nextPage.pageIndex)
		{
			[self applyNewIndex:upperNumber pageController:currentPage];
		}
		else if (upperNumber == nextPage.pageIndex)
		{
			[self applyNewIndex:lowerNumber pageController:currentPage];
		}
		else
		{
			[self applyNewIndex:lowerNumber pageController:currentPage];
			[self applyNewIndex:upperNumber pageController:nextPage];
		}
	}
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)newScrollView
{
    CGFloat pageWidth = self.scrollView.frame.size.width;
    float fractionalPage = self.scrollView.contentOffset.x / pageWidth;
	NSInteger nearestNumber = lround(fractionalPage);
    
	if (currentPage.pageIndex != nearestNumber)
	{
		StoryDetailViewController *swapController = currentPage;
		currentPage = nextPage;
		nextPage = swapController;
	}
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)newScrollView
{
	[self scrollViewDidEndScrollingAnimation:newScrollView];
	self.pageControl.currentPage = currentPage.pageIndex;
}

- (IBAction)changePage:(id)sender
{
	NSInteger pageIndex = self.pageControl.currentPage;
    
	// update the scroll view to the appropriate page
    CGRect frame = self.scrollView.frame;
    frame.origin.x = frame.size.width * pageIndex;
    frame.origin.y = 0;
    [self.scrollView scrollRectToVisible:frame animated:YES];
}

@end
