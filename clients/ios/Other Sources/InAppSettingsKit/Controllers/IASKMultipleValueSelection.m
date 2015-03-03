#import "IASKMultipleValueSelection.h"

#import "IASKSettingsStore.h"
#import "IASKSettingsStoreUserDefaults.h"
#import "IASKSpecifier.h"
#import "IASKSettingsReader.h"

@implementation IASKMultipleValueSelection {
    NSInteger _checkedIndex;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userDefaultsDidChange)
                                                     name:NSUserDefaultsDidChangeNotification
                                                   object:[NSUserDefaults standardUserDefaults]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSUserDefaultsDidChangeNotification object:nil];
}

- (void)setSpecifier:(IASKSpecifier *)specifier {
    _specifier = specifier;
    [self updateCheckedItem];
}

- (NSIndexPath *)checkedItem {
    return [NSIndexPath indexPathForRow:_checkedIndex inSection:_section];;
}

- (void)updateCheckedItem {
    // Find the currently checked item
    id value = [self.settingsStore objectForKey:[_specifier key]];
    if (!value) {
        value = [_specifier defaultValue];
    }
    _checkedIndex = [[_specifier multipleValues] indexOfObject:value];
}

- (id<IASKSettingsStore>)settingsStore {
    if (_settingsStore == nil) {
        _settingsStore = [[IASKSettingsStoreUserDefaults alloc] init];
    }
    return _settingsStore;
}

#pragma mark - selection

- (void)selectRowAtIndexPath:(NSIndexPath *)indexPath {

    if (indexPath == self.checkedItem) {
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }

    NSArray *values = [_specifier multipleValues];

    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self deselectCell:[self.tableView cellForRowAtIndexPath:self.checkedItem]];
    [self selectCell:[self.tableView cellForRowAtIndexPath:indexPath]];
    _checkedIndex = indexPath.row;

    [self.settingsStore setObject:[values objectAtIndex:indexPath.row] forKey:[_specifier key]];
    [self.settingsStore synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:kIASKAppSettingChanged
                                                        object:[_specifier key]
                                                      userInfo:@{
                                                          _specifier.key: values[indexPath.row]
                                                      }];
};

- (void)updateSelectionInCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath {
    if ([indexPath isEqual:self.checkedItem]) {
        [self selectCell:cell];
    } else {
        [self deselectCell:cell];
    }
}

- (void)selectCell:(UITableViewCell *)cell {
    [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    IASK_IF_PRE_IOS7([[cell textLabel] setTextColor:kIASKgrayBlueColor];);
}

- (void)deselectCell:(UITableViewCell *)cell {
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    IASK_IF_PRE_IOS7([[cell textLabel] setTextColor:[UIColor darkTextColor]];);
}


#pragma mark Notifications

- (void)userDefaultsDidChange {
    NSIndexPath *oldCheckedItem = self.checkedItem;
    if (_specifier) {
        [self updateCheckedItem];
    }

    // only reload the table if it had changed; prevents animation cancellation
    if (![self.checkedItem isEqual:oldCheckedItem]) {
        [self.tableView reloadData];
    }
}

@end
