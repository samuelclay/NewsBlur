//
//  OSKShareableContentItem.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

extern NSString * const OSKShareableContentItemType_MicroblogPost;
extern NSString * const OSKShareableContentItemType_Facebook;
extern NSString * const OSKShareableContentItemType_BlogPost;
extern NSString * const OSKShareableContentItemType_Email;
extern NSString * const OSKShareableContentItemType_SMS;
extern NSString * const OSKShareableContentItemType_PhotoSharing;
extern NSString * const OSKShareableContentItemType_CopyToPasteboard;
extern NSString * const OSKShareableContentItemType_ReadLater;
extern NSString * const OSKShareableContentItemType_LinkBookmark;
extern NSString * const OSKShareableContentItemType_WebBrowser;
extern NSString * const OSKShareableContentItemType_PasswordManagementAppSearch;
extern NSString * const OSKShareableContentItemType_ToDoListEntry;
extern NSString * const OSKShareableContentItemType_AirDrop;
extern NSString * const OSKShareableContentItemType_TextEditing;

///---------------------------
/// @name Abstract Base Class
///---------------------------

/**
 An abstract base class for the many kinds of shareable content items.
 
 @discussion Never instantiate `OSKShareableContentItem` directly. You must use it via
 a subclass (either built-in or one of your own).
 
 @see OSKShareableContent
 */
@interface OSKShareableContentItem : NSObject

/**
 An alternate name to be used in place of the default name of any `<OSKActivity>` that
 is handling the content item. The default is `nil`.
 
 @discussion Useful for when you need multiple instances of the same content item, e.g.
 in Riposte, we have "Email Post" and "Email Conversation" in the
 conversation share sheet. If you don't set an alternate activity name, then the
 `<OSKActivity>`'s default name and icon will be used instead.
 
 If all you need to do is localize an activity name, it is better to do that
 via the `customizationsDelegate` of `OSKPresentationManager`.
 */
@property (copy, nonatomic) NSString *alternateActivityName;

/**
 An alternate icon to be displayed in place of the default icon of any `<OSKActivity>` that
 is handling the content item. The default is `nil`.
 */
@property (strong, nonatomic) UIImage *alternateActivityIcon;

/**
 Returns either one of the officially supported item types listed above,
 or a custom item type.
 
 @warning Required. Subclasses must override without calling super.
 */
- (NSString *)itemType;

/**
 Additional activity-specific or contextual info.
 
 @discussion Third-party apps & services vary widely in the extra features they
 offer. Facebook is *in general* a microblogging activity, like ADN and Twitter,
 but in practice it has a few advanced needs. Rather than add dozens of properties 
 that are each only used by a single activity type, it makes more sense use an 
 NSMutableDictionary to store activity-specific or app-specific contextual info.
 
 To avoid conflicts, keys in this dictionary should be namespaced as follows:
 
 com.<application>.<activityName>.<key>
 
 For example, the key to an NSDictionary of Facebook post attributes would use
 a protected namespace as follows:
 
 com.oversharekit.facebook.userInfo
 
 Let's say there's an app called Foo.app that has integrated OvershareKit.
 It has also written a bespoke OSKActivity subclass, "FOOSelfieActivity." This
 activity is a microblogging activity, but it needs additional data to submit a post.
 It could add an NSDictionary of custom attributes to the userInfo dictionary 
 with the following key:
 
 com.fooapp.selfie.userInfo
 
 This would allow Foo.app to add the Selfie activity without having to make awkward
 modifications to their OSK integration.
 
 As OvershareKit matures, we may occasionally promote frequently-used data types
 stored in userInfo dictionaries to class-level @properties.
 */
@property (copy, nonatomic, readonly) NSMutableDictionary *userInfo;

@end

///---------------------------------------------------
/// @name Microblog Posts (Twitter, App.net)
///---------------------------------------------------

/**
 Content for sharing to microblogging services like Twitter or App.net.
 */
@interface OSKMicroblogPostContentItem : OSKShareableContentItem

/**
 The plain-text content of the outgoing post. Must not be nil.
 */
@property (copy, nonatomic) NSString *text;

/**
 An optional array of `<UIImage>` objects to be attached to the outgoing post.
 
 @discussion Not all activities support multiple images. Those that do not will simply
 ignore all but the first image in the array when creating a new post.
 */
@property (strong, nonatomic) NSArray *images;

