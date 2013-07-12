/* Copyright 2012 IGN Entertainment, Inc. */

#import "PocketService.h"
#import "KeychainItemWrapper.h"
#import "ShareThis.h"

//Success login or success posted
const int SUCCESS = 200;
//Instapaper and Pocket: Bad request or exceeded the rate limit. Probably missing a required parameter, such as url.
const int BAD_REQUEST_POCKET = 400;
//Pocket Only: Invalid username or password
const int INVALID_LOGIN_POCKET = 401;
//Rate limit exceeded
const int RATE_LIMIT_ERROR = 403;
//Read It Later's sync server is down for scheduled maintenance.
const int SERVER_SYNC_ERROR = 503;

NSString *const PocketIdentifier =
@"PocketLoginData";
NSString *const PocketActivity =
@"PocketActivity";

static PocketService *_manager;

#define pocketApiAuthenticateUrl @"https://readitlaterlist.com/v2/auth?username=%@&password=%@&apikey=%@"
#define pocketApiPostUrl @"https://readitlaterlist.com/v2/add?username=%@&password=%@&apikey=%@&url=%@&title=%@"

@interface PocketService()
@property (strong, nonatomic) NSString *username;
@property (strong, nonatomic) NSString *password;
@end

@implementation PocketService


+ (PocketService *)sharedManager
{
    if (!_manager) {
        _manager = [[PocketService alloc] init];
    }
    return _manager;
}

+ (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    [[PocketService sharedManager] performReadLaterServiceWithParams:params];
}

- (void)setParams:(NSDictionary *)params
{
    // Set the url and title from the passed in parameters
    if (params) {
        self.url = [[params objectForKey:@"url"] absoluteString];
        self.articleTitle = [[params objectForKey:@"title"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
}

- (void)performReadLaterServiceWithParams:(NSDictionary *)params
{
    self.params = params;
    KeychainItemWrapper *keychain =
    [[KeychainItemWrapper alloc] initWithIdentifier:PocketIdentifier accessGroup:nil];
    
    [self performAlertViewUsingKeychain:keychain];
}

#pragma mark Login Service
// Perform login action for the given service
- (void)loginWithUsername:(NSString *)username password:(NSString *)password
{
    self.username = username;
    self.password = password;

    NSString *urlString = [NSString stringWithFormat:pocketApiAuthenticateUrl, self.username, self.password, [[ShareThis sharedManager] pocketAPIKey]];;
    [self performConnectionToUrl:[NSURL URLWithString:urlString]];
}

#pragma mark Log out service
// Log out by deleting the keychain item in the keychain
- (void)logOutOfService
{
    KeychainItemWrapper *keychain =
    [[KeychainItemWrapper alloc] initWithIdentifier:PocketIdentifier accessGroup:nil];
    
    [keychain resetKeychainItem];
}

#pragma mark Post to service
// Post the url and title to the given service using the login credentials
- (void)postToService
{
    KeychainItemWrapper *keychain =
    [[KeychainItemWrapper alloc] initWithIdentifier:PocketIdentifier accessGroup:nil];
    
    self.username = [keychain objectForKey:(__bridge id)kSecAttrAccount];
    self.password = [keychain objectForKey:(__bridge id)kSecValueData];
    NSString *urlString = [NSString stringWithFormat:pocketApiPostUrl, self.username, self.password, [[ShareThis sharedManager] pocketAPIKey], self.url, self.articleTitle];
    
    [self performConnectionToUrl:[NSURL URLWithString:urlString]];
}

// Handle the status code given from the response in a nsurlconnection
- (void)handleStatusCode
{
    KeychainItemWrapper *keychain =
    [[KeychainItemWrapper alloc] initWithIdentifier:PocketIdentifier accessGroup:nil];
    switch (self.statusCode) {
        case SUCCESS:
            // Pocket uses the same status code for both login success and success posted
            if (![[keychain objectForKey:(__bridge id) kSecAttrAccount] isEqualToString:@""]
                && [keychain objectForKey:(__bridge id)kSecValueData]) {
                [self showAlertMessageWithTitle:@"Success" Message:@"Successfully Added!"];
            } else {
                [keychain setObject:self.username forKey:(__bridge id)kSecAttrAccount];
                [keychain setObject:self.password forKey:(__bridge id)kSecValueData];
                // Directly post to service after a successful login
                [self postToService];
            }
            break;
        case BAD_REQUEST_POCKET:
            [self showAlertMessageWithTitle:@"Error" Message:@"Bad Request"];
            break;
        case INVALID_LOGIN_POCKET:
            [self showAlertMessageWithTitle:@"Error" Message:@"Invalid Username or Password"];
            break;
        case RATE_LIMIT_ERROR:
            [self showAlertMessageWithTitle:@"Error" Message:@"Rate limit exceeded. Please try again later."];
            break;
        case SERVER_SYNC_ERROR:
            [self showAlertMessageWithTitle:@"Error" Message:@"Service encountered an error. Please try again later."];
            break;
        default:
            break;
    }
}
@end
