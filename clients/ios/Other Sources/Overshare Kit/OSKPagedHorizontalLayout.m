//
//  OSKPagedHorizontalLayout.m
//  Overshare
//
//  Created by Jared Sinclair on 10/14/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKPagedHorizontalLayout.h"

@interface OSKPagedHorizontalLayout ()

@property (assign, nonatomic) CGFloat availableWidth;
@property (assign, nonatomic) CGFloat availableHeight;
@property (assign, nonatomic) UIEdgeInsets edgeInsets;
@property (strong, nonatomic) NSArray *attributes;
@property (assign, nonatomic) NSInteger numberOfPages;

@end

@implementation OSKPagedHorizontalLayout

#pragma mark - Required Methods

- (CGSize)collectionViewContentSize {
    NSInteger totalItemCount = [self.oskDelegate numberOfItemsForLayout:self];
    CGFloat totalWidth = [self totalWidth];
    CGFloat availableWidth = [self availableWidth];
    CGFloat availableHeight = [self availableHeight];
    CGSize itemSize = [self.oskDelegate itemSizeForLayout:self];
    
    NSInteger numberOfPages;
    NSInteger numberOfCols;
    NSInteger numberOfRows;
    NSInteger itemsPerPage;
    
    numberOfCols = floor(availableWidth / itemSize.width);
    numberOfRows = floor(availableHeight / itemSize.height);
    itemsPerPage = numberOfRows * numberOfCols;
    numberOfPages = MAX(1,ceil((totalItemCount*1.0f) / (itemsPerPage*1.0f)));
    
    [self setNumberOfPages:numberOfPages];
    
    return CGSizeMake(totalWidth * numberOfPages, self.availableHeight);
}

- (void)prepareLayout {
    _attributes = [self repopulateAttributes];
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
    NSMutableArray *matches = [[NSMutableArray alloc] init];
    for (UICollectionViewLayoutAttributes *anAttribute in _attributes) {
        if (CGRectIntersectsRect(rect, anAttribute.frame)) {
            [matches addObject:anAttribute];
        }
    }
    return matches;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    return _attributes[indexPath.row];
}

#pragma mark - Calculations

- (UIEdgeInsets)edgeInsets {
    return [self.oskDelegate insetsForLayout:self];
}

- (CGFloat)availableWidth {
    UIEdgeInsets insets = [self edgeInsets];
    return [self totalWidth] - insets.left - insets.right;
}

- (CGFloat)availableHeight {
    return [self.oskDelegate availablePageSizeForLayout:self].height;
}

- (CGFloat)totalWidth {
    return [self.oskDelegate availablePageSizeForLayout:self].width;
}

- (void)setNumberOfPages:(NSInteger)numberOfPages {
    if (_numberOfPages != numberOfPages) {
        _numberOfPages = numberOfPages;
        [self.oskDelegate layout:self didChangeNumberOfPages:_numberOfPages];
    }
}

- (NSArray *)repopulateAttributes {
    NSMutableArray *newAttributes = [[NSMutableArray alloc] init];
    
    NSInteger totalItemCount = [self.oskDelegate numberOfItemsForLayout:self];
    CGFloat leftInset = [self edgeInsets].left;
    CGFloat totalWidth = [self totalWidth];
    CGFloat availableWidth = [self availableWidth];
    CGFloat availableHeight = [self availableHeight];
    CGSize itemSize = [self.oskDelegate itemSizeForLayout:self];
    
    NSInteger numberOfPages;
    NSInteger numberOfCols;
    NSInteger numberOfRows;
    NSInteger itemsPerPage;
    
    numberOfCols = MAX(1,floor(availableWidth / itemSize.width));
    numberOfRows = MAX(1,floor(availableHeight / itemSize.height));
    itemsPerPage = numberOfRows * numberOfCols;
    numberOfPages = MAX(1,ceil((totalItemCount*1.0f) / (itemsPerPage*1.0f)));
    
    [self setNumberOfPages:numberOfPages];
    
    CGFloat interItemSpacing = 0;
    CGFloat lastColItemSpacing = 0;
    
    if (totalItemCount > 1) {
        CGFloat totalInterItemSpace = availableWidth - (numberOfCols * itemSize.width);
        interItemSpacing = roundf(totalInterItemSpace / (numberOfCols-1.0f));
        if (numberOfCols > 2) {
            lastColItemSpacing = totalInterItemSpace - (interItemSpacing * (numberOfCols-2.0));
        } else {
            lastColItemSpacing = interItemSpacing;
        }
    }
    
    NSInteger actualIndex = 0;
    
    for (NSInteger pageIndex = 0; pageIndex < numberOfPages; pageIndex++) {
        CGFloat xOffset = leftInset + pageIndex*totalWidth;
        NSInteger rowIndex = 0;
        NSInteger colIndex = 0;
        NSInteger itemsThisPage = [self numberOfItemsForPage:pageIndex
                                               numberOfPages:numberOfPages
                                              totalItemCount:totalItemCount
                                                itemsPerPage:itemsPerPage];
        for (NSInteger relativeIndex = 0; relativeIndex < itemsThisPage; relativeIndex++) {
            CGFloat xOrigin = xOffset + colIndex*itemSize.width;
            if (colIndex > 0) {
                if (numberOfCols == 2) {
                    xOrigin += lastColItemSpacing;
                }
                else if (colIndex == numberOfCols-1) {
                    xOrigin += (interItemSpacing*(colIndex-1)) + lastColItemSpacing;
                }
                else {
                    xOrigin += interItemSpacing * colIndex;
                }
            }
            CGFloat yOrigin = rowIndex * itemSize.height;
            CGPoint targetOrigin = CGPointMake(xOrigin, yOrigin);
            
            UICollectionViewLayoutAttributes *attributes = [self newAttributesForTargetOrigin:targetOrigin
                                                                                     itemSize:itemSize
                                                            indexPath:[NSIndexPath indexPathForRow:actualIndex inSection:0]];
            [newAttributes addObject:attributes];
            
            colIndex++;
            actualIndex++;
            
            if (colIndex >= numberOfCols) {
                colIndex = 0;
                rowIndex++;
            }
        }
    }
    
    return newAttributes;
}

- (NSInteger)numberOfItemsForPage:(NSInteger)pageIndex numberOfPages:(NSInteger)numberOfPages totalItemCount:(NSInteger)totalItemCount itemsPerPage:(NSInteger)itemsPerPage {
    NSInteger number;
    if (totalItemCount <= itemsPerPage) {
        number = totalItemCount;
    }
    else if (pageIndex == numberOfPages-1) {
        number = totalItemCount - (pageIndex * itemsPerPage);
    }
    else {
        number = itemsPerPage;
    }
    return number;
}

- (UICollectionViewLayoutAttributes *)newAttributesForTargetOrigin:(CGPoint)targetOrigin itemSize:(CGSize)size indexPath:(NSIndexPath *)indexPath {
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attributes.frame = CGRectMake(targetOrigin.x, targetOrigin.y, size.width, size.height);
    attributes.alpha = 1.0f;
    attributes.hidden = NO;
    return attributes;
}

@end