/**
 The latitude component of the user's geolocation.
 */
@property (nonatomic, assign) double latitude;

/**
 The longitude component of the user's geolocation.
 */
@property (nonatomic, assign) double longitude;

@end

///---------------------------------------------------
/// @name Facebook
///---------------------------------------------------

/**
 Text content. The user should be provided an opportunity to edit this text prior to 
 publishing, per Facebook's API terms.
 */
@interface OSKFacebookContentItem : OSKShareableContentItem

/**
 The plain-text content of the outgoing post. Must not be nil.
 */
@property (copy, nonatomic) NSString *text;

/**
 Facebook link posts require a URL separate from the post text.
 */
@property (copy, nonatomic) NSURL *link;

/**
 An optional array of `<UIImage>` objects to be attached to the outgoing post.
 */
@property (strong, nonatomic) NSArray *images;

/**
 The latitude component of the user's geolocation.
 */
@property (nonatomic, assign) double latitude;

/**
 The longitude component of the user's geolocation.
 */
@property (nonatomic, assign) double longitude;

@end

///-----------------------------------------
/// @name Blog Posts (Tumblr)
///-----------------------------------------

/**
 Content for sharing to blogging services like Tumblr or WordPress.
 
 @warning As of October 31, 2013, no activities in Overshare Kit are using this item.
 */
@interface OSKBlogPostContentItem : OSKShareableContentItem

/**
 The plain-text content of the blog post. Must not be nil.
 */
@property (copy, nonatomic) NSString *text;

/**
 An optional array of `<UIImage>` objects to be attached to the outgoing post.
 */
@property (strong, nonatomic) NSArray *images;

/**
 An optional array of `NSString` tags for tagging the outgoing post.
 */
@property (strong, nonatomic) NSArray *tags;

/**
 An optional flag for creating the post in the drafts queue instead of immediately publishing the post.
 
 Defaults to NO (publishes immediately).
 */
@property (assign, nonatomic) BOOL publishAsDraft;

@end

///-----------------------------------------
/// @name Email
///-----------------------------------------

/**
 Content for creating a new email message.
 */
@interface OSKEmailContentItem : OSKShareableContentItem

/**
 An array of email addresses for the "to:" field. Optional.
 */
@property (copy, nonatomic) NSArray *toRecipients;

/**
 An array of email addresses for the "cc:" field. Optional.
 */
@property (copy, nonatomic) NSArray *ccRecipients;

/**
 An array of email addresses for the "bcc:" field. Optional.
 */
@property (copy, nonatomic) NSArray *bccRecipients;

/**
 A plain-text subject for the email. Optional.
 */
@property (copy, nonatomic) NSString *subject;

/**
 The body text for the outgoing email. May be plain text or HTML markup. 
 
 If HTML, the `isHTML` property must set to `YES`.
 */
@property (copy, nonatomic) NSString *body;

/**
 Flags whether or not the `body` contents are HTML markup.
 */
@property (assign, nonatomic) BOOL isHTML;

/**
 An array of `UIImage` objects to attach to the outgoing message.
 */
@property (copy, nonatomic) NSArray *attachments;

@end

///-----------------------------------------
/// @name SMS & iMessage
///-----------------------------------------

/**
 Content for sharing via iMessage or SMS.
 */
@interface OSKSMSContentItem : OSKShareableContentItem

/**
 An array of recipient phone numbers or email addresses. Optional.
 */
@property (copy, nonatomic) NSArray *recipients;

/**
 The plain-text content of the outgoing message.
 */
@property (copy, nonatomic) NSString *body;

/**
 An array of `UIImage` objects to attach to the outgoing message.
 */
@property (copy, nonatomic) NSArray *attachments;

@end

///-----------------------------------------
/// @name Photo Sharing (Instagram, etc.)
///-----------------------------------------

/**
 Content for sharing to photo services like Instagram or Flickr.
 */
@interface OSKPhotoSharingContentItem : OSKShareableContentItem

/**
 An array of one or more `UIImage` objects.
 */
@property (copy, nonatomic) NSArray *images;

/**
 A plain-text caption to be applied to all the images.
 */
@property (copy, nonatomic) NSString *caption;

/**
 The latitude component of the user's location.
 */
@property (nonatomic, assign) double latitude;

/**
 The longitude component of the user's location.
 */
@property (nonatomic, assign) double longitude;

@end

