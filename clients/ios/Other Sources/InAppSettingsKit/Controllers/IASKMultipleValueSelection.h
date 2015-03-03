#import <UIKit/UIKit.h>

@class IASKSpecifier;
@protocol IASKSettingsStore;

/// Encapsulates the selection among multiple values.
/// This is used for PSMultiValueSpecifier and PSRadioGroupSpecifier
@interface IASKMultipleValueSelection : NSObject

@property (nonatomic, assign) UITableView *tableView;
@property (nonatomic, retain) IASKSpecifier *specifier;
@property (nonatomic, assign) NSInteger section;
@property (nonatomic, copy, readonly) NSIndexPath *checkedItem;
@property (nonatomic, strong) id<IASKSettingsStore> settingsStore;

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)updateSelectionInCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath;

@end
