//
//  OSKActivityCollectionViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/12/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKActivityCollectionViewController.h"

#import "OSKActivityCollectionViewCell.h"
#import "OSKPagedHorizontalLayout.h"

@interface OSKActivityCollectionViewController () <OSKPagedHorizontalLayoutDelegate>

@property (weak, nonatomic) id <OSKActivityCollectionViewControllerDelegate> delegate;
@property (assign, nonatomic) NSInteger currentPage;

@end

@implementation OSKActivityCollectionViewController

- (instancetype)initWithActivities:(NSArray *)activities delegate:(id<OSKActivityCollectionViewControllerDelegate>)delegate {
    OSKPagedHorizontalLayout *flowLayout = [[OSKPagedHorizontalLayout alloc] init];
    self = [super initWithCollectionViewLayout:flowLayout];
    if (self) {
        [flowLayout setOskDelegate:self];
        _activities = activities;
        _delegate = delegate;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.scrollEnabled = YES;
    self.collectionView.pagingEnabled = YES;
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 16.0, 0, 16.0);
    self.collectionView.shouldGroupAccessibilityChildren = YES;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UINib *nib = [UINib nibWithNibName:@"OSKActivityCollectionViewCell_Pad" bundle:nil];
        [self.collectionView registerNib:nib forCellWithReuseIdentifier:OSKActivityCollectionViewCellIdentifier];
    } else {
        UINib *nib = [UINib nibWithNibName:@"OSKActivityCollectionViewCell" bundle:nil];
        [self.collectionView registerNib:nib forCellWithReuseIdentifier:OSKActivityCollectionViewCellIdentifier];
    }
}

- (void)osk_invalidateLayout {
    [self.collectionViewLayout invalidateLayout];
    [self.collectionView setContentOffset:CGPointZero animated:YES];
}

- (NSInteger)numberOfVisibleActivitiesPerRow {
    CGSize size = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                    ? OSKActivityCollectionViewCellSize_Pad
                    : OSKActivityCollectionViewCellSize_Phone;
    return floor(self.view.frame.size.width / size.width);
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.activities.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    OSKActivityCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:OSKActivityCollectionViewCellIdentifier forIndexPath:indexPath];
    OSKActivity *activity = [self.activities objectAtIndex:indexPath.row];
    [cell setActivity:activity];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    [self.delegate activityCollection:self didSelectActivity:_activities[indexPath.row]];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSInteger pageIndex = round(scrollView.contentOffset.x / self.view.frame.size.width);
    pageIndex = MAX(MIN(pageIndex, [self numberOfPages]-1), 0);
    [self setCurrentPage:pageIndex];
}

- (void)setCurrentPage:(NSInteger)currentPage {
    if (_currentPage != currentPage) {
        _currentPage = currentPage;
        [self.delegate activityCollection:self didScrollToPageIndex:_currentPage];
    }
}

- (NSInteger)numberOfPages {
    return [(OSKPagedHorizontalLayout *)self.collectionView.collectionViewLayout numberOfPages];
}

- (void)scrollToPage:(NSInteger)pageIndex {
    pageIndex = MAX(MIN(pageIndex, [self numberOfPages]-1), 0);
    CGFloat xOffset = self.view.frame.size.width * pageIndex;
    [self.collectionView setContentOffset:CGPointMake(xOffset, 0) animated:YES];
}

#pragma mark - Paged Horizontal Layout Delegate

- (NSInteger)numberOfItemsForLayout:(OSKPagedHorizontalLayout *)layout {
    return _activities.count;
}

- (CGSize)itemSizeForLayout:(OSKPagedHorizontalLayout *)layout {
    CGSize size = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                    ? OSKActivityCollectionViewCellSize_Pad
                    : OSKActivityCollectionViewCellSize_Phone;
    return size;
}

- (UIEdgeInsets)insetsForLayout:(OSKPagedHorizontalLayout *)layout {
    return UIEdgeInsetsMake(0, 8.0f, 0, 8.0f);
}

- (CGSize)availablePageSizeForLayout:(OSKPagedHorizontalLayout *)layout {
    return self.view.frame.size;
}

- (void)layout:(OSKPagedHorizontalLayout *)layout didChangeNumberOfPages:(NSInteger)numberOfPages {
    [self.delegate activityCollection:self didChangeNumberOfPages:numberOfPages];
    self.collectionView.delaysContentTouches = (numberOfPages > 1);
}

@end