///-----------------------------------------
/// @name Copy-to-Pasteboard
///-----------------------------------------

/**
 Content for saving to the system pasteboard.
 */
@interface OSKCopyToPasteboardContentItem : OSKShareableContentItem

/**
 Plain text content for copying & pasting. Setting this property will set all
 other properties to nil.
 */
@property (copy, nonatomic) NSString *text;

/**
 Image content for copying & pasting. Setting this property will set all
 other properties to nil. 
 */
@property (copy, nonatomic) NSArray *images;

@end

///---------------------------------------------
/// @name Read Later (Instapaper, Pocket, etc.)
///---------------------------------------------

/**
 Content for sending to read-later services like Instapaper or Pocket.
 */
@interface OSKReadLaterContentItem : OSKShareableContentItem

/**
 The url to be saved. Must be set to a non-nil value before sharing.
 */
@property (copy, nonatomic) NSURL *url;

/**
 An optional title. Not all activities use this.
 */
@property (copy, nonatomic) NSString *title;

/**
 An optional description. Not all activities use this.
 */
@property (copy, nonatomic) NSString *description;

@end

///-----------------------------------------
/// @name Link Bookmarking (Pinboard)
///-----------------------------------------

/**
 Content for sending to link-bookmarking services like Pinboard.
 */
@interface OSKLinkBookmarkContentItem : OSKShareableContentItem

/**
 The url to be saved. Required.
 */
@property (copy, nonatomic) NSURL *url;

/**
 The title of the bookmark. Optional.
 
 If left blank, `OSKPinboardActivity` will attempt to fetch
 the page title before sending the link to Pinboard.
 */
@property (copy, nonatomic) NSString *title;

/**
 Optional plain-text notes describing the link.
 */
@property (copy, nonatomic) NSString *notes;

/**
 Option to flag a saved item as "to-read." 
 
 Not all services may support this flag. At the very least, Pinboard does. It is
 recommended to set this to YES (it is YES by default).
 */
@property (assign, nonatomic) BOOL markToRead;

/**
 Optional array of tags for the saved item.
 */
@property (copy, nonatomic) NSArray *tags;

@end

///--------------------------------------------
/// @name Web Browsers (Safari.app, Chrome.app)
///--------------------------------------------

/**
 Content that can be opened in another app's web browser.
 */
@interface OSKWebBrowserContentItem : OSKShareableContentItem

/**
 The url to opened. Required.
 */
@property (copy, nonatomic) NSURL *url;

@end

///-----------------------------------------
/// @name 1Password Searches
///-----------------------------------------

/**
 Content for performing a search in a password management app like 1Password.
 */
@interface OSKPasswordManagementAppSearchContentItem : OSKShareableContentItem

/**
 The search query.
 */
@property (copy, nonatomic) NSString *query;

@end

///-----------------------------------------------
/// @name Creating To-Do Items (OmniFocus, Things)
///-----------------------------------------------

/**
 Content for creating a new to-do item in a task management app like OmniFocus or Things.
 */
@interface OSKToDoListEntryContentItem : OSKShareableContentItem

/**
 The title of the entry. Required.
 */
@property (copy, nonatomic) NSString *title;

/**
 Optional notes for the body of the entry.
 */
@property (copy, nonatomic) NSString *notes;

@end

///-----------------------------------------
/// @name AirDrop
///-----------------------------------------

/**
 Content that can be shared via AirDrop.
 */
@interface OSKAirDropContentItem : OSKShareableContentItem

/**
 The items in this array should be the same items that you would pass to an
 instance of `UIActivityViewController`.
 */
@property (copy, nonatomic) NSArray *items;

@end

///-------------------------------------------------------
/// @name Text-Editing (Drafts, Editorial, Evernote etc.)
///-------------------------------------------------------

/**
 Content for creating a new text editing document.
 */
@interface OSKTextEditingContentItem : OSKShareableContentItem

/**
 The body text. Required.
 */
@property (copy, nonatomic) NSString *text;

/**
 Optional title of the entry. Some apps don't support title fields.
 */
@property (copy, nonatomic) NSString *title;

/**
 Optional image attachements for the new entry. Not all apps support images. Those that
 do may not support multiple images.
 */
@property (copy, nonatomic) NSArray *images;

/**
 Optional tags for the new entry. Not all apps support tags. Those that
 do may not support multiple tags.
 */
@property (copy, nonatomic) NSArray *tags;

@end



