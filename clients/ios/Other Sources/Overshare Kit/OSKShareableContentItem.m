//
//  OSKShareableContentItem.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKShareableContentItem.h"

NSString * const OSKShareableContentItemType_MicroblogPost = @"OSKShareableContentItemType_MicroblogPost";
NSString * const OSKShareableContentItemType_Facebook = @"OSKShareableContentItemType_Facebook";
NSString * const OSKShareableContentItemType_BlogPost = @"OSKShareableContentItemType_BlogPost";
NSString * const OSKShareableContentItemType_Email = @"OSKShareableContentItemType_Email";
NSString * const OSKShareableContentItemType_SMS = @"OSKShareableContentItemType_SMS";
NSString * const OSKShareableContentItemType_PhotoSharing = @"OSKShareableContentItemType_PhotoSharing";
NSString * const OSKShareableContentItemType_CopyToPasteboard = @"OSKShareableContentItemType_CopyToPasteboard";
NSString * const OSKShareableContentItemType_ReadLater = @"OSKShareableContentItemType_ReadLater";
NSString * const OSKShareableContentItemType_LinkBookmark = @"OSKShareableContentItemType_LinkBookmark";
NSString * const OSKShareableContentItemType_WebBrowser = @"OSKShareableContentItemType_WebBrowser";
NSString * const OSKShareableContentItemType_PasswordManagementAppSearch = @"OSKShareableContentItemType_PasswordManagementAppSearch";
NSString * const OSKShareableContentItemType_ToDoListEntry = @"OSKShareableContentItemType_ToDoListEntry";
NSString * const OSKShareableContentItemType_AirDrop = @"OSKShareableContentItemType_AirDrop";
NSString * const OSKShareableContentItemType_TextEditing = @"OSKShareableContentItemType_TextEditing";

@implementation OSKShareableContentItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _userInfo = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (NSString *)itemType {
    NSAssert(NO, @"OSKShareableContentItem subclasses must override itemType without calling super.");
    return nil;
}

@end

@implementation OSKMicroblogPostContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_MicroblogPost;
}

@end

@implementation OSKFacebookContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_Facebook;
}

@end

@implementation OSKBlogPostContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_BlogPost;
}

@end

@implementation OSKEmailContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_Email;
}

@end

@implementation OSKSMSContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_SMS;
}

@end

@implementation OSKPhotoSharingContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_PhotoSharing;
}

@end

@implementation OSKCopyToPasteboardContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_CopyToPasteboard;
}

- (void)setText:(NSString *)text {
    _text = [text copy];
    if (_text) {
        [self setImages:nil];
    }
}

- (void)setImages:(NSArray *)images {
    _images = [images copy];
    if (_images) {
        [self setText:nil];
    }
}

@end

@implementation OSKReadLaterContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_ReadLater;
}

@end

@implementation OSKLinkBookmarkContentItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _markToRead = YES;
    }
    return self;
}

- (NSString *)itemType {
    return OSKShareableContentItemType_LinkBookmark;
}

@end

@implementation OSKWebBrowserContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_WebBrowser;
}

@end

@implementation OSKPasswordManagementAppSearchContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_PasswordManagementAppSearch;
}

@end

@implementation OSKToDoListEntryContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_ToDoListEntry;
}

@end

@implementation OSKAirDropContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_AirDrop;
}

@end

@implementation OSKTextEditingContentItem

- (NSString *)itemType {
    return OSKShareableContentItemType_TextEditing;
}

@end

