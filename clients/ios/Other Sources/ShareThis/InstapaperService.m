/* Copyright 2012 IGN Entertainment, Inc. */

#import "InstapaperService.h"
#import "KeychainItemWrapper.h"

//Instapaper:Successfully logged in, Pocket: Success
const int SUCCESS_LOGIN = 200;
//Instapaper Only:This URL has been successfully added to this Instapaper account.
const int SUCCESS_POSTED = 201;
//Instapaper: Invalid username or password
const int INVALID_LOGIN = 403;
//Instapaper Only:The service encountered an error. Please try again later.
const int SERVICE_ERROR = 500;
////Bad request or exceeded the rate limit. Probably missing a required parameter, such as url.
const int BAD_REQUEST_INSTAPAPER = 400;

NSString *const InstapaperIdentifier =
@"InstapaperLoginData";
NSString *const InstapaperActivity =
@"InstapaperActivity";

static InstapaperService *_manager;

#define instapaperApiPostUrl @"https://www.instapaper.com/api/add?username=%@&password=%@&url=%@&title=%@"
#define instapaperApiAuthenticateUrl @"https://www.instapaper.com/api/authenticate?username=%@&password=%@"

@interface InstapaperService()
@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSString *password;
@end

@implementation InstapaperService


+ (InstapaperService *)sharedManager
{
    if (!_manager) {
        _manager = [[InstapaperService alloc] init];
    }
    return _manager;
}

// Perform the read later service given.
+ (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    [[InstapaperService sharedManager] performReadLaterServiceWithParams:params];
}

- (void)performReadLaterServiceWithParams:(NSDictionary *)params
{
    self.params = params;
    KeychainItemWrapper *keychain =
    [[KeychainItemWrapper alloc] initWithIdentifier:InstapaperIdentifier accessGroup:nil];
    
    [self performAlertViewUsingKeychain:keychain];
}

#pragma mark Login Service
// Perform login action for the given service
- (void)loginWithUsername:(NSString *)username password:(NSString *)password
{
    self.username = username;
    self.password = password;
    NSString *urlString = [NSString stringWithFormat:instapaperApiAuthenticateUrl, self.username, self.password];;
    [self performConnectionToUrl:[NSURL URLWithString:urlString]];
}

#pragma mark Log out service
// Log out by deleting the keychain item in the keychain
- (void)logOutOfService
{
    KeychainItemWrapper *keychain =
    [[KeychainItemWrapper alloc] initWithIdentifier:InstapaperIdentifier accessGroup:nil];
    
    [keychain resetKeychainItem];
}

#pragma mark Post to service
// Post the url and title to service
- (void)postToService
{
    KeychainItemWrapper *keychain =
    [[KeychainItemWrapper alloc] initWithIdentifier:InstapaperIdentifier accessGroup:nil];
    
    self.username = [keychain objectForKey:(__bridge id)kSecAttrAccount];
    self.password = [keychain objectForKey:(__bridge id)kSecValueData];
    NSString *urlString = [NSString stringWithFormat:instapaperApiPostUrl, self.username, self.password, self.url, self.articleTitle];
    
    [self performConnectionToUrl:[NSURL URLWithString:urlString]];
}

// Handle the status code given from the response in a nsurlconnection
- (void)handleStatusCode
{
    KeychainItemWrapper *keychain =
    [[KeychainItemWrapper alloc] initWithIdentifier:InstapaperIdentifier accessGroup:nil];
    switch (self.statusCode) {
        case SUCCESS_LOGIN:
            [keychain setObject:self.username forKey:(__bridge id)kSecAttrAccount];
            [keychain setObject:self.password forKey:(__bridge id)kSecValueData];
            // Directly post to service after a successful login
            [self postToService];
            break;
        case SUCCESS_POSTED:
            [self showAlertMessageWithTitle:@"Success" Message:@"Successfully Added!"];
            break;
        case BAD_REQUEST_INSTAPAPER:
            [self showAlertMessageWithTitle:@"Error" Message:@"Bad Request"];
            break;
        case INVALID_LOGIN:
            [self showAlertMessageWithTitle:@"Error" Message:@"Invalid Username or Password"];
            break;
        case SERVICE_ERROR:
            [self showAlertMessageWithTitle:@"Error" Message:@"Service encountered an error. Please try again later."];
            break;
        default:
            break;
    }
}

@end
