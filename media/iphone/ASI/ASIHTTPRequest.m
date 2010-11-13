//
//  ASIHTTPRequest.m
//
//  Created by Ben Copsey on 04/10/2007.
//  Copyright 2007-2010 All-Seeing Interactive. All rights reserved.
//
//  A guide to the main features is available at:
//  http://allseeing-i.com/ASIHTTPRequest
//
//  Portions are based on the ImageClient example from Apple:
//  See: http://developer.apple.com/samplecode/ImageClient/listing37.html

#import "ASIHTTPRequest.h"
#import <zlib.h>
#if TARGET_OS_IPHONE
#import "Reachability.h"
#import "ASIAuthenticationDialog.h"
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <SystemConfiguration/SystemConfiguration.h>
#endif
#import "ASIInputStream.h"


// Automatically set on build
NSString *ASIHTTPRequestVersion = @"v1.7-56 2010-08-30";

NSString* const NetworkRequestErrorDomain = @"ASIHTTPRequestErrorDomain";

static NSString *ASIHTTPRequestRunLoopMode = @"ASIHTTPRequestRunLoopMode";

static const CFOptionFlags kNetworkEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;

// In memory caches of credentials, used on when useSessionPersistence is YES
static NSMutableArray *sessionCredentialsStore = nil;
static NSMutableArray *sessionProxyCredentialsStore = nil;

// This lock mediates access to session credentials
static NSRecursiveLock *sessionCredentialsLock = nil;

// We keep track of cookies we have received here so we can remove them from the sharedHTTPCookieStorage later
static NSMutableArray *sessionCookies = nil;

// The number of times we will allow requests to redirect before we fail with a redirection error
const int RedirectionLimit = 5;

// The default number of seconds to use for a timeout
static NSTimeInterval defaultTimeOutSeconds = 10;

static void ReadStreamClientCallBack(CFReadStreamRef readStream, CFStreamEventType type, void *clientCallBackInfo) {
    [((ASIHTTPRequest*)clientCallBackInfo) handleNetworkEvent: type];
}

// This lock prevents the operation from being cancelled while it is trying to update the progress, and vice versa
static NSRecursiveLock *progressLock;

static NSError *ASIRequestCancelledError;
static NSError *ASIRequestTimedOutError;
static NSError *ASIAuthenticationError;
static NSError *ASIUnableToCreateRequestError;
static NSError *ASITooMuchRedirectionError;

static NSMutableArray *bandwidthUsageTracker = nil;
static unsigned long averageBandwidthUsedPerSecond = 0;

static SEL queueRequestStartedSelector = nil;
static SEL queueRequestReceivedResponseHeadersSelector = nil;
static SEL queueRequestFinishedSelector = nil;
static SEL queueRequestFailedSelector = nil;


// These are used for queuing persistent connections on the same connection

// Incremented every time we specify we want a new connection
static unsigned int nextConnectionNumberToCreate = 0;

// An array of connectionInfo dictionaries.
// When attempting a persistent connection, we look here to try to find an existing connection to the same server that is currently not in use
static NSMutableArray *persistentConnectionsPool = nil;

// Mediates access to the persistent connections pool
static NSRecursiveLock *connectionsLock = nil;

// Each request gets a new id, we store this rather than a ref to the request itself in the connectionInfo dictionary.
// We do this so we don't have to keep the request around while we wait for the connection to expire
static unsigned int nextRequestID = 0;

// Records how much bandwidth all requests combined have used in the last second
static unsigned long bandwidthUsedInLastSecond = 0; 

// A date one second in the future from the time it was created
static NSDate *bandwidthMeasurementDate = nil;

// Since throttling variables are shared among all requests, we'll use a lock to mediate access
static NSLock *bandwidthThrottlingLock = nil;

// the maximum number of bytes that can be transmitted in one second
static unsigned long maxBandwidthPerSecond = 0;

// A default figure for throttling bandwidth on mobile devices
unsigned long const ASIWWANBandwidthThrottleAmount = 14800;

#if TARGET_OS_IPHONE
// YES when bandwidth throttling is active
// This flag does not denote whether throttling is turned on - rather whether it is currently in use
// It will be set to NO when throttling was turned on with setShouldThrottleBandwidthForWWAN, but a WI-FI connection is active
static BOOL isBandwidthThrottled = NO;

// When YES, bandwidth will be automatically throttled when using WWAN (3G/Edge/GPRS)
// Wifi will not be throttled
static BOOL shouldThrottleBandwithForWWANOnly = NO;
#endif

// Mediates access to the session cookies so requests
static NSRecursiveLock *sessionCookiesLock = nil;

// This lock ensures delegates only receive one notification that authentication is required at once
// When using ASIAuthenticationDialogs, it also ensures only one dialog is shown at once
// If a request can't aquire the lock immediately, it means a dialog is being shown or a delegate is handling the authentication challenge
// Once it gets the lock, it will try to look for existing credentials again rather than showing the dialog / notifying the delegate
// This is so it can make use of any credentials supplied for the other request, if they are appropriate
static NSRecursiveLock *delegateAuthenticationLock = nil;

// When throttling bandwidth, Set to a date in future that we will allow all requests to wake up and reschedule their streams
static NSDate *throttleWakeUpTime = nil;

static id <ASICacheDelegate> defaultCache = nil;


// Used for tracking when requests are using the network
static unsigned int runningRequestCount = 0;


// You can use [ASIHTTPRequest setShouldUpdateNetworkActivityIndicator:NO] if you want to manage it yourself
// Alternatively, override showNetworkActivityIndicator / hideNetworkActivityIndicator
// By default this does nothing on Mac OS X, but again override the above methods for a different behaviour
static BOOL shouldUpdateNetworkActivityIndicator = YES;


//**Queue stuff**/

// The thread all requests will run on
// Hangs around forever, but will be blocked unless there are requests underway
static NSThread *networkThread = nil;

static NSOperationQueue *sharedQueue = nil;

// Private stuff
@interface ASIHTTPRequest ()

- (void)cancelLoad;

- (void)destroyReadStream;
- (void)scheduleReadStream;
- (void)unscheduleReadStream;

- (BOOL)askDelegateForCredentials;
- (BOOL)askDelegateForProxyCredentials;
+ (void)measureBandwidthUsage;
+ (void)recordBandwidthUsage;
- (void)startRequest;
- (void)updateStatus:(NSTimer *)timer;
- (void)checkRequestStatus;

- (void)markAsFinished;
- (void)performRedirect;
- (BOOL)shouldTimeOut;


- (BOOL)useDataFromCache;

// Called to update the size of a partial download when starting a request, or retrying after a timeout
- (void)updatePartialDownloadSize;

#if TARGET_OS_IPHONE
+ (void)registerForNetworkReachabilityNotifications;
+ (void)unsubscribeFromNetworkReachabilityNotifications;
// Called when the status of the network changes
+ (void)reachabilityChanged:(NSNotification *)note;

- (void)failAuthentication;

#endif

@property (assign) BOOL complete;
@property (retain) NSArray *responseCookies;
@property (assign) int responseStatusCode;
@property (retain, nonatomic) NSDate *lastActivityTime;
@property (assign) unsigned long long contentLength;
@property (assign) unsigned long long partialDownloadSize;
@property (assign, nonatomic) unsigned long long uploadBufferSize;
@property (assign) NSStringEncoding responseEncoding;
@property (retain, nonatomic) NSOutputStream *postBodyWriteStream;
@property (retain, nonatomic) NSInputStream *postBodyReadStream;
@property (assign) unsigned long long totalBytesRead;
@property (assign) unsigned long long totalBytesSent;
@property (assign, nonatomic) unsigned long long lastBytesRead;
@property (assign, nonatomic) unsigned long long lastBytesSent;
@property (retain) NSRecursiveLock *cancelledLock;
@property (retain, nonatomic) NSOutputStream *fileDownloadOutputStream;
@property (assign) int authenticationRetryCount;
@property (assign) int proxyAuthenticationRetryCount;
@property (assign, nonatomic) BOOL updatedProgress;
@property (assign, nonatomic) BOOL needsRedirect;
@property (assign, nonatomic) int redirectCount;
@property (retain, nonatomic) NSData *compressedPostBody;
@property (retain, nonatomic) NSString *compressedPostBodyFilePath;
@property (retain) NSString *authenticationRealm;
@property (retain) NSString *proxyAuthenticationRealm;
@property (retain) NSString *responseStatusMessage;
@property (assign) BOOL inProgress;
@property (assign) int retryCount;
@property (assign) BOOL connectionCanBeReused;
@property (retain, nonatomic) NSMutableDictionary *connectionInfo;
@property (retain, nonatomic) NSInputStream *readStream;
@property (assign) ASIAuthenticationState authenticationNeeded;
@property (assign, nonatomic) BOOL readStreamIsScheduled;
@property (assign, nonatomic) BOOL downloadComplete;
@property (retain) NSNumber *requestID;
@property (assign, nonatomic) NSString *runLoopMode;
@property (retain, nonatomic) NSTimer *statusTimer;
@property (assign) BOOL didUseCachedResponse;
@end


@implementation ASIHTTPRequest

#pragma mark init / dealloc

+ (void)initialize
{
	if (self == [ASIHTTPRequest class]) {
		queueRequestStartedSelector = @selector(requestStarted:);
		queueRequestReceivedResponseHeadersSelector = @selector(requestReceivedResponseHeaders:);
		queueRequestFinishedSelector = @selector(requestFinished:);
		queueRequestFailedSelector = @selector(requestFailed:);
		persistentConnectionsPool = [[NSMutableArray alloc] init];
		connectionsLock = [[NSRecursiveLock alloc] init];
		progressLock = [[NSRecursiveLock alloc] init];
		bandwidthThrottlingLock = [[NSLock alloc] init];
		sessionCookiesLock = [[NSRecursiveLock alloc] init];
		sessionCredentialsLock = [[NSRecursiveLock alloc] init];
		delegateAuthenticationLock = [[NSRecursiveLock alloc] init];
		bandwidthUsageTracker = [[NSMutableArray alloc] initWithCapacity:5];
		ASIRequestTimedOutError = [[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIRequestTimedOutErrorType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The request timed out",NSLocalizedDescriptionKey,nil]] retain];	
		ASIAuthenticationError = [[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIAuthenticationErrorType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Authentication needed",NSLocalizedDescriptionKey,nil]] retain];
		ASIRequestCancelledError = [[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIRequestCancelledErrorType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The request was cancelled",NSLocalizedDescriptionKey,nil]] retain];
		ASIUnableToCreateRequestError = [[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIUnableToCreateRequestErrorType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Unable to create request (bad url?)",NSLocalizedDescriptionKey,nil]] retain];
		ASITooMuchRedirectionError = [[NSError errorWithDomain:NetworkRequestErrorDomain code:ASITooMuchRedirectionErrorType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The request failed because it redirected too many times",NSLocalizedDescriptionKey,nil]] retain];	

		sharedQueue = [[NSOperationQueue alloc] init];
		[sharedQueue setMaxConcurrentOperationCount:4];

	}
}


- (id)initWithURL:(NSURL *)newURL
{
	self = [self init];
	[self setRequestMethod:@"GET"];

	[self setRunLoopMode:NSDefaultRunLoopMode];
	[self setShouldAttemptPersistentConnection:YES];
	[self setPersistentConnectionTimeoutSeconds:60.0];
	[self setShouldPresentCredentialsBeforeChallenge:YES];
	[self setShouldRedirect:YES];
	[self setShowAccurateProgress:YES];
	[self setShouldResetDownloadProgress:YES];
	[self setShouldResetUploadProgress:YES];
	[self setAllowCompressedResponse:YES];
	[self setDefaultResponseEncoding:NSISOLatin1StringEncoding];
	[self setShouldPresentProxyAuthenticationDialog:YES];
	
	[self setTimeOutSeconds:[ASIHTTPRequest defaultTimeOutSeconds]];
	[self setUseSessionPersistence:YES];
	[self setUseCookiePersistence:YES];
	[self setValidatesSecureCertificate:YES];
	[self setRequestCookies:[[[NSMutableArray alloc] init] autorelease]];
	[self setDidStartSelector:@selector(requestStarted:)];
	[self setDidReceiveResponseHeadersSelector:@selector(requestReceivedResponseHeaders:)];
	[self setDidFinishSelector:@selector(requestFinished:)];
	[self setDidFailSelector:@selector(requestFailed:)];
	[self setDidReceiveDataSelector:@selector(request:didReceiveData:)];
	[self setURL:newURL];
	[self setCancelledLock:[[[NSRecursiveLock alloc] init] autorelease]];
	[self setDownloadCache:[[self class] defaultCache]];
	return self;
}

+ (id)requestWithURL:(NSURL *)newURL
{
	return [[[self alloc] initWithURL:newURL] autorelease];
}

+ (id)requestWithURL:(NSURL *)newURL usingCache:(id <ASICacheDelegate>)cache
{
	return [self requestWithURL:newURL usingCache:cache andCachePolicy:ASIDefaultCachePolicy];
}

+ (id)requestWithURL:(NSURL *)newURL usingCache:(id <ASICacheDelegate>)cache andCachePolicy:(ASICachePolicy)policy
{
	ASIHTTPRequest *request = [[[self alloc] initWithURL:newURL] autorelease];
	[request setDownloadCache:cache];
	[request setCachePolicy:policy];
	return request;
}

- (void)dealloc
{
	[self setAuthenticationNeeded:ASINoAuthenticationNeededYet];
	if (requestAuthentication) {
		CFRelease(requestAuthentication);
	}
	if (proxyAuthentication) {
		CFRelease(proxyAuthentication);
	}
	if (request) {
		CFRelease(request);
	}
	if (clientCertificateIdentity) {
		CFRelease(clientCertificateIdentity);
	}
	[self cancelLoad];
	[queue release];
	[userInfo release];
	[postBody release];
	[compressedPostBody release];
	[error release];
	[requestHeaders release];
	[requestCookies release];
	[downloadDestinationPath release];
	[temporaryFileDownloadPath release];
	[fileDownloadOutputStream release];
	[username release];
	[password release];
	[domain release];
	[authenticationRealm release];
	[authenticationScheme release];
	[requestCredentials release];
	[proxyHost release];
	[proxyType release];
	[proxyUsername release];
	[proxyPassword release];
	[proxyDomain release];
	[proxyAuthenticationRealm release];
	[proxyAuthenticationScheme release];
	[proxyCredentials release];
	[url release];
	[originalURL release];
	[lastActivityTime release];
	[responseCookies release];
	[rawResponseData release];
	[responseHeaders release];
	[requestMethod release];
	[cancelledLock release];
	[postBodyFilePath release];
	[compressedPostBodyFilePath release];
	[postBodyWriteStream release];
	[postBodyReadStream release];
	[PACurl release];
	[clientCertificates release];
	[responseStatusMessage release];
	[connectionInfo release];
	[requestID release];
	[super dealloc];
}

#pragma mark setup request

- (void)addRequestHeader:(NSString *)header value:(NSString *)value
{
	if (!requestHeaders) {
		[self setRequestHeaders:[NSMutableDictionary dictionaryWithCapacity:1]];
	}
	[requestHeaders setObject:value forKey:header];
}

// This function will be called either just before a request starts, or when postLength is needed, whichever comes first
// postLength must be set by the time this function is complete
- (void)buildPostBody
{
	if ([self haveBuiltPostBody]) {
		return;
	}
	
	// Are we submitting the request body from a file on disk
	if ([self postBodyFilePath]) {
		
		// If we were writing to the post body via appendPostData or appendPostDataFromFile, close the write stream
		if ([self postBodyWriteStream]) {
			[[self postBodyWriteStream] close];
			[self setPostBodyWriteStream:nil];
		}

		NSError *err = nil;
		NSString *path;
		if ([self shouldCompressRequestBody]) {
			[self setCompressedPostBodyFilePath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]]];
			[ASIHTTPRequest compressDataFromFile:[self postBodyFilePath] toFile:[self compressedPostBodyFilePath]];
			path = [self compressedPostBodyFilePath];
		} else {
			path = [self postBodyFilePath];
		}
		[self setPostLength:[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:&err] fileSize]];
		if (err) {
			[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIFileManagementError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Failed to get attributes for file at path '@%'",path],NSLocalizedDescriptionKey,error,NSUnderlyingErrorKey,nil]]];
			return;
		}
		
	// Otherwise, we have an in-memory request body
	} else {
		if ([self shouldCompressRequestBody]) {
			[self setCompressedPostBody:[ASIHTTPRequest compressData:[self postBody]]];
			[self setPostLength:[[self compressedPostBody] length]];
		} else {
			[self setPostLength:[[self postBody] length]];
		}
	}
		
	if ([self postLength] > 0) {
		if ([requestMethod isEqualToString:@"GET"] || [requestMethod isEqualToString:@"DELETE"] || [requestMethod isEqualToString:@"HEAD"]) {
			[self setRequestMethod:@"POST"];
		}
		[self addRequestHeader:@"Content-Length" value:[NSString stringWithFormat:@"%llu",[self postLength]]];
	}
	[self setHaveBuiltPostBody:YES];
}

// Sets up storage for the post body
- (void)setupPostBody
{
	if ([self shouldStreamPostDataFromDisk]) {
		if (![self postBodyFilePath]) {
			[self setPostBodyFilePath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]]];
			[self setDidCreateTemporaryPostDataFile:YES];
		}
		if (![self postBodyWriteStream]) {
			[self setPostBodyWriteStream:[[[NSOutputStream alloc] initToFileAtPath:[self postBodyFilePath] append:NO] autorelease]];
			[[self postBodyWriteStream] open];
		}
	} else {
		if (![self postBody]) {
			[self setPostBody:[[[NSMutableData alloc] init] autorelease]];
		}
	}	
}

- (void)appendPostData:(NSData *)data
{
	[self setupPostBody];
	if ([data length] == 0) {
		return;
	}
	if ([self shouldStreamPostDataFromDisk]) {
		[[self postBodyWriteStream] write:[data bytes] maxLength:[data length]];
	} else {
		[[self postBody] appendData:data];
	}
}

- (void)appendPostDataFromFile:(NSString *)file
{
	[self setupPostBody];
	NSInputStream *stream = [[[NSInputStream alloc] initWithFileAtPath:file] autorelease];
	[stream open];
	NSUInteger bytesRead;
	while ([stream hasBytesAvailable]) {
		
		unsigned char buffer[1024*256];
		bytesRead = [stream read:buffer maxLength:sizeof(buffer)];
		if (bytesRead == 0) {
			break;
		}
		if ([self shouldStreamPostDataFromDisk]) {
			[[self postBodyWriteStream] write:buffer maxLength:bytesRead];
		} else {
			[[self postBody] appendData:[NSData dataWithBytes:buffer length:bytesRead]];
		}
	}
	[stream close];
}

- (id)delegate
{
	[[self cancelledLock] lock];
	id d = delegate;
	[[self cancelledLock] unlock];
	return d;
}

- (void)setDelegate:(id)newDelegate
{
	[[self cancelledLock] lock];
	delegate = newDelegate;
	[[self cancelledLock] unlock];
}

- (id)queue
{
	[[self cancelledLock] lock];
	id q = queue;
	[[self cancelledLock] unlock];
	return q;
}


- (void)setQueue:(id)newQueue
{
	[[self cancelledLock] lock];
	if (newQueue != queue) {
		[queue release];
		queue = [newQueue retain];
	}
	[[self cancelledLock] unlock];
}

#pragma mark get information about this request

// cancel the request - this must be run on the same thread as the request is running on
- (void)cancelOnRequestThread
{
	#if DEBUG_REQUEST_STATUS
	NSLog(@"Request cancelled: %@",self);
	#endif
    
	[[self cancelledLock] lock];

    if ([self isCancelled] || [self complete]) {
		[[self cancelledLock] unlock];
		return;
	}
	[self failWithError:ASIRequestCancelledError];
	[self setComplete:YES];
	[self cancelLoad];
	
	[[self retain] autorelease];
    [self willChangeValueForKey:@"isCancelled"];
    cancelled = YES;
    [self didChangeValueForKey:@"isCancelled"];
    
	[[self cancelledLock] unlock];
}

- (void)cancel
{
    [self performSelector:@selector(cancelOnRequestThread) onThread:[[self class] threadForRequest:self] withObject:nil waitUntilDone:NO];    
}


- (BOOL)isCancelled
{
    BOOL result;
    
	[[self cancelledLock] lock];
    result = cancelled;
    [[self cancelledLock] unlock];
    
    return result;
}

// Call this method to get the received data as an NSString. Don't use for binary data!
- (NSString *)responseString
{
	NSData *data = [self responseData];
	if (!data) {
		return nil;
	}
	
	return [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:[self responseEncoding]] autorelease];
}

- (BOOL)isResponseCompressed
{
	NSString *encoding = [[self responseHeaders] objectForKey:@"Content-Encoding"];
	return encoding && [encoding rangeOfString:@"gzip"].location != NSNotFound;
}

- (NSData *)responseData
{	
	if ([self isResponseCompressed]) {
		return [ASIHTTPRequest uncompressZippedData:[self rawResponseData]];
	} else {
		return [self rawResponseData];
	}
}

#pragma mark running a request

- (void)startSynchronous
{
#if DEBUG_REQUEST_STATUS || DEBUG_THROTTLING
	NSLog(@"Starting synchronous request %@",self);
#endif
	[self setRunLoopMode:ASIHTTPRequestRunLoopMode];
	[self setInProgress:YES];

	if (![self isCancelled] && ![self complete]) {
		[self main];
		while (!complete) {
			[[NSRunLoop currentRunLoop] runMode:[self runLoopMode] beforeDate:[NSDate distantFuture]];
		}
	}

	[self setInProgress:NO];
}

- (void)start
{
	[self setInProgress:YES];
	[self performSelector:@selector(main) onThread:[[self class] threadForRequest:self] withObject:nil waitUntilDone:NO];
}

- (void)startAsynchronous
{
#if DEBUG_REQUEST_STATUS || DEBUG_THROTTLING
	NSLog(@"Starting asynchronous request %@",self);
#endif
	[sharedQueue addOperation:self];
}

#pragma mark concurrency

- (BOOL)isConcurrent
{
    return YES;
}

- (BOOL)isFinished 
{
	return finished;
}

- (BOOL)isExecuting {
	return [self inProgress];
}

#pragma mark request logic

// Create the request
- (void)main
{
	@try {
		
		[[self cancelledLock] lock];
		
		// A HEAD request generated by an ASINetworkQueue may have set the error already. If so, we should not proceed.
		if ([self error]) {
			[self setComplete:YES];
			[self markAsFinished];
			return;		
		}

		[self setComplete:NO];
		[self setDidUseCachedResponse:NO];
		
		if (![self url]) {
			[self failWithError:ASIUnableToCreateRequestError];
			return;		
		}
		
		// Must call before we create the request so that the request method can be set if needs be
		if (![self mainRequest]) {
			[self buildPostBody];
		}
		
		if (![[self requestMethod] isEqualToString:@"GET"]) {
			[self setDownloadCache:nil];
		}
		
		
		// If we're redirecting, we'll already have a CFHTTPMessageRef
		if (request) {
			CFRelease(request);
		}

		// Create a new HTTP request.
		request = CFHTTPMessageCreateRequest(kCFAllocatorDefault, (CFStringRef)[self requestMethod], (CFURLRef)[self url], [self useHTTPVersionOne] ? kCFHTTPVersion1_0 : kCFHTTPVersion1_1);
		if (!request) {
			[self failWithError:ASIUnableToCreateRequestError];
			return;
		}

		//If this is a HEAD request generated by an ASINetworkQueue, we need to let the main request generate its headers first so we can use them
		if ([self mainRequest]) {
			[[self mainRequest] buildRequestHeaders];
		}
		
		// Even if this is a HEAD request with a mainRequest, we still need to call to give subclasses a chance to add their own to HEAD requests (ASIS3Request does this)
		[self buildRequestHeaders];
		
		if ([self downloadCache]) {
			if ([self cachePolicy] == ASIDefaultCachePolicy) {
				[self setCachePolicy:[[self downloadCache] defaultCachePolicy]];
			}

			// See if we should pull from the cache rather than fetching the data
			if ([self cachePolicy] == ASIOnlyLoadIfNotCachedCachePolicy) {
				if ([self useDataFromCache]) {
					return;
				}
			} else if ([self cachePolicy] == ASIReloadIfDifferentCachePolicy) {

				// Force a conditional GET if we have a cached version of this content already
				NSDictionary *cachedHeaders = [[self downloadCache] cachedHeadersForRequest:self];
				if (cachedHeaders) {
					NSString *etag = [cachedHeaders objectForKey:@"Etag"];
					if (etag) {
						[[self requestHeaders] setObject:etag forKey:@"If-None-Match"];
					}
					NSString *lastModified = [cachedHeaders objectForKey:@"Last-Modified"];
					if (lastModified) {
						[[self requestHeaders] setObject:lastModified forKey:@"If-Modified-Since"];
					}
				}
			}
		}

		[self applyAuthorizationHeader];
		
		
		NSString *header;
		for (header in [self requestHeaders]) {
			CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)header, (CFStringRef)[[self requestHeaders] objectForKey:header]);
		}
			
		[self startRequest];
		
	} @catch (NSException *exception) {
		NSError *underlyingError = [NSError errorWithDomain:NetworkRequestErrorDomain code:ASIUnhandledExceptionError userInfo:[exception userInfo]];
		[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIUnhandledExceptionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[exception name],NSLocalizedDescriptionKey,[exception reason],NSLocalizedFailureReasonErrorKey,underlyingError,NSUnderlyingErrorKey,nil]]];

	} @finally {
		[[self cancelledLock] unlock];
	}
}

- (void)applyAuthorizationHeader
{
	// Do we want to send credentials before we are asked for them?
	if (![self shouldPresentCredentialsBeforeChallenge]) {
		return;
	}
		
	// First, see if we have any credentials we can use in the session store
	NSDictionary *credentials = nil;
	if ([self useSessionPersistence]) {
		credentials = [self findSessionAuthenticationCredentials];
	}
	
	
	// Are any credentials set on this request that might be used for basic authentication?
	if ([self username] && [self password] && ![self domain]) {
		
		// If we have stored credentials, is this server asking for basic authentication? If we don't have credentials, we'll assume basic
		if (!credentials || (CFStringRef)[credentials objectForKey:@"AuthenticationScheme"] == kCFHTTPAuthenticationSchemeBasic) {
			[self addBasicAuthenticationHeaderWithUsername:[self username] andPassword:[self password]];
		}
	}
	
	if (credentials && ![[self requestHeaders] objectForKey:@"Authorization"]) {
		
		// When the Authentication key is set, the credentials were stored after an authentication challenge, so we can let CFNetwork apply them
		// (credentials for Digest and NTLM will always be stored like this)
		if ([credentials objectForKey:@"Authentication"]) {
			
			// If we've already talked to this server and have valid credentials, let's apply them to the request
			if (!CFHTTPMessageApplyCredentialDictionary(request, (CFHTTPAuthenticationRef)[credentials objectForKey:@"Authentication"], (CFDictionaryRef)[credentials objectForKey:@"Credentials"], NULL)) {
				[[self class] removeAuthenticationCredentialsFromSessionStore:[credentials objectForKey:@"Credentials"]];
			}
			
			// If the Authentication key is not set, these credentials were stored after a username and password set on a previous request passed basic authentication
			// When this happens, we'll need to create the Authorization header ourselves
		} else {
			NSDictionary *usernameAndPassword = [credentials objectForKey:@"Credentials"];
			[self addBasicAuthenticationHeaderWithUsername:[usernameAndPassword objectForKey:(NSString *)kCFHTTPAuthenticationUsername] andPassword:[usernameAndPassword objectForKey:(NSString *)kCFHTTPAuthenticationPassword]];
		}
	}
	if ([self useSessionPersistence]) {
		credentials = [self findSessionProxyAuthenticationCredentials];
		if (credentials) {
			if (!CFHTTPMessageApplyCredentialDictionary(request, (CFHTTPAuthenticationRef)[credentials objectForKey:@"Authentication"], (CFDictionaryRef)[credentials objectForKey:@"Credentials"], NULL)) {
				[[self class] removeProxyAuthenticationCredentialsFromSessionStore:[credentials objectForKey:@"Credentials"]];
			}
		}
	}
}

- (void)applyCookieHeader
{
	// Add cookies from the persistent (mac os global) store
	if ([self useCookiePersistence]) {
		NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[[self url] absoluteURL]];
		if (cookies) {
			[[self requestCookies] addObjectsFromArray:cookies];
		}
	}
	
	// Apply request cookies
	NSArray *cookies;
	if ([self mainRequest]) {
		cookies = [[self mainRequest] requestCookies];
	} else {
		cookies = [self requestCookies];
	}
	if ([cookies count] > 0) {
		NSHTTPCookie *cookie;
		NSString *cookieHeader = nil;
		for (cookie in cookies) {
			if (!cookieHeader) {
				cookieHeader = [NSString stringWithFormat: @"%@=%@",[cookie name],[cookie value]];
			} else {
				cookieHeader = [NSString stringWithFormat: @"%@; %@=%@",cookieHeader,[cookie name],[cookie value]];
			}
		}
		if (cookieHeader) {
			[self addRequestHeader:@"Cookie" value:cookieHeader];
		}
	}	
}

- (void)buildRequestHeaders
{
	if ([self haveBuiltRequestHeaders]) {
		return;
	}
	[self setHaveBuiltRequestHeaders:YES];
	
	if ([self mainRequest]) {
		for (NSString *header in [[self mainRequest] requestHeaders]) {
			[self addRequestHeader:header value:[[[self mainRequest] requestHeaders] valueForKey:header]];
		}
		return;
	}
	
	[self applyCookieHeader];
	
	// Build and set the user agent string if the request does not already have a custom user agent specified
	if (![[self requestHeaders] objectForKey:@"User-Agent"]) {
		NSString *userAgentString = [ASIHTTPRequest defaultUserAgentString];
		if (userAgentString) {
			[self addRequestHeader:@"User-Agent" value:userAgentString];
		}
	}
	
	
	// Accept a compressed response
	if ([self allowCompressedResponse]) {
		[self addRequestHeader:@"Accept-Encoding" value:@"gzip"];
	}
	
	// Configure a compressed request body
	if ([self shouldCompressRequestBody]) {
		[self addRequestHeader:@"Content-Encoding" value:@"gzip"];
	}
	
	// Should this request resume an existing download?
	[self updatePartialDownloadSize];
	if ([self partialDownloadSize]) {
		[self addRequestHeader:@"Range" value:[NSString stringWithFormat:@"bytes=%llu-",[self partialDownloadSize]]];
	}
}

- (void)updatePartialDownloadSize
{
	if ([self allowResumeForFileDownloads] && [self downloadDestinationPath] && [self temporaryFileDownloadPath] && [[NSFileManager defaultManager] fileExistsAtPath:[self temporaryFileDownloadPath]]) {
		NSError *err = nil;
		[self setPartialDownloadSize:[[[NSFileManager defaultManager] attributesOfItemAtPath:[self temporaryFileDownloadPath] error:&err] fileSize]];
		if (err) {
			[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIFileManagementError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Failed to get attributes for file at path '@%'",[self temporaryFileDownloadPath]],NSLocalizedDescriptionKey,error,NSUnderlyingErrorKey,nil]]];
			return;
		}
	}
}

- (void)startRequest
{
	if ([self isCancelled]) {
		return;
	}
	
	[self requestStarted];
	
	[self setDownloadComplete:NO];
	[self setComplete:NO];
	[self setTotalBytesRead:0];
	[self setLastBytesRead:0];
	
	if ([self redirectCount] == 0) {
		[self setOriginalURL:[self url]];
	}
	
	// If we're retrying a request, let's remove any progress we made
	if ([self lastBytesSent] > 0) {
		[self removeUploadProgressSoFar];
	}
	
	[self setLastBytesSent:0];
	[self setContentLength:0];
	[self setResponseHeaders:nil];
	if (![self downloadDestinationPath]) {
		[self setRawResponseData:[[[NSMutableData alloc] init] autorelease]];
    }
	
	
    //
	// Create the stream for the request
	//
	
	[self setReadStreamIsScheduled:NO];
	
	// Do we need to stream the request body from disk
	if ([self shouldStreamPostDataFromDisk] && [self postBodyFilePath] && [[NSFileManager defaultManager] fileExistsAtPath:[self postBodyFilePath]]) {
		
		// Are we gzipping the request body?
		if ([self compressedPostBodyFilePath] && [[NSFileManager defaultManager] fileExistsAtPath:[self compressedPostBodyFilePath]]) {
			[self setPostBodyReadStream:[ASIInputStream inputStreamWithFileAtPath:[self compressedPostBodyFilePath] request:self]];
		} else {
			[self setPostBodyReadStream:[ASIInputStream inputStreamWithFileAtPath:[self postBodyFilePath] request:self]];
		}
		[self setReadStream:[(NSInputStream *)CFReadStreamCreateForStreamedHTTPRequest(kCFAllocatorDefault, request,(CFReadStreamRef)[self postBodyReadStream]) autorelease]];
    } else {
		
		// If we have a request body, we'll stream it from memory using our custom stream, so that we can measure bandwidth use and it can be bandwidth-throttled if nescessary
		if ([self postBody] && [[self postBody] length] > 0) {
			if ([self shouldCompressRequestBody] && [self compressedPostBody]) {
				[self setPostBodyReadStream:[ASIInputStream inputStreamWithData:[self compressedPostBody] request:self]];
			} else if ([self postBody]) {
				[self setPostBodyReadStream:[ASIInputStream inputStreamWithData:[self postBody] request:self]];
			}
			[self setReadStream:[(NSInputStream *)CFReadStreamCreateForStreamedHTTPRequest(kCFAllocatorDefault, request,(CFReadStreamRef)[self postBodyReadStream]) autorelease]];
		
		} else {
			[self setReadStream:[(NSInputStream *)CFReadStreamCreateForHTTPRequest(kCFAllocatorDefault, request) autorelease]];
		}
	}

	if (![self readStream]) {
		[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIInternalErrorWhileBuildingRequestType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Unable to create read stream",NSLocalizedDescriptionKey,nil]]];
        return;
    }


    
    
    //
    // Handle SSL certificate settings
    //

    if([[[[self url] scheme] lowercaseString] isEqualToString:@"https"]) {

        NSMutableDictionary *sslProperties = [NSMutableDictionary dictionaryWithCapacity:1];

        // Tell CFNetwork not to validate SSL certificates
        if (![self validatesSecureCertificate]) {
            [sslProperties setObject:(NSString *)kCFBooleanFalse forKey:(NSString *)kCFStreamSSLValidatesCertificateChain];
        }

        // Tell CFNetwork to use a client certificate
        if (clientCertificateIdentity) {

			NSMutableArray *certificates = [NSMutableArray arrayWithCapacity:[clientCertificates count]+1];

			// The first object in the array is our SecIdentityRef
			[certificates addObject:(id)clientCertificateIdentity];

			// If we've added any additional certificates, add them too
			for (id cert in clientCertificates) {
				[certificates addObject:cert];
			}
            [sslProperties setObject:certificates forKey:(NSString *)kCFStreamSSLCertificates];
        }

        CFReadStreamSetProperty((CFReadStreamRef)[self readStream], kCFStreamPropertySSLSettings, sslProperties);
    }

    
	
	//
	// Handle proxy settings
	//
	
	// Have details of the proxy been set on this request
	if (![self proxyHost] && ![self proxyPort]) {
		
		// If not, we need to figure out what they'll be
		
		NSArray *proxies = nil;
		
		// Have we been given a proxy auto config file?
		if ([self PACurl]) {
			
			proxies = [ASIHTTPRequest proxiesForURL:[self url] fromPAC:[self PACurl]];
			
			// Detect proxy settings and apply them	
		} else {
			
#if TARGET_OS_IPHONE
			NSDictionary *proxySettings = NSMakeCollectable([(NSDictionary *)CFNetworkCopySystemProxySettings() autorelease]);
#else
			NSDictionary *proxySettings = NSMakeCollectable([(NSDictionary *)SCDynamicStoreCopyProxies(NULL) autorelease]);
#endif
			
			proxies = NSMakeCollectable([(NSArray *)CFNetworkCopyProxiesForURL((CFURLRef)[self url], (CFDictionaryRef)proxySettings) autorelease]);
			
			// Now check to see if the proxy settings contained a PAC url, we need to run the script to get the real list of proxies if so
			NSDictionary *settings = [proxies objectAtIndex:0];
			if ([settings objectForKey:(NSString *)kCFProxyAutoConfigurationURLKey]) {
				proxies = [ASIHTTPRequest proxiesForURL:[self url] fromPAC:[settings objectForKey:(NSString *)kCFProxyAutoConfigurationURLKey]];
			}
		}
		
		if (!proxies) {
			[self setReadStream:nil];
			[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIInternalErrorWhileBuildingRequestType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Unable to obtain information on proxy servers needed for request",NSLocalizedDescriptionKey,nil]]];
			return;			
		}
		// I don't really understand why the dictionary returned by CFNetworkCopyProxiesForURL uses different key names from CFNetworkCopySystemProxySettings/SCDynamicStoreCopyProxies
		// and why its key names are documented while those we actually need to use don't seem to be (passing the kCF* keys doesn't seem to work)
		if ([proxies count] > 0) {
			NSDictionary *settings = [proxies objectAtIndex:0];
			[self setProxyHost:[settings objectForKey:(NSString *)kCFProxyHostNameKey]];
			[self setProxyPort:[[settings objectForKey:(NSString *)kCFProxyPortNumberKey] intValue]];
			[self setProxyType:[settings objectForKey:(NSString *)kCFProxyTypeKey]];
		}
	}
	if ([self proxyHost] && [self proxyPort]) {
		NSString *hostKey;
		NSString *portKey;

		if (![self proxyType]) {
			[self setProxyType:(NSString *)kCFProxyTypeHTTP];
		}

		if ([[self proxyType] isEqualToString:(NSString *)kCFProxyTypeSOCKS]) {
			hostKey = (NSString *)kCFStreamPropertySOCKSProxyHost;
			portKey = (NSString *)kCFStreamPropertySOCKSProxyPort;
		} else {
			hostKey = (NSString *)kCFStreamPropertyHTTPProxyHost;
			portKey = (NSString *)kCFStreamPropertyHTTPProxyPort;
			if ([[[[self url] scheme] lowercaseString] isEqualToString:@"https"]) {
				hostKey = (NSString *)kCFStreamPropertyHTTPSProxyHost;
				portKey = (NSString *)kCFStreamPropertyHTTPSProxyPort;
			}
		}
		NSMutableDictionary *proxyToUse = [NSMutableDictionary dictionaryWithObjectsAndKeys:[self proxyHost],hostKey,[NSNumber numberWithInt:[self proxyPort]],portKey,nil];

		if ([[self proxyType] isEqualToString:(NSString *)kCFProxyTypeSOCKS]) {
			CFReadStreamSetProperty((CFReadStreamRef)[self readStream], kCFStreamPropertySOCKSProxy, proxyToUse);
		} else {
			CFReadStreamSetProperty((CFReadStreamRef)[self readStream], kCFStreamPropertyHTTPProxy, proxyToUse);
		}
	}

	//
	// Handle persistent connections
	//
	
	[ASIHTTPRequest expirePersistentConnections];

	[connectionsLock lock];
	
	
	if (![[self url] host] || ![[self url] scheme]) {
		[self setConnectionInfo:nil];
		[self setShouldAttemptPersistentConnection:NO];
	}
	
	// Will store the old stream that was using this connection (if there was one) so we can clean it up once we've opened our own stream
	NSInputStream *oldStream = nil;
	
	// Use a persistent connection if possible
	if ([self shouldAttemptPersistentConnection]) {
		

		// If we are redirecting, we will re-use the current connection only if we are connecting to the same server
		if ([self connectionInfo]) {
			
			if (![[[self connectionInfo] objectForKey:@"host"] isEqualToString:[[self url] host]] || ![[[self connectionInfo] objectForKey:@"scheme"] isEqualToString:[[self url] scheme]] || [(NSNumber *)[[self connectionInfo] objectForKey:@"port"] intValue] != [[[self url] port] intValue]) {
				[self setConnectionInfo:nil];
				
			// Check if we should have expired this connection
			} else if ([[[self connectionInfo] objectForKey:@"expires"] timeIntervalSinceNow] < 0) {
				#if DEBUG_PERSISTENT_CONNECTIONS
				NSLog(@"Not re-using connection #%i because it has expired",[[[self connectionInfo] objectForKey:@"id"] intValue]);
				#endif
				[persistentConnectionsPool removeObject:[self connectionInfo]];
				[self setConnectionInfo:nil];
			}
		}
		
		
		
		if (![self connectionInfo] && [[self url] host] && [[self url] scheme]) { // We must have a proper url with a host and scheme, or this will explode
			
			// Look for a connection to the same server in the pool
			for (NSMutableDictionary *existingConnection in persistentConnectionsPool) {
				if (![existingConnection objectForKey:@"request"] && [[existingConnection objectForKey:@"host"] isEqualToString:[[self url] host]] && [[existingConnection objectForKey:@"scheme"] isEqualToString:[[self url] scheme]] && [(NSNumber *)[existingConnection objectForKey:@"port"] intValue] == [[[self url] port] intValue]) {
					[self setConnectionInfo:existingConnection];
				}
			}
		}
		
		if ([[self connectionInfo] objectForKey:@"stream"]) {
			oldStream = [[[self connectionInfo] objectForKey:@"stream"] retain];

		}
		
		// No free connection was found in the pool matching the server/scheme/port we're connecting to, we'll need to create a new one
		if (![self connectionInfo]) {
			[self setConnectionInfo:[NSMutableDictionary dictionary]];
			nextConnectionNumberToCreate++;
			[[self connectionInfo] setObject:[NSNumber numberWithInt:nextConnectionNumberToCreate] forKey:@"id"];
			[[self connectionInfo] setObject:[[self url] host] forKey:@"host"];
			[[self connectionInfo] setObject:[NSNumber numberWithInt:[[[self url] port] intValue]] forKey:@"port"];
			[[self connectionInfo] setObject:[[self url] scheme] forKey:@"scheme"];
			[persistentConnectionsPool addObject:[self connectionInfo]];
		}
		
		// If we are retrying this request, it will already have a requestID
		if (![self requestID]) {
			nextRequestID++;
			[self setRequestID:[NSNumber numberWithUnsignedInt:nextRequestID]];
		}
		[[self connectionInfo] setObject:[self requestID] forKey:@"request"];		
		[[self connectionInfo] setObject:[self readStream] forKey:@"stream"];
		CFReadStreamSetProperty((CFReadStreamRef)[self readStream],  kCFStreamPropertyHTTPAttemptPersistentConnection, kCFBooleanTrue);
		
		#if DEBUG_PERSISTENT_CONNECTIONS
		NSLog(@"Request #%@ will use connection #%i",[self requestID],[[[self connectionInfo] objectForKey:@"id"] intValue]);
		#endif
		
		
		// Tag the stream with an id that tells it which connection to use behind the scenes
		// See http://lists.apple.com/archives/macnetworkprog/2008/Dec/msg00001.html for details on this approach
		
		CFReadStreamSetProperty((CFReadStreamRef)[self readStream], CFSTR("ASIStreamID"), [[self connectionInfo] objectForKey:@"id"]);
	
	}
	
	[connectionsLock unlock];

	// Schedule the stream
	if (![self readStreamIsScheduled] && (!throttleWakeUpTime || [throttleWakeUpTime timeIntervalSinceDate:[NSDate date]] < 0)) {
		[self scheduleReadStream];
	}
	
	BOOL streamSuccessfullyOpened = NO;


   // Start the HTTP connection
	CFStreamClientContext ctxt = {0, self, NULL, NULL, NULL};
    if (CFReadStreamSetClient((CFReadStreamRef)[self readStream], kNetworkEvents, ReadStreamClientCallBack, &ctxt)) {
		if (CFReadStreamOpen((CFReadStreamRef)[self readStream])) {
			streamSuccessfullyOpened = YES;
		}
	}
	
	// Here, we'll close the stream that was previously using this connection, if there was one
	// We've kept it open until now (when we've just opened a new stream) so that the new stream can make use of the old connection
	// http://lists.apple.com/archives/Macnetworkprog/2006/Mar/msg00119.html
	if (oldStream) {
		[oldStream close];
		[oldStream release];
		oldStream = nil;
	}

	if (!streamSuccessfullyOpened) {
		[self setConnectionCanBeReused:NO];
		[self destroyReadStream];
		[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIInternalErrorWhileBuildingRequestType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Unable to start HTTP connection",NSLocalizedDescriptionKey,nil]]];
		return;	
	}
	
	if (![self mainRequest]) {
		if ([self shouldResetUploadProgress]) {
			if ([self showAccurateProgress]) {
				[self incrementUploadSizeBy:[self postLength]];
			} else {
				[self incrementUploadSizeBy:1];	 
			}
			[ASIHTTPRequest updateProgressIndicator:&uploadProgressDelegate withProgress:0 ofTotal:1];
		}
		if ([self shouldResetDownloadProgress] && ![self partialDownloadSize]) {
			[ASIHTTPRequest updateProgressIndicator:&downloadProgressDelegate withProgress:0 ofTotal:1];
		}
	}	
	
	
	// Record when the request started, so we can timeout if nothing happens
	[self setLastActivityTime:[NSDate date]];
	[self setStatusTimer:[NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(updateStatus:) userInfo:nil repeats:YES]];
	[[NSRunLoop currentRunLoop] addTimer:[self statusTimer] forMode:[self runLoopMode]];
}

- (void)setStatusTimer:(NSTimer *)timer
{
	[self retain];
	// We must invalidate the old timer here, not before we've created and scheduled a new timer
	// This is because the timer may be the only thing retaining an asynchronous request
	if (statusTimer && timer != statusTimer) {
		[statusTimer invalidate];
		[statusTimer release];
	}
	statusTimer = [timer retain];
	[self release];
}

// This gets fired every 1/4 of a second to update the progress and work out if we need to timeout
- (void)updateStatus:(NSTimer*)timer
{
	[self checkRequestStatus];
	if (![self inProgress]) {
		[self setStatusTimer:nil];
	}
}

- (void)performRedirect
{
	[self setComplete:YES];
	[self setNeedsRedirect:NO];
	[self setRedirectCount:[self redirectCount]+1];

	if ([self redirectCount] > RedirectionLimit) {
		// Some naughty / badly coded website is trying to force us into a redirection loop. This is not cool.
		[self failWithError:ASITooMuchRedirectionError];
		[self setComplete:YES];
	} else {
		// Go all the way back to the beginning and build the request again, so that we can apply any new cookies
		[self main];
	}
}

- (BOOL)shouldTimeOut
{
	NSTimeInterval secondsSinceLastActivity = [[NSDate date] timeIntervalSinceDate:lastActivityTime];
	// See if we need to timeout
	if ([self readStream] && [self readStreamIsScheduled] && [self lastActivityTime] && [self timeOutSeconds] > 0 && secondsSinceLastActivity > [self timeOutSeconds]) {
		
		// We have no body, or we've sent more than the upload buffer size,so we can safely time out here
		if ([self postLength] == 0 || ([self uploadBufferSize] > 0 && [self totalBytesSent] > [self uploadBufferSize])) {
			return YES;
			
		// ***Black magic warning***
		// We have a body, but we've taken longer than timeOutSeconds to upload the first small chunk of data
		// Since there's no reliable way to track upload progress for the first 32KB (iPhone) or 128KB (Mac) with CFNetwork, we'll be slightly more forgiving on the timeout, as there's a strong chance our connection is just very slow.
		} else if (secondsSinceLastActivity > [self timeOutSeconds]*1.5) {
			return YES;
		}
	}
	return NO;
}

- (void)checkRequestStatus
{
	// We won't let the request cancel while we're updating progress / checking for a timeout
	[[self cancelledLock] lock];
	
	// See if our NSOperationQueue told us to cancel
	if ([self isCancelled] || [self complete]) {
		[[self cancelledLock] unlock];
		return;
	}
	
	[self performThrottling];
	
	if ([self shouldTimeOut]) {			
		// Do we need to auto-retry this request?
		if ([self numberOfTimesToRetryOnTimeout] > [self retryCount]) {

			// If we are resuming a download, we may need to update the Range header to take account of data we've just downloaded
			[self updatePartialDownloadSize];
			if ([self partialDownloadSize]) {
				CFHTTPMessageSetHeaderFieldValue(request, (CFStringRef)@"Range", (CFStringRef)[NSString stringWithFormat:@"bytes=%llu-",[self partialDownloadSize]]);
			}
			[self setRetryCount:[self retryCount]+1];
			[self unscheduleReadStream];
			[[self cancelledLock] unlock];
			[self startRequest];
			return;
		}
		[self failWithError:ASIRequestTimedOutError];
		[self cancelLoad];
		[self setComplete:YES];
		[[self cancelledLock] unlock];
		return;
	}

	// readStream will be null if we aren't currently running (perhaps we're waiting for a delegate to supply credentials)
	if ([self readStream]) {
		
		// If we have a post body
		if ([self postLength]) {
		
			[self setLastBytesSent:totalBytesSent];	
			
			// Find out how much data we've uploaded so far
			[self setTotalBytesSent:[NSMakeCollectable([(NSNumber *)CFReadStreamCopyProperty((CFReadStreamRef)[self readStream], kCFStreamPropertyHTTPRequestBytesWrittenCount) autorelease]) unsignedLongLongValue]];
			if (totalBytesSent > lastBytesSent) {
				
				// We've uploaded more data,  reset the timeout
				[self setLastActivityTime:[NSDate date]];
				[ASIHTTPRequest incrementBandwidthUsedInLastSecond:(unsigned long)(totalBytesSent-lastBytesSent)];		
						
				#if DEBUG_REQUEST_STATUS
				if ([self totalBytesSent] == [self postLength]) {
					NSLog(@"Request %@ finished uploading data",self);
				}
				#endif
			}
		}
			
		[self updateProgressIndicators];

	}
	
	[[self cancelledLock] unlock];
}


// Cancel loading and clean up. DO NOT USE THIS TO CANCEL REQUESTS - use [request cancel] instead
- (void)cancelLoad
{
    [self destroyReadStream];
	
	[[self postBodyReadStream] close];
	
    if ([self rawResponseData]) {
		[self setRawResponseData:nil];
	
	// If we were downloading to a file
	} else if ([self temporaryFileDownloadPath]) {
		[[self fileDownloadOutputStream] close];
		
		// If we haven't said we might want to resume, let's remove the temporary file too
		if (![self allowResumeForFileDownloads]) {
			[self removeTemporaryDownloadFile];
		}
	}
	
	// Clean up any temporary file used to store request body for streaming
	if (![self authenticationNeeded] && [self didCreateTemporaryPostDataFile]) {
		[self removePostDataFile];
		[self setDidCreateTemporaryPostDataFile:NO];
	}
	
	[self setResponseHeaders:nil];
}


- (void)removeTemporaryDownloadFile
{
	if ([self temporaryFileDownloadPath]) {
		if ([[NSFileManager defaultManager] fileExistsAtPath:[self temporaryFileDownloadPath]]) {
			NSError *removeError = nil;
			[[NSFileManager defaultManager] removeItemAtPath:[self temporaryFileDownloadPath] error:&removeError];
			if (removeError) {
				[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIFileManagementError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Failed to delete file at path '%@'",[self temporaryFileDownloadPath]],NSLocalizedDescriptionKey,removeError,NSUnderlyingErrorKey,nil]]];
			}
		}
		[self setTemporaryFileDownloadPath:nil];
	}
}

- (void)removePostDataFile
{
	if ([self postBodyFilePath]) {
		NSError *removeError = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[self postBodyFilePath] error:&removeError];
		if (removeError) {
			[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIFileManagementError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Failed to delete file at path '%@'",[self postBodyFilePath]],NSLocalizedDescriptionKey,removeError,NSUnderlyingErrorKey,nil]]];
		}
		[self setPostBodyFilePath:nil];
	}
	if ([self compressedPostBodyFilePath]) {
		NSError *removeError = nil;
		[[NSFileManager defaultManager] removeItemAtPath:[self compressedPostBodyFilePath] error:&removeError];
		if (removeError) {
			[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIFileManagementError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Failed to delete file at path '%@'",[self compressedPostBodyFilePath]],NSLocalizedDescriptionKey,removeError,NSUnderlyingErrorKey,nil]]];
		}
		[self setCompressedPostBodyFilePath:nil];
	}
}

#pragma mark HEAD request

// Used by ASINetworkQueue to create a HEAD request appropriate for this request with the same headers (though you can use it yourself)
- (ASIHTTPRequest *)HEADRequest
{
	ASIHTTPRequest *headRequest = [[self class] requestWithURL:[self url]];
	
	// Copy the properties that make sense for a HEAD request
	[headRequest setRequestHeaders:[[[self requestHeaders] mutableCopy] autorelease]];
	[headRequest setRequestCookies:[[[self requestCookies] mutableCopy] autorelease]];
	[headRequest setUseCookiePersistence:[self useCookiePersistence]];
	[headRequest setUseKeychainPersistence:[self useKeychainPersistence]];
	[headRequest setUseSessionPersistence:[self useSessionPersistence]];
	[headRequest setAllowCompressedResponse:[self allowCompressedResponse]];
	[headRequest setUsername:[self username]];
	[headRequest setPassword:[self password]];
	[headRequest setDomain:[self domain]];
	[headRequest setProxyUsername:[self proxyUsername]];
	[headRequest setProxyPassword:[self proxyPassword]];
	[headRequest setProxyDomain:[self proxyDomain]];
	[headRequest setProxyHost:[self proxyHost]];
	[headRequest setProxyPort:[self proxyPort]];
	[headRequest setProxyType:[self proxyType]];
	[headRequest setShouldPresentAuthenticationDialog:[self shouldPresentAuthenticationDialog]];
	[headRequest setShouldPresentProxyAuthenticationDialog:[self shouldPresentProxyAuthenticationDialog]];
	[headRequest setTimeOutSeconds:[self timeOutSeconds]];
	[headRequest setUseHTTPVersionOne:[self useHTTPVersionOne]];
	[headRequest setValidatesSecureCertificate:[self validatesSecureCertificate]];
    [headRequest setClientCertificateIdentity:clientCertificateIdentity];
	[headRequest setClientCertificates:[[clientCertificates copy] autorelease]];
	[headRequest setPACurl:[self PACurl]];
	[headRequest setShouldPresentCredentialsBeforeChallenge:[self shouldPresentCredentialsBeforeChallenge]];
	[headRequest setNumberOfTimesToRetryOnTimeout:[self numberOfTimesToRetryOnTimeout]];
	[headRequest setShouldUseRFC2616RedirectBehaviour:[self shouldUseRFC2616RedirectBehaviour]];
	[headRequest setShouldAttemptPersistentConnection:[self shouldAttemptPersistentConnection]];
	[headRequest setPersistentConnectionTimeoutSeconds:[self persistentConnectionTimeoutSeconds]];
	
	[headRequest setMainRequest:self];
	[headRequest setRequestMethod:@"HEAD"];
	return headRequest;
}


#pragma mark upload/download progress


- (void)updateProgressIndicators
{
	//Only update progress if this isn't a HEAD request used to preset the content-length
	if (![self mainRequest]) {
		if ([self showAccurateProgress] || ([self complete] && ![self updatedProgress])) {
			[self updateUploadProgress];
			[self updateDownloadProgress];
		}
	}
}

- (id)uploadProgressDelegate
{
	[[self cancelledLock] lock];
	id d = [[uploadProgressDelegate retain] autorelease];
	[[self cancelledLock] unlock];
	return d;
}

- (void)setUploadProgressDelegate:(id)newDelegate
{
	[[self cancelledLock] lock];
	uploadProgressDelegate = newDelegate;

	#if !TARGET_OS_IPHONE
	// If the uploadProgressDelegate is an NSProgressIndicator, we set its MaxValue to 1.0 so we can update it as if it were a UIProgressView
	double max = 1.0;
	[ASIHTTPRequest performSelector:@selector(setMaxValue:) onTarget:&uploadProgressDelegate withObject:nil amount:&max];
	#endif
	[[self cancelledLock] unlock];
}

- (id)downloadProgressDelegate
{
	[[self cancelledLock] lock];
	id d = [[downloadProgressDelegate retain] autorelease];
	[[self cancelledLock] unlock];
	return d;
}

- (void)setDownloadProgressDelegate:(id)newDelegate
{
	[[self cancelledLock] lock];
	downloadProgressDelegate = newDelegate;

	#if !TARGET_OS_IPHONE
	// If the downloadProgressDelegate is an NSProgressIndicator, we set its MaxValue to 1.0 so we can update it as if it were a UIProgressView
	double max = 1.0;
	[ASIHTTPRequest performSelector:@selector(setMaxValue:) onTarget:&downloadProgressDelegate withObject:nil amount:&max];	
	#endif
	[[self cancelledLock] unlock];
}


- (void)updateDownloadProgress
{
	// We won't update download progress until we've examined the headers, since we might need to authenticate
	if (![self responseHeaders] || [self needsRedirect] || !([self contentLength] || [self complete])) {
		return;
	}
		
	unsigned long long bytesReadSoFar = [self totalBytesRead]+[self partialDownloadSize];
	unsigned long long value = 0;
	
	if ([self showAccurateProgress] && [self contentLength]) {
		value = bytesReadSoFar-[self lastBytesRead];
		if (value == 0) {
			return;
		}
	} else {
		value = 1;
		[self setUpdatedProgress:YES];
	}
	if (!value) {
		return;
	}

	[ASIHTTPRequest performSelector:@selector(request:didReceiveBytes:) onTarget:&queue withObject:self amount:&value];
	[ASIHTTPRequest performSelector:@selector(request:didReceiveBytes:) onTarget:&downloadProgressDelegate withObject:self amount:&value];
	[ASIHTTPRequest updateProgressIndicator:&downloadProgressDelegate withProgress:[self totalBytesRead]+[self partialDownloadSize] ofTotal:[self contentLength]+[self partialDownloadSize]];
		
	[self setLastBytesRead:bytesReadSoFar];
}


- (void)updateUploadProgress
{
	if ([self isCancelled] || [self totalBytesSent] == 0) {
		return;
	}
	
	// If this is the first time we've written to the buffer, totalBytesSent will be the size of the buffer (currently seems to be 128KB on both Leopard and iPhone 2.2.1, 32KB on iPhone 3.0)
	// If request body is less than the buffer size, totalBytesSent will be the total size of the request body
	// We will remove this from any progress display, as kCFStreamPropertyHTTPRequestBytesWrittenCount does not tell us how much data has actually be written
	if ([self uploadBufferSize] == 0 && [self totalBytesSent] != [self postLength]) {
		[self setUploadBufferSize:[self totalBytesSent]];
		[self incrementUploadSizeBy:-[self uploadBufferSize]];
	}
	
	unsigned long long value = 0;
	
	if ([self showAccurateProgress]) {
		if ([self totalBytesSent] == [self postLength] || [self lastBytesSent] > 0) {
			value = [self totalBytesSent]-[self lastBytesSent];
		} else {
			return;
		}
	} else {
		value = 1;
		[self setUpdatedProgress:YES];
	}
	
	if (!value) {
		return;
	}
	
	[ASIHTTPRequest performSelector:@selector(request:didSendBytes:) onTarget:&queue withObject:self amount:&value];
	[ASIHTTPRequest performSelector:@selector(request:didSendBytes:) onTarget:&uploadProgressDelegate withObject:self amount:&value];
	[ASIHTTPRequest updateProgressIndicator:&uploadProgressDelegate withProgress:[self totalBytesSent]-[self uploadBufferSize] ofTotal:[self postLength]-[self uploadBufferSize]];
}


- (void)incrementDownloadSizeBy:(long long)length
{
	[ASIHTTPRequest performSelector:@selector(request:incrementDownloadSizeBy:) onTarget:&queue withObject:self amount:&length];
	[ASIHTTPRequest performSelector:@selector(request:incrementDownloadSizeBy:) onTarget:&downloadProgressDelegate withObject:self amount:&length];
}


- (void)incrementUploadSizeBy:(long long)length
{
	[ASIHTTPRequest performSelector:@selector(request:incrementUploadSizeBy:) onTarget:&queue withObject:self amount:&length];
	[ASIHTTPRequest performSelector:@selector(request:incrementUploadSizeBy:) onTarget:&uploadProgressDelegate withObject:self amount:&length];
}


-(void)removeUploadProgressSoFar
{
	long long progressToRemove = -[self totalBytesSent];
	[ASIHTTPRequest performSelector:@selector(request:didSendBytes:) onTarget:&queue withObject:self amount:&progressToRemove];
	[ASIHTTPRequest performSelector:@selector(request:didSendBytes:) onTarget:&uploadProgressDelegate withObject:self amount:&progressToRemove];
	[ASIHTTPRequest updateProgressIndicator:&uploadProgressDelegate withProgress:0 ofTotal:[self postLength]];
}

+ (void)performInvocation:(NSInvocation *)invocation onTarget:(id *)target
{
    if (*target && [*target respondsToSelector:invocation.selector])
    {
        [invocation invokeWithTarget:*target];
    }
    [invocation release];
    [self autorelease];
}

+ (void)performSelector:(SEL)selector onTarget:(id *)target withObject:(id)object amount:(void *)amount
{
	if ([*target respondsToSelector:selector]) {
		NSMethodSignature *signature = nil;
		signature = [[*target class] instanceMethodSignatureForSelector:selector];
		NSInvocation *invocation = [[NSInvocation invocationWithMethodSignature:signature] retain];
		[invocation setSelector:selector];
		
		int argumentNumber = 2;
		
		// If we got an object parameter, we pass a pointer to the object pointer
		if (object) {
			[invocation setArgument:&object atIndex:argumentNumber];
			argumentNumber++;	
		}
		
		// For the amount we'll just pass the pointer directly so NSInvocation will call the method using the number itself rather than a pointer to it
		if (amount) {
			[invocation setArgument:amount atIndex:argumentNumber];
		}

        SEL callback = @selector(performInvocation:onTarget:);
        NSMethodSignature *cbSignature = [ASIHTTPRequest methodSignatureForSelector:callback];
        NSInvocation *cbInvocation = [NSInvocation invocationWithMethodSignature:cbSignature];
        [cbInvocation setSelector:callback];
        [cbInvocation setTarget:self];
        [cbInvocation setArgument:&invocation atIndex:2];
        [cbInvocation setArgument:&target atIndex:3];
        
        [self retain]; // ensure we stay around for the duration of the callback
        [cbInvocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:[NSThread isMainThread]];
    }
}
	
	
+ (void)updateProgressIndicator:(id *)indicator withProgress:(unsigned long long)progress ofTotal:(unsigned long long)total
{
	#if TARGET_OS_IPHONE
		// Cocoa Touch: UIProgressView
		SEL selector = @selector(setProgress:);
		float progressAmount = (progress*1.0f)/(total*1.0f);
		
	#else
		// Cocoa: NSProgressIndicator
		double progressAmount = progressAmount = (progress*1.0)/(total*1.0);
		SEL selector = @selector(setDoubleValue:);
	#endif
	
	if (![*indicator respondsToSelector:selector]) {
		return;
	}
	
	[progressLock lock];
	[ASIHTTPRequest performSelector:selector onTarget:indicator withObject:nil amount:&progressAmount];
	[progressLock unlock];
}


#pragma mark handling request complete / failure

- (void)callSelectorCallback:(SEL *)selectorPtr withTarget:(id *)targetPtr request:(ASIHTTPRequest *)request
{
	id target = *targetPtr;
	SEL selector = *selectorPtr;
	if (selector && target && [target respondsToSelector:selector]) {
		[target performSelector:selector withObject:self];
	}
}

// Call a selector for a delegate on the main thread
// As either the delegate or the selector may be changed before we get
// to run on the main thread, they are passed as pointers, which we only
// dereference on the main thread just before we call the selector
- (void)callSelectorOnMainThread:(SEL *)selector forDelegate:(id *)target
{
	if (!*selector || !*target)
		return;
	
	SEL callback = @selector(callSelectorCallback:withTarget:request:);
	NSMethodSignature *signature = [ASIHTTPRequest instanceMethodSignatureForSelector:callback];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	[invocation setSelector:callback];
	[invocation setTarget:self];
	[invocation setArgument:&selector atIndex:2];
	[invocation setArgument:&target atIndex:3];
	[invocation setArgument:&self atIndex:4];
	
	// Force the invocation to retain this request until after we have performed the callback
    [invocation retainArguments];
	[invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:[NSThread isMainThread]];
}



- (void)requestReceivedResponseHeaders
{
	if ([self error] || [self mainRequest]) {
		return;
	}
	// Let the delegate know we have started
	[self callSelectorOnMainThread:&didReceiveResponseHeadersSelector forDelegate:&delegate];
	
	// Let the queue know we have started
	[self callSelectorOnMainThread:&queueRequestReceivedResponseHeadersSelector forDelegate:&queue];
}

- (void)requestStarted
{
	if ([self error] || [self mainRequest]) {
		return;
	}
	// Let the delegate know we have started
	[self callSelectorOnMainThread:&didStartSelector forDelegate:&delegate];
	
	// Let the queue know we have started
	[self callSelectorOnMainThread:&queueRequestStartedSelector forDelegate:&queue];
}

// Subclasses might override this method to process the result in the same thread
// If you do this, don't forget to call [super requestFinished] to let the queue / delegate know we're done
- (void)requestFinished
{
#if DEBUG_REQUEST_STATUS || DEBUG_THROTTLING
	NSLog(@"Request finished: %@",self);
#endif
	if ([self error] || [self mainRequest]) {
		return;
	}
	// Let the delegate know we are done
	[self callSelectorOnMainThread:&didFinishSelector forDelegate:&delegate];
	
	// Let the queue know we are done
	[self callSelectorOnMainThread:&queueRequestFinishedSelector forDelegate:&queue];
}


- (void)reportFailure
{
    // Let the delegate know something went wrong
	[self callSelectorOnMainThread:&didFailSelector forDelegate:&delegate];
	
	// Let the queue know something went wrong
	[self callSelectorOnMainThread:&queueRequestFailedSelector forDelegate:&queue];
}

// Subclasses might override this method to perform error handling in the same thread
// If you do this, don't forget to call [super failWithError:] to let the queue / delegate know we're done
- (void)failWithError:(NSError *)theError
{
#if DEBUG_REQUEST_STATUS || DEBUG_THROTTLING
	NSLog(@"Request %@: %@",self,(theError == ASIRequestCancelledError ? @"Cancelled" : @"Failed"));
#endif
	[self setComplete:YES];
	
	// Invalidate the current connection so subsequent requests don't attempt to reuse it
	if (theError && [theError code] != ASIAuthenticationErrorType && [theError code] != ASITooMuchRedirectionErrorType) {
		[connectionsLock lock];
		#if DEBUG_PERSISTENT_CONNECTIONS
		NSLog(@"Request #%@ failed and will invalidate connection #%@",[self requestID],[[self connectionInfo] objectForKey:@"id"]);
		#endif
		[[self connectionInfo] removeObjectForKey:@"request"];
		[persistentConnectionsPool removeObject:[self connectionInfo]];
		[connectionsLock unlock];
		[self destroyReadStream];
	}
	if ([self connectionCanBeReused]) {
		[[self connectionInfo] setObject:[NSDate dateWithTimeIntervalSinceNow:[self persistentConnectionTimeoutSeconds]] forKey:@"expires"];
	}
	
    if ([self isCancelled] || [self error]) {
		return;
	}
	
	if ([self downloadCache] && [self cachePolicy] == ASIUseCacheIfLoadFailsCachePolicy) {
		if ([self useDataFromCache]) {
			return;
		}
	}
	
	
	[self setError:theError];
	
	ASIHTTPRequest *failedRequest = self;
	
	// If this is a HEAD request created by an ASINetworkQueue or compatible queue delegate, make the main request fail
	if ([self mainRequest]) {
		failedRequest = [self mainRequest];
		[failedRequest setError:theError];
	}

    [failedRequest reportFailure];
	
    if (!inProgress)
    {
        // if we're not in progress, we can't notify the queue we've finished (doing so can cause a crash later on)
        // "markAsFinished" will be at the start of main() when we are started
        return;
    }
	// markAsFinished may well cause this object to be dealloced
	[self retain];
	[self markAsFinished];
	[self release];
}

#pragma mark parsing HTTP response headers

- (void)readResponseHeaders
{
	[self setAuthenticationNeeded:ASINoAuthenticationNeededYet];

	CFHTTPMessageRef message = (CFHTTPMessageRef)CFReadStreamCopyProperty((CFReadStreamRef)[self readStream], kCFStreamPropertyHTTPResponseHeader);
	if (!message) {
		return;
	}
	
	// Make sure we've received all the headers
	if (!CFHTTPMessageIsHeaderComplete(message)) {
		CFRelease(message);
		return;
	}

	#if DEBUG_REQUEST_STATUS
	if ([self totalBytesSent] == [self postLength]) {
		NSLog(@"Request %@ received response headers",self);
	}
	#endif		

	CFDictionaryRef headerFields = CFHTTPMessageCopyAllHeaderFields(message);
	[self setResponseHeaders:(NSDictionary *)headerFields];

	CFRelease(headerFields);
	
	[self setResponseStatusCode:(int)CFHTTPMessageGetResponseStatusCode(message)];
	[self setResponseStatusMessage:[(NSString *)CFHTTPMessageCopyResponseStatusLine(message) autorelease]];
	
	if ([self downloadCache] && [self cachePolicy] == ASIReloadIfDifferentCachePolicy) {
		if ([self useDataFromCache]) {
			CFRelease(message);
			return;
		}
	}

	// Is the server response a challenge for credentials?
	if ([self responseStatusCode] == 401) {
		[self setAuthenticationNeeded:ASIHTTPAuthenticationNeeded];
	} else if ([self responseStatusCode] == 407) {
		[self setAuthenticationNeeded:ASIProxyAuthenticationNeeded];
	}
		
	// Authentication succeeded, or no authentication was required
	if (![self authenticationNeeded]) {

		// Did we get here without an authentication challenge? (which can happen when shouldPresentCredentialsBeforeChallenge is YES and basic auth was successful)
		if (!requestAuthentication && [self username] && [self password] && [self useSessionPersistence]) {
			
			NSMutableDictionary *newCredentials = [NSMutableDictionary dictionaryWithCapacity:2];
			[newCredentials setObject:[self username] forKey:(NSString *)kCFHTTPAuthenticationUsername];
			[newCredentials setObject:[self password] forKey:(NSString *)kCFHTTPAuthenticationPassword];
			
			// Store the credentials in the session 
			NSMutableDictionary *sessionCredentials = [NSMutableDictionary dictionary];
			[sessionCredentials setObject:newCredentials forKey:@"Credentials"];
			[sessionCredentials setObject:[self url] forKey:@"URL"];
			[sessionCredentials setObject:(NSString *)kCFHTTPAuthenticationSchemeBasic forKey:@"AuthenticationScheme"];
			[[self class] storeAuthenticationCredentialsInSessionStore:sessionCredentials];
		}
	}

	// Handle response text encoding
	[self parseStringEncodingFromHeaders];

	// Handle cookies
	NSArray *newCookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[self responseHeaders] forURL:[self url]];
	[self setResponseCookies:newCookies];
	
	if ([self useCookiePersistence]) {
		
		// Store cookies in global persistent store
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookies:newCookies forURL:[self url] mainDocumentURL:nil];
		
		// We also keep any cookies in the sessionCookies array, so that we have a reference to them if we need to remove them later
		NSHTTPCookie *cookie;
		for (cookie in newCookies) {
			[ASIHTTPRequest addSessionCookie:cookie];
		}
	}
	
	// Do we need to redirect?
	// Note that ASIHTTPRequest does not currently support 305 Use Proxy
	if ([self shouldRedirect] && [responseHeaders valueForKey:@"Location"]) {
		if (([self responseStatusCode] > 300 && [self responseStatusCode] < 304) || [self responseStatusCode] == 307) {
			
			// By default, we redirect 301 and 302 response codes as GET requests
			// According to RFC 2616 this is wrong, but this is what most browsers do, so it's probably what you're expecting to happen
			// See also:
			// http://allseeing-i.lighthouseapp.com/projects/27881/tickets/27-302-redirection-issue
							
			if ([self responseStatusCode] != 307 && (![self shouldUseRFC2616RedirectBehaviour] || [self responseStatusCode] == 303)) {
				[self setRequestMethod:@"GET"];
				[self setPostBody:nil];
				[self setPostLength:0];

				// Perhaps there are other headers we should be preserving, but it's hard to know what we need to keep and what to throw away.
				NSString *userAgentHeader = [[self requestHeaders] objectForKey:@"User-Agent"];
				NSString *acceptHeader = [[self requestHeaders] objectForKey:@"Accept"];
				[self setRequestHeaders:nil];
				if (userAgentHeader) {
					[self addRequestHeader:@"User-Agent" value:userAgentHeader];
				}
				if (acceptHeader) {
					[self addRequestHeader:@"Accept" value:acceptHeader];
				}
				[self setHaveBuiltRequestHeaders:NO];
			} else {
			
				// Force rebuild the cookie header incase we got some new cookies from this request
				// All other request headers will remain as they are for 301 / 302 redirects
				[self applyCookieHeader];
			}

			// Force the redirected request to rebuild the request headers (if not a 303, it will re-use old ones, and add any new ones)
			
			[self setURL:[[NSURL URLWithString:[responseHeaders valueForKey:@"Location"] relativeToURL:[self url]] absoluteURL]];
			[self setNeedsRedirect:YES];
			
			// Clear the request cookies
			// This means manually added cookies will not be added to the redirect request - only those stored in the global persistent store
			// But, this is probably the safest option - we might be redirecting to a different domain
			[self setRequestCookies:[NSMutableArray array]];
			
			#if DEBUG_REQUEST_STATUS
				NSLog(@"Request will redirect (code: %i): %@",[self responseStatusCode],self);
			#endif
			
		}
	}

	if (![self needsRedirect]) {
		// See if we got a Content-length header
		NSString *cLength = [responseHeaders valueForKey:@"Content-Length"];
		ASIHTTPRequest *theRequest = self;
		if ([self mainRequest]) {
			theRequest = [self mainRequest];
		}

		if (cLength) {
			unsigned long long length = strtoull([cLength UTF8String], NULL, 0);

			// Workaround for Apache HEAD requests for dynamically generated content returning the wrong Content-Length when using gzip
			if ([self mainRequest] && [self allowCompressedResponse] && length == 20 && [self showAccurateProgress] && [self shouldResetDownloadProgress]) {
				[[self mainRequest] setShowAccurateProgress:NO];
				[[self mainRequest] incrementDownloadSizeBy:1];

			} else {
				[theRequest setContentLength:length];
				if ([self showAccurateProgress] && [self shouldResetDownloadProgress]) {
					[theRequest incrementDownloadSizeBy:[theRequest contentLength]+[theRequest partialDownloadSize]];
				}
			}

		} else if ([self showAccurateProgress] && [self shouldResetDownloadProgress]) {
			[theRequest setShowAccurateProgress:NO];
			[theRequest incrementDownloadSizeBy:1];
		}
	}

	// Handle connection persistence
	if ([self shouldAttemptPersistentConnection]) {
		
		NSString *connectionHeader = [[[self responseHeaders] objectForKey:@"Connection"] lowercaseString];
		NSString *httpVersion = NSMakeCollectable([(NSString *)CFHTTPMessageCopyVersion(message) autorelease]);
		
		// Don't re-use the connection if the server is HTTP 1.0 and didn't send Connection: Keep-Alive
		if (![httpVersion isEqualToString:(NSString *)kCFHTTPVersion1_0] || [connectionHeader isEqualToString:@"keep-alive"]) {

			// See if server explicitly told us to close the connection
			if (![connectionHeader isEqualToString:@"close"]) {
				
				NSString *keepAliveHeader = [[self responseHeaders] objectForKey:@"Keep-Alive"];
				
				// If we got a keep alive header, we'll reuse the connection for as long as the server tells us
				if (keepAliveHeader) { 
					int timeout = 0;
					int max = 0;
					NSScanner *scanner = [NSScanner scannerWithString:keepAliveHeader];
					[scanner scanString:@"timeout=" intoString:NULL];
					[scanner scanInt:&timeout];
					[scanner scanUpToString:@"max=" intoString:NULL];
					[scanner scanString:@"max=" intoString:NULL];
					[scanner scanInt:&max];
					if (max > 5) {
						[self setConnectionCanBeReused:YES];
						[self setPersistentConnectionTimeoutSeconds:timeout];
						#if DEBUG_PERSISTENT_CONNECTIONS
							NSLog(@"Got a keep-alive header, will keep this connection open for %f seconds", [self persistentConnectionTimeoutSeconds]);
						#endif					
					}
				
				// Otherwise, we'll assume we can keep this connection open
				} else {
					[self setConnectionCanBeReused:YES];
					#if DEBUG_PERSISTENT_CONNECTIONS
						NSLog(@"Got no keep-alive header, will keep this connection open for %f seconds", [self persistentConnectionTimeoutSeconds]);
					#endif
				}
			}
		}
	}

	CFRelease(message);
	[self requestReceivedResponseHeaders];
}

// Handle response text encoding
// If the Content-Type header specified an encoding, we'll use that, otherwise we use defaultStringEncoding (which defaults to NSISOLatin1StringEncoding)
- (void)parseStringEncodingFromHeaders
{
	NSString *contentType = [[self responseHeaders] objectForKey:@"Content-Type"];
	NSStringEncoding encoding = [self defaultResponseEncoding];
	if (contentType) {

		NSString *charsetSeparator = @"charset=";
		NSScanner *charsetScanner = [NSScanner scannerWithString: contentType];
		NSString *IANAEncoding = nil;

		if ([charsetScanner scanUpToString: charsetSeparator intoString: NULL] && [charsetScanner scanLocation] < [contentType length]) {
			[charsetScanner setScanLocation: [charsetScanner scanLocation] + [charsetSeparator length]];
			[charsetScanner scanUpToString: @";" intoString: &IANAEncoding];
		}

		if (IANAEncoding) {
			CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)IANAEncoding);
			if (cfEncoding != kCFStringEncodingInvalidId) {
				encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
			}
		}
	}
	[self setResponseEncoding:encoding];
}

#pragma mark http authentication

- (void)saveProxyCredentialsToKeychain:(NSDictionary *)newCredentials
{
	NSURLCredential *authenticationCredentials = [NSURLCredential credentialWithUser:[newCredentials objectForKey:(NSString *)kCFHTTPAuthenticationUsername] password:[newCredentials objectForKey:(NSString *)kCFHTTPAuthenticationPassword] persistence:NSURLCredentialPersistencePermanent];
	if (authenticationCredentials) {
		[ASIHTTPRequest saveCredentials:authenticationCredentials forProxy:[self proxyHost] port:[self proxyPort] realm:[self proxyAuthenticationRealm]];
	}	
}


- (void)saveCredentialsToKeychain:(NSDictionary *)newCredentials
{
	NSURLCredential *authenticationCredentials = [NSURLCredential credentialWithUser:[newCredentials objectForKey:(NSString *)kCFHTTPAuthenticationUsername] password:[newCredentials objectForKey:(NSString *)kCFHTTPAuthenticationPassword] persistence:NSURLCredentialPersistencePermanent];
	
	if (authenticationCredentials) {
		[ASIHTTPRequest saveCredentials:authenticationCredentials forHost:[[self url] host] port:[[[self url] port] intValue] protocol:[[self url] scheme] realm:[self authenticationRealm]];
	}	
}

- (BOOL)applyProxyCredentials:(NSDictionary *)newCredentials
{
	[self setProxyAuthenticationRetryCount:[self proxyAuthenticationRetryCount]+1];
	
	if (newCredentials && proxyAuthentication && request) {

		// Apply whatever credentials we've built up to the old request
		if (CFHTTPMessageApplyCredentialDictionary(request, proxyAuthentication, (CFMutableDictionaryRef)newCredentials, NULL)) {
			
			//If we have credentials and they're ok, let's save them to the keychain
			if (useKeychainPersistence) {
				[self saveProxyCredentialsToKeychain:newCredentials];
			}
			if (useSessionPersistence) {
				NSMutableDictionary *sessionProxyCredentials = [NSMutableDictionary dictionary];
				[sessionProxyCredentials setObject:(id)proxyAuthentication forKey:@"Authentication"];
				[sessionProxyCredentials setObject:newCredentials forKey:@"Credentials"];
				[sessionProxyCredentials setObject:[self proxyHost] forKey:@"Host"];
				[sessionProxyCredentials setObject:[NSNumber numberWithInt:[self proxyPort]] forKey:@"Port"];
				[sessionProxyCredentials setObject:[self proxyAuthenticationScheme] forKey:@"AuthenticationScheme"];
				[[self class] storeProxyAuthenticationCredentialsInSessionStore:sessionProxyCredentials];
			}
			[self setProxyCredentials:newCredentials];
			return YES;
		} else {
			[[self class] removeProxyAuthenticationCredentialsFromSessionStore:newCredentials];
		}
	}
	return NO;
}

- (BOOL)applyCredentials:(NSDictionary *)newCredentials
{
	[self setAuthenticationRetryCount:[self authenticationRetryCount]+1];
	
	if (newCredentials && requestAuthentication && request) {
		// Apply whatever credentials we've built up to the old request
		if (CFHTTPMessageApplyCredentialDictionary(request, requestAuthentication, (CFMutableDictionaryRef)newCredentials, NULL)) {
			
			//If we have credentials and they're ok, let's save them to the keychain
			if (useKeychainPersistence) {
				[self saveCredentialsToKeychain:newCredentials];
			}
			if (useSessionPersistence) {
				
				NSMutableDictionary *sessionCredentials = [NSMutableDictionary dictionary];
				[sessionCredentials setObject:(id)requestAuthentication forKey:@"Authentication"];
				[sessionCredentials setObject:newCredentials forKey:@"Credentials"];
				[sessionCredentials setObject:[self url] forKey:@"URL"];
				[sessionCredentials setObject:[self authenticationScheme] forKey:@"AuthenticationScheme"];
				if ([self authenticationRealm]) {
					[sessionCredentials setObject:[self authenticationRealm] forKey:@"AuthenticationRealm"];
				}
				[[self class] storeAuthenticationCredentialsInSessionStore:sessionCredentials];

			}
			[self setRequestCredentials:newCredentials];
			return YES;
		} else {
			[[self class] removeAuthenticationCredentialsFromSessionStore:newCredentials];
		}
	}
	return NO;
}

- (NSMutableDictionary *)findProxyCredentials
{
	NSMutableDictionary *newCredentials = [[[NSMutableDictionary alloc] init] autorelease];
	
	// Is an account domain needed? (used currently for NTLM only)
	if (CFHTTPAuthenticationRequiresAccountDomain(proxyAuthentication)) {
		if (![self proxyDomain]) {
			[self setProxyDomain:@""];
		}
		[newCredentials setObject:[self proxyDomain] forKey:(NSString *)kCFHTTPAuthenticationAccountDomain];
	}
	
	NSString *user = nil;
	NSString *pass = nil;
	

	// If this is a HEAD request generated by an ASINetworkQueue, we'll try to use the details from the main request
	if ([self mainRequest] && [[self mainRequest] proxyUsername] && [[self mainRequest] proxyPassword]) {
		user = [[self mainRequest] proxyUsername];
		pass = [[self mainRequest] proxyPassword];
		
		// Let's try to use the ones set in this object
	} else if ([self proxyUsername] && [self proxyPassword]) {
		user = [self proxyUsername];
		pass = [self proxyPassword];
	}		

	
	// Ok, that didn't work, let's try the keychain
	// For authenticating proxies, we'll look in the keychain regardless of the value of useKeychainPersistence
	if ((!user || !pass)) {
		NSURLCredential *authenticationCredentials = [ASIHTTPRequest savedCredentialsForProxy:[self proxyHost] port:[self proxyPort] protocol:[[self url] scheme] realm:[self proxyAuthenticationRealm]];
		if (authenticationCredentials) {
			user = [authenticationCredentials user];
			pass = [authenticationCredentials password];
		}
		
	}
	
	// If we have a username and password, let's apply them to the request and continue
	if (user && pass) {
		
		[newCredentials setObject:user forKey:(NSString *)kCFHTTPAuthenticationUsername];
		[newCredentials setObject:pass forKey:(NSString *)kCFHTTPAuthenticationPassword];
		return newCredentials;
	}
	return nil;
}


- (NSMutableDictionary *)findCredentials
{
	NSMutableDictionary *newCredentials = [[[NSMutableDictionary alloc] init] autorelease];
	
	// Is an account domain needed? (used currently for NTLM only)
	if (CFHTTPAuthenticationRequiresAccountDomain(requestAuthentication)) {
		if (!domain) {
			[self setDomain:@""];
		}
		[newCredentials setObject:domain forKey:(NSString *)kCFHTTPAuthenticationAccountDomain];
	}
	
	// First, let's look at the url to see if the username and password were included
	NSString *user = [[self url] user];
	NSString *pass = [[self url] password];
	
	// If the username and password weren't in the url
	if (!user || !pass) {
		
		// If this is a HEAD request generated by an ASINetworkQueue, we'll try to use the details from the main request
		if ([self mainRequest] && [[self mainRequest] username] && [[self mainRequest] password]) {
			user = [[self mainRequest] username];
			pass = [[self mainRequest] password];
			
		// Let's try to use the ones set in this object
		} else if ([self username] && [self password]) {
			user = [self username];
			pass = [self password];
		}		
		
	}
	
	// Ok, that didn't work, let's try the keychain
	if ((!user || !pass) && useKeychainPersistence) {
		NSURLCredential *authenticationCredentials = [ASIHTTPRequest savedCredentialsForHost:[[self url] host] port:[[[self url] port] intValue] protocol:[[self url] scheme] realm:[self authenticationRealm]];
		if (authenticationCredentials) {
			user = [authenticationCredentials user];
			pass = [authenticationCredentials password];
		}
		
	}
	
	// If we have a username and password, let's apply them to the request and continue
	if (user && pass) {
		
		[newCredentials setObject:user forKey:(NSString *)kCFHTTPAuthenticationUsername];
		[newCredentials setObject:pass forKey:(NSString *)kCFHTTPAuthenticationPassword];
		return newCredentials;
	}
	return nil;
}

// Called by delegate or authentication dialog to resume loading once authentication info has been populated
- (void)retryUsingSuppliedCredentials
{
	[self performSelector:@selector(attemptToApplyCredentialsAndResume) onThread:[[self class] threadForRequest:self] withObject:nil waitUntilDone:NO];
}

// Called by delegate or authentication dialog to cancel authentication
- (void)cancelAuthentication
{
	[self performSelector:@selector(failAuthentication) onThread:[[self class] threadForRequest:self] withObject:nil waitUntilDone:NO];
}

- (void)failAuthentication
{
	[self failWithError:ASIAuthenticationError];
}

- (BOOL)showProxyAuthenticationDialog
{
// Mac authentication dialog coming soon!
#if TARGET_OS_IPHONE
	if ([self shouldPresentProxyAuthenticationDialog]) {
		[ASIAuthenticationDialog performSelectorOnMainThread:@selector(presentAuthenticationDialogForRequest:) withObject:self waitUntilDone:[NSThread isMainThread]];
		return YES;
	}
	return NO;
#else
	return NO;
#endif
}


- (BOOL)askDelegateForProxyCredentials
{

	// If we have a delegate, we'll see if it can handle proxyAuthenticationNeededForRequest:.
	// Otherwise, we'll try the queue (if this request is part of one) and it will pass the message on to its own delegate
	id authenticationDelegate = [self delegate];
	if (!authenticationDelegate) {
		authenticationDelegate = [self queue];
	}
	
	if ([authenticationDelegate respondsToSelector:@selector(proxyAuthenticationNeededForRequest:)]) {
		[authenticationDelegate performSelectorOnMainThread:@selector(proxyAuthenticationNeededForRequest:) withObject:self waitUntilDone:[NSThread isMainThread]];
		return YES;
	}
	return NO;
}

- (void)attemptToApplyProxyCredentialsAndResume
{
	
	if ([self error] || [self isCancelled]) {
		return;
	}
	
	// Read authentication data
	if (!proxyAuthentication) {
		CFHTTPMessageRef responseHeader = (CFHTTPMessageRef) CFReadStreamCopyProperty((CFReadStreamRef)[self readStream],kCFStreamPropertyHTTPResponseHeader);
		proxyAuthentication = CFHTTPAuthenticationCreateFromResponse(NULL, responseHeader);
		CFRelease(responseHeader);
		[self setProxyAuthenticationScheme:[(NSString *)CFHTTPAuthenticationCopyMethod(proxyAuthentication) autorelease]];
	}
	
	// If we haven't got a CFHTTPAuthenticationRef by now, something is badly wrong, so we'll have to give up
	if (!proxyAuthentication) {
		[self cancelLoad];
		[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIInternalErrorWhileApplyingCredentialsType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Failed to get authentication object from response headers",NSLocalizedDescriptionKey,nil]]];
		return;
	}
	
	// Get the authentication realm
	[self setProxyAuthenticationRealm:nil];
	if (!CFHTTPAuthenticationRequiresAccountDomain(proxyAuthentication)) {
		[self setProxyAuthenticationRealm:[(NSString *)CFHTTPAuthenticationCopyRealm(proxyAuthentication) autorelease]];
	}
	
	// See if authentication is valid
	CFStreamError err;		
	if (!CFHTTPAuthenticationIsValid(proxyAuthentication, &err)) {
		
		CFRelease(proxyAuthentication);
		proxyAuthentication = NULL;
		
		// check for bad credentials, so we can give the delegate a chance to replace them
		if (err.domain == kCFStreamErrorDomainHTTP && (err.error == kCFStreamErrorHTTPAuthenticationBadUserName || err.error == kCFStreamErrorHTTPAuthenticationBadPassword)) {
			
			// Prevent more than one request from asking for credentials at once
			[delegateAuthenticationLock lock];
			
			// We know the credentials we just presented are bad, we should remove them from the session store too
			[[self class] removeProxyAuthenticationCredentialsFromSessionStore:proxyCredentials];
			[self setProxyCredentials:nil];
			
			
			// If the user cancelled authentication via a dialog presented by another request, our queue may have cancelled us
			if ([self error] || [self isCancelled]) {
				[delegateAuthenticationLock unlock];
				return;
			}
			
			
			// Now we've acquired the lock, it may be that the session contains credentials we can re-use for this request
			if ([self useSessionPersistence]) {
				NSDictionary *credentials = [self findSessionProxyAuthenticationCredentials];
				if (credentials && [self applyProxyCredentials:[credentials objectForKey:@"Credentials"]]) {
					[delegateAuthenticationLock unlock];
					[self startRequest];
					return;
				}
			}
			
			[self setLastActivityTime:nil];
			
			if ([self askDelegateForProxyCredentials]) {
				[self attemptToApplyProxyCredentialsAndResume];
				[delegateAuthenticationLock unlock];
				return;
			}
			if ([self showProxyAuthenticationDialog]) {
				[self attemptToApplyProxyCredentialsAndResume];
				[delegateAuthenticationLock unlock];
				return;
			}
			[delegateAuthenticationLock unlock];
		}
		[self cancelLoad];
		[self failWithError:ASIAuthenticationError];
		return;
	}

	[self cancelLoad];
	
	if (proxyCredentials) {
		
		// We use startRequest rather than starting all over again in load request because NTLM requires we reuse the request
		if ((([self proxyAuthenticationScheme] != (NSString *)kCFHTTPAuthenticationSchemeNTLM) || [self proxyAuthenticationRetryCount] < 2) && [self applyProxyCredentials:proxyCredentials]) {
			[self startRequest];
			
		// We've failed NTLM authentication twice, we should assume our credentials are wrong
		} else if ([self proxyAuthenticationScheme] == (NSString *)kCFHTTPAuthenticationSchemeNTLM && [self proxyAuthenticationRetryCount] == 2) {
			[self failWithError:ASIAuthenticationError];
			
		// Something went wrong, we'll have to give up
		} else {
			[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIInternalErrorWhileApplyingCredentialsType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Failed to apply proxy credentials to request",NSLocalizedDescriptionKey,nil]]];
		}
		
	// Are a user name & password needed?
	}  else if (CFHTTPAuthenticationRequiresUserNameAndPassword(proxyAuthentication)) {
		
		// Prevent more than one request from asking for credentials at once
		[delegateAuthenticationLock lock];
		
		// If the user cancelled authentication via a dialog presented by another request, our queue may have cancelled us
		if ([self error] || [self isCancelled]) {
			[delegateAuthenticationLock unlock];
			return;
		}
		
		// Now we've acquired the lock, it may be that the session contains credentials we can re-use for this request
		if ([self useSessionPersistence]) {
			NSDictionary *credentials = [self findSessionProxyAuthenticationCredentials];
			if (credentials && [self applyProxyCredentials:[credentials objectForKey:@"Credentials"]]) {
				[delegateAuthenticationLock unlock];
				[self startRequest];
				return;
			}
		}
		
		NSMutableDictionary *newCredentials = [self findProxyCredentials];
		
		//If we have some credentials to use let's apply them to the request and continue
		if (newCredentials) {
			
			if ([self applyProxyCredentials:newCredentials]) {
				[delegateAuthenticationLock unlock];
				[self startRequest];
			} else {
				[delegateAuthenticationLock unlock];
				[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIInternalErrorWhileApplyingCredentialsType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Failed to apply proxy credentials to request",NSLocalizedDescriptionKey,nil]]];
			}
			
			return;
		}
		
		if ([self askDelegateForProxyCredentials]) {
			[delegateAuthenticationLock unlock];
			return;
		}
		
		if ([self showProxyAuthenticationDialog]) {
			[delegateAuthenticationLock unlock];
			return;
		}
		[delegateAuthenticationLock unlock];
		
		// The delegate isn't interested and we aren't showing the authentication dialog, we'll have to give up
		[self failWithError:ASIAuthenticationError];
		return;
	}
	
}

- (BOOL)showAuthenticationDialog
{
// Mac authentication dialog coming soon!
#if TARGET_OS_IPHONE
	if ([self shouldPresentAuthenticationDialog]) {
		[ASIAuthenticationDialog performSelectorOnMainThread:@selector(presentAuthenticationDialogForRequest:) withObject:self waitUntilDone:[NSThread isMainThread]];
		return YES;
	}
	return NO;
#else
	return NO;
#endif
}

- (BOOL)askDelegateForCredentials
{
	// If we have a delegate, we'll see if it can handle proxyAuthenticationNeededForRequest:.
	// Otherwise, we'll try the queue (if this request is part of one) and it will pass the message on to its own delegate
	id authenticationDelegate = [self delegate];
	if (!authenticationDelegate) {
		authenticationDelegate = [self queue];
	}
	
	if ([authenticationDelegate respondsToSelector:@selector(authenticationNeededForRequest:)]) {
		[authenticationDelegate performSelectorOnMainThread:@selector(authenticationNeededForRequest:) withObject:self waitUntilDone:[NSThread isMainThread]];
		return YES;
	}
	return NO;
}

- (void)attemptToApplyCredentialsAndResume
{
	if ([self error] || [self isCancelled]) {
		return;
	}
	
	if ([self authenticationNeeded] == ASIProxyAuthenticationNeeded) {
		[self attemptToApplyProxyCredentialsAndResume];
		return;
	}
	
	// Read authentication data
	if (!requestAuthentication) {
		CFHTTPMessageRef responseHeader = (CFHTTPMessageRef) CFReadStreamCopyProperty((CFReadStreamRef)[self readStream],kCFStreamPropertyHTTPResponseHeader);
		requestAuthentication = CFHTTPAuthenticationCreateFromResponse(NULL, responseHeader);
		CFRelease(responseHeader);
		[self setAuthenticationScheme:[(NSString *)CFHTTPAuthenticationCopyMethod(requestAuthentication) autorelease]];
	}
	
	if (!requestAuthentication) {
		[self cancelLoad];
		[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIInternalErrorWhileApplyingCredentialsType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Failed to get authentication object from response headers",NSLocalizedDescriptionKey,nil]]];
		return;
	}
	
	// Get the authentication realm
	[self setAuthenticationRealm:nil];
	if (!CFHTTPAuthenticationRequiresAccountDomain(requestAuthentication)) {
		[self setAuthenticationRealm:[(NSString *)CFHTTPAuthenticationCopyRealm(requestAuthentication) autorelease]];
	}
	
	// See if authentication is valid
	CFStreamError err;		
	if (!CFHTTPAuthenticationIsValid(requestAuthentication, &err)) {
		
		CFRelease(requestAuthentication);
		requestAuthentication = NULL;
		
		// check for bad credentials, so we can give the delegate a chance to replace them
		if (err.domain == kCFStreamErrorDomainHTTP && (err.error == kCFStreamErrorHTTPAuthenticationBadUserName || err.error == kCFStreamErrorHTTPAuthenticationBadPassword)) {
			
			// Prevent more than one request from asking for credentials at once
			[delegateAuthenticationLock lock];
			
			// We know the credentials we just presented are bad, we should remove them from the session store too
			[[self class] removeAuthenticationCredentialsFromSessionStore:requestCredentials];
			[self setRequestCredentials:nil];
			
			// If the user cancelled authentication via a dialog presented by another request, our queue may have cancelled us
			if ([self error] || [self isCancelled]) {
				[delegateAuthenticationLock unlock];
				return;
			}
			
			// Now we've acquired the lock, it may be that the session contains credentials we can re-use for this request
			if ([self useSessionPersistence]) {
				NSDictionary *credentials = [self findSessionAuthenticationCredentials];
				if (credentials && [self applyCredentials:[credentials objectForKey:@"Credentials"]]) {
					[delegateAuthenticationLock unlock];
					[self startRequest];
					return;
				}
			}
			
			
			
			[self setLastActivityTime:nil];
			
			if ([self askDelegateForCredentials]) {
				[delegateAuthenticationLock unlock];
				return;
			}
			if ([self showAuthenticationDialog]) {
				[delegateAuthenticationLock unlock];
				return;
			}
			[delegateAuthenticationLock unlock];
		}
		[self cancelLoad];
		[self failWithError:ASIAuthenticationError];
		return;
	}
	
	[self cancelLoad];
	
	if (requestCredentials) {
		
		if ((([self authenticationScheme] != (NSString *)kCFHTTPAuthenticationSchemeNTLM) || [self authenticationRetryCount] < 2) && [self applyCredentials:requestCredentials]) {
			[self startRequest];
			
			// We've failed NTLM authentication twice, we should assume our credentials are wrong
		} else if ([self authenticationScheme] == (NSString *)kCFHTTPAuthenticationSchemeNTLM && [self authenticationRetryCount ] == 2) {
			[self failWithError:ASIAuthenticationError];
			
		} else {
			[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIInternalErrorWhileApplyingCredentialsType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Failed to apply credentials to request",NSLocalizedDescriptionKey,nil]]];
		}
		
		// Are a user name & password needed?
	}  else if (CFHTTPAuthenticationRequiresUserNameAndPassword(requestAuthentication)) {
		
		// Prevent more than one request from asking for credentials at once
		[delegateAuthenticationLock lock];
		
		// If the user cancelled authentication via a dialog presented by another request, our queue may have cancelled us
		if ([self error] || [self isCancelled]) {
			[delegateAuthenticationLock unlock];
			return;
		}
		
		// Now we've acquired the lock, it may be that the session contains credentials we can re-use for this request
		if ([self useSessionPersistence]) {
			NSDictionary *credentials = [self findSessionAuthenticationCredentials];
			if (credentials && [self applyCredentials:[credentials objectForKey:@"Credentials"]]) {
				[delegateAuthenticationLock unlock];
				[self startRequest];
				return;
			}
		}
		

		NSMutableDictionary *newCredentials = [self findCredentials];
		
		//If we have some credentials to use let's apply them to the request and continue
		if (newCredentials) {
			
			if ([self applyCredentials:newCredentials]) {
				[delegateAuthenticationLock unlock];
				[self startRequest];
			} else {
				[delegateAuthenticationLock unlock];
				[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIInternalErrorWhileApplyingCredentialsType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Failed to apply credentials to request",NSLocalizedDescriptionKey,nil]]];
			}
			return;
		}
		if ([self askDelegateForCredentials]) {
			[delegateAuthenticationLock unlock];
			return;
		}
		
		if ([self showAuthenticationDialog]) {
			[delegateAuthenticationLock unlock];
			return;
		}
		[delegateAuthenticationLock unlock];
		
		[self failWithError:ASIAuthenticationError];

		return;
	}
	
}

- (void)addBasicAuthenticationHeaderWithUsername:(NSString *)theUsername andPassword:(NSString *)thePassword
{
	[self addRequestHeader:@"Authorization" value:[NSString stringWithFormat:@"Basic %@",[ASIHTTPRequest base64forData:[[NSString stringWithFormat:@"%@:%@",theUsername,thePassword] dataUsingEncoding:NSUTF8StringEncoding]]]];	
}


#pragma mark stream status handlers

- (void)handleNetworkEvent:(CFStreamEventType)type
{	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[self retain] autorelease];

	[[self cancelledLock] lock];
	
	if ([self complete] || [self isCancelled]) {
		[[self cancelledLock] unlock];
		[pool release];
		return;
	}
	
    // Dispatch the stream events.
    switch (type) {
        case kCFStreamEventHasBytesAvailable:
            [self handleBytesAvailable];
            break;
            
        case kCFStreamEventEndEncountered:
            [self handleStreamComplete];
            break;
            
        case kCFStreamEventErrorOccurred:
            [self handleStreamError];
            break;
            
        default:
            break;
    }
	
	[self performThrottling];
	
	[[self cancelledLock] unlock];
	
	if ([self downloadComplete] && [self needsRedirect]) {
		[self performRedirect];
	} else if ([self downloadComplete] && [self authenticationNeeded]) {
		[self attemptToApplyCredentialsAndResume];
	}
	[pool release];
}

// This runs on the main thread to run the given invocation on the current delegate
- (void)invocateDelegate:(NSInvocation *)invocation
{
    if (delegate && [delegate respondsToSelector:invocation.selector])
    {
        [invocation invokeWithTarget:delegate];
    }
    [invocation release];
}

- (void)handleBytesAvailable
{
	if (![self responseHeaders]) {
		[self readResponseHeaders];
	}
	
	// If we've cancelled the load part way through (for example, after deciding to use a cached version)
	if ([self complete]) {
		return;
	}
	
	// In certain (presumably very rare) circumstances, handleBytesAvailable seems to be called when there isn't actually any data available
	// We'll check that there is actually data available to prevent blocking on CFReadStreamRead()
	// So far, I've only seen this in the stress tests, so it might never happen in real-world situations.
	if (!CFReadStreamHasBytesAvailable((CFReadStreamRef)[self readStream])) {
		return;
	}

	long long bufferSize = 16384;
	if (contentLength > 262144) {
		bufferSize = 262144;
	} else if (contentLength > 65536) {
		bufferSize = 65536;
	}
	
	// Reduce the buffer size if we're receiving data too quickly when bandwidth throttling is active
	// This just augments the throttling done in measureBandwidthUsage to reduce the amount we go over the limit
	
	if ([[self class] isBandwidthThrottled]) {
		[bandwidthThrottlingLock lock];
		if (maxBandwidthPerSecond > 0) {
			long long maxiumumSize  = (long long)maxBandwidthPerSecond-(long long)bandwidthUsedInLastSecond;
			if (maxiumumSize < 0) {
				// We aren't supposed to read any more data right now, but we'll read a single byte anyway so the CFNetwork's buffer isn't full
				bufferSize = 1;
			} else if (maxiumumSize/4 < bufferSize) {
				// We were going to fetch more data that we should be allowed, so we'll reduce the size of our read
				bufferSize = maxiumumSize/4;
			}
		}
		if (bufferSize < 1) {
			bufferSize = 1;
		}
		[bandwidthThrottlingLock unlock];
	}
	
	
    UInt8 buffer[bufferSize];
    NSInteger bytesRead = [[self readStream] read:buffer maxLength:sizeof(buffer)];

    // Less than zero is an error
    if (bytesRead < 0) {
        [self handleStreamError];
		
	// If zero bytes were read, wait for the EOF to come.
    } else if (bytesRead) {
		
		[self setTotalBytesRead:[self totalBytesRead]+bytesRead];
		[self setLastActivityTime:[NSDate date]];

		// For bandwidth measurement / throttling
		[ASIHTTPRequest incrementBandwidthUsedInLastSecond:bytesRead];
		
		// If we need to redirect, and have automatic redirect on, and might be resuming a download, let's do nothing with the content
		if ([self needsRedirect] && [self shouldRedirect] && [self allowResumeForFileDownloads]) {
			return;
		}
		
		// Does the delegate want to handle the data manually?
		if ([[self delegate] respondsToSelector:[self didReceiveDataSelector]]) {
			NSMethodSignature *signature = [[[self delegate] class] instanceMethodSignatureForSelector:[self didReceiveDataSelector]];
			NSInvocation *invocation = [[NSInvocation invocationWithMethodSignature:signature] retain];
			[invocation setSelector:[self didReceiveDataSelector]];
			[invocation setArgument:&self atIndex:2];
			NSData *data = [NSData dataWithBytes:buffer length:bytesRead];
			[invocation setArgument:&data atIndex:3];
			[invocation retainArguments];
            [self performSelectorOnMainThread:@selector(invocateDelegate:) withObject:invocation waitUntilDone:[NSThread isMainThread]];

		// Are we downloading to a file?
		} else if ([self downloadDestinationPath]) {
			if (![self fileDownloadOutputStream]) {
				BOOL append = NO;
				if (![self temporaryFileDownloadPath]) {
					[self setTemporaryFileDownloadPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]]];
				} else if ([self allowResumeForFileDownloads] && [[self requestHeaders] objectForKey:@"Range"]) {
					if ([[self responseHeaders] objectForKey:@"Content-Range"]) {
						append = YES;
					} else {
						[self incrementDownloadSizeBy:-[self partialDownloadSize]];
						[self setPartialDownloadSize:0];
					}
				}

				[self setFileDownloadOutputStream:[[[NSOutputStream alloc] initToFileAtPath:[self temporaryFileDownloadPath] append:append] autorelease]];
				[[self fileDownloadOutputStream] open];
			}
			[[self fileDownloadOutputStream] write:buffer maxLength:bytesRead];
			
		//Otherwise, let's add the data to our in-memory store
		} else {
			[rawResponseData appendBytes:buffer length:bytesRead];
		}
    }

}

- (void)handleStreamComplete
{	
#if DEBUG_REQUEST_STATUS
	NSLog(@"Request %@ finished downloading data (%qu bytes)",self, [self totalBytesRead]);
#endif
	
	[self setDownloadComplete:YES];
	
	if (![self responseHeaders]) {
		[self readResponseHeaders];
	}

	[progressLock lock];	
	// Find out how much data we've uploaded so far
	[self setLastBytesSent:totalBytesSent];	
	[self setTotalBytesSent:[NSMakeCollectable([(NSNumber *)CFReadStreamCopyProperty((CFReadStreamRef)[self readStream], kCFStreamPropertyHTTPRequestBytesWrittenCount) autorelease]) unsignedLongLongValue]];
	[self setComplete:YES];
	[self updateProgressIndicators];

	
	[[self postBodyReadStream] close];
	
	NSError *fileError = nil;
	
	// Delete up the request body temporary file, if it exists
	if ([self didCreateTemporaryPostDataFile] && ![self authenticationNeeded]) {
		[self removePostDataFile];
	}
	
	// Close the output stream as we're done writing to the file
	if ([self temporaryFileDownloadPath]) {
		[[self fileDownloadOutputStream] close];
		[self setFileDownloadOutputStream:nil];
		
		// If we are going to redirect and we are resuming, let's ignore this download
		if ([self shouldRedirect] && [self needsRedirect] && [self allowResumeForFileDownloads]) {
		
		// Decompress the file (if necessary) directly to the destination path
		} else if ([self isResponseCompressed]) {
			int decompressionStatus = [ASIHTTPRequest uncompressZippedDataFromFile:[self temporaryFileDownloadPath] toFile:[self downloadDestinationPath]];
			if (decompressionStatus != Z_OK) {
				fileError = [NSError errorWithDomain:NetworkRequestErrorDomain code:ASIFileManagementError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Decompression of %@ failed with code %hi",[self temporaryFileDownloadPath],decompressionStatus],NSLocalizedDescriptionKey,nil]];
			}
			[self removeTemporaryDownloadFile];
		} else {
			
	
			//Remove any file at the destination path
			NSError *moveError = nil;
			if ([[NSFileManager defaultManager] fileExistsAtPath:[self downloadDestinationPath]]) {
				[[NSFileManager defaultManager] removeItemAtPath:[self downloadDestinationPath] error:&moveError];
				if (moveError) {
					fileError = [NSError errorWithDomain:NetworkRequestErrorDomain code:ASIFileManagementError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Unable to remove file at path '%@'",[self downloadDestinationPath]],NSLocalizedDescriptionKey,moveError,NSUnderlyingErrorKey,nil]];
				}
			}
					
			//Move the temporary file to the destination path
			if (!fileError) {
				[[NSFileManager defaultManager] moveItemAtPath:[self temporaryFileDownloadPath] toPath:[self downloadDestinationPath] error:&moveError];
				if (moveError) {
					fileError = [NSError errorWithDomain:NetworkRequestErrorDomain code:ASIFileManagementError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Failed to move file from '%@' to '%@'",[self temporaryFileDownloadPath],[self downloadDestinationPath]],NSLocalizedDescriptionKey,moveError,NSUnderlyingErrorKey,nil]];
				}
				[self setTemporaryFileDownloadPath:nil];
			}
			
		}
	}
	
	// Save to the cache
	if ([self downloadCache] && ![self didUseCachedResponse]) {
		[[self downloadCache] storeResponseForRequest:self maxAge:[self secondsToCache]];
	}
	
	[progressLock unlock];

	
	[connectionsLock lock];
	if (![self connectionCanBeReused]) {
		[self unscheduleReadStream];
	}
	#if DEBUG_PERSISTENT_CONNECTIONS
	NSLog(@"Request #%@ finished using connection #%@",[self requestID], [[self connectionInfo] objectForKey:@"id"]);
	#endif
	[[self connectionInfo] removeObjectForKey:@"request"];
	[[self connectionInfo] setObject:[NSDate dateWithTimeIntervalSinceNow:[self persistentConnectionTimeoutSeconds]] forKey:@"expires"];
	[connectionsLock unlock];
	
	if (![self authenticationNeeded]) {
		[self destroyReadStream];
	}
	
	if (![self needsRedirect] && ![self authenticationNeeded] && ![self didUseCachedResponse]) {
		
		if (fileError) {
			[self failWithError:fileError];
		} else {
			[self requestFinished];
		}

		[self markAsFinished];
		
	// If request has asked delegate or ASIAuthenticationDialog for credentials
	} else if ([self authenticationNeeded]) {
		[self setStatusTimer:nil];
		CFRunLoopStop(CFRunLoopGetCurrent());
	}
}

- (void)markAsFinished
{
	// Autoreleased requests may well be dealloced here otherwise
	[self retain];

	// dealloc won't be called when running with GC, so we'll clean these up now
	if (request) {
		CFMakeCollectable(request);
	}
	if (requestAuthentication) {
		CFMakeCollectable(requestAuthentication);
	}
	if (proxyAuthentication) {
		CFMakeCollectable(proxyAuthentication);
	}

    BOOL wasInProgress = inProgress;
    BOOL wasFinished = finished;

    if (!wasFinished)
        [self willChangeValueForKey:@"isFinished"];
    if (wasInProgress)
        [self willChangeValueForKey:@"isExecuting"];

	[self setInProgress:NO];
	[self setStatusTimer:nil];
    finished = YES;

    if (wasInProgress)
        [self didChangeValueForKey:@"isExecuting"];
    if (!wasFinished)
        [self didChangeValueForKey:@"isFinished"];

	CFRunLoopStop(CFRunLoopGetCurrent());

	[self release];
}

- (BOOL)useDataFromCache
{
	NSDictionary *headers = [[self downloadCache] cachedHeadersForRequest:self];
	if (!headers) {
		return NO;
	}
	NSString *dataPath = [[self downloadCache] pathToCachedResponseDataForRequest:self];
	if (!dataPath) {
		return NO;
	}
	
	if ([self cachePolicy] == ASIReloadIfDifferentCachePolicy) {
		if (![[self downloadCache] isCachedDataCurrentForRequest:self]) {
			[[self downloadCache] removeCachedDataForRequest:self];
			return NO;
		}
	}

	// only 200 responses are stored in the cache, so let the client know
	// this was a successful response
	[self setResponseStatusCode:200];
        
	[self setDidUseCachedResponse:YES];
	
	ASIHTTPRequest *theRequest = self;
	if ([self mainRequest]) {
		theRequest = [self mainRequest];
	}
	[theRequest setResponseHeaders:headers];
	if ([theRequest downloadDestinationPath]) {
		[theRequest setDownloadDestinationPath:dataPath];
	} else {
		[theRequest setRawResponseData:[NSMutableData dataWithContentsOfFile:dataPath]];
	}
	[theRequest setContentLength:[[[self responseHeaders] objectForKey:@"Content-Length"] longLongValue]];
	[theRequest setTotalBytesRead:[self contentLength]];

	[theRequest parseStringEncodingFromHeaders];

	[theRequest setResponseCookies:[NSHTTPCookie cookiesWithResponseHeaderFields:headers forURL:[self url]]];

	[theRequest setComplete:YES];
	[theRequest setDownloadComplete:YES];
	
	[theRequest updateProgressIndicators];
	[theRequest requestFinished];
	[theRequest markAsFinished];	
	if ([self mainRequest]) {
		[self markAsFinished];
	}
	return YES;
}

- (BOOL)retryUsingNewConnection
{
	if ([self retryCount] == 0) {
		#if DEBUG_PERSISTENT_CONNECTIONS
			NSLog(@"Request attempted to use connection #%@, but it has been closed - will retry with a new connection", [[self connectionInfo] objectForKey:@"id"]);
		#endif
		[connectionsLock lock];
		[[self connectionInfo] removeObjectForKey:@"request"];
		[persistentConnectionsPool removeObject:[self connectionInfo]];
		[self setConnectionInfo:nil];
		[connectionsLock unlock];
		[self setRetryCount:[self retryCount]+1];
		[self startRequest];
		return YES;
	}
	#if DEBUG_PERSISTENT_CONNECTIONS
		NSLog(@"Request attempted to use connection #%@, but it has been closed - we have already retried with a new connection, so we must give up", [[self connectionInfo] objectForKey:@"id"]);
	#endif	
	return NO;
}

- (void)handleStreamError

{
	NSError *underlyingError = NSMakeCollectable([(NSError *)CFReadStreamCopyError((CFReadStreamRef)[self readStream]) autorelease]);

	[self cancelLoad];
	
	if (![self error]) { // We may already have handled this error
		
		// First, check for a 'socket not connected', 'broken pipe' or 'connection lost' error
		// This may occur when we've attempted to reuse a connection that should have been closed
		// If we get this, we need to retry the request
		// We'll only do this once - if it happens again on retry, we'll give up
		// -1005 = kCFURLErrorNetworkConnectionLost - this doesn't seem to be declared on Mac OS 10.5
		if (([[underlyingError domain] isEqualToString:NSPOSIXErrorDomain] && ([underlyingError code] == ENOTCONN || [underlyingError code] == EPIPE)) 
			|| ([[underlyingError domain] isEqualToString:(NSString *)kCFErrorDomainCFNetwork] && [underlyingError code] == -1005)) {
			if ([self retryUsingNewConnection]) {
				return;
			}
		}
		
		NSString *reason = @"A connection failure occurred";
		
		// We'll use a custom error message for SSL errors, but you should always check underlying error if you want more details
		// For some reason SecureTransport.h doesn't seem to be available on iphone, so error codes hard-coded
		// Also, iPhone seems to handle errors differently from Mac OS X - a self-signed certificate returns a different error code on each platform, so we'll just provide a general error
		if ([[underlyingError domain] isEqualToString:NSOSStatusErrorDomain]) {
			if ([underlyingError code] <= -9800 && [underlyingError code] >= -9818) {
				reason = [NSString stringWithFormat:@"%@: SSL problem (possibly a bad/expired/self-signed certificate)",reason];
			}
		}
		
		[self failWithError:[NSError errorWithDomain:NetworkRequestErrorDomain code:ASIConnectionFailureErrorType userInfo:[NSDictionary dictionaryWithObjectsAndKeys:reason,NSLocalizedDescriptionKey,underlyingError,NSUnderlyingErrorKey,nil]]];
	}
	[self checkRequestStatus];
}

#pragma mark managing the read stream



- (void)destroyReadStream
{
    if ([self readStream]) {
		CFReadStreamSetClient((CFReadStreamRef)[self readStream], kCFStreamEventNone, NULL, NULL);
		[connectionsLock lock];

		if ([self readStreamIsScheduled]) {
			runningRequestCount--;
			if (shouldUpdateNetworkActivityIndicator && runningRequestCount == 0) {
				// Wait half a second before turning off the indicator
				// This can prevent flicker when you have a single request finish and then immediately start another request
				// We will cancel hiding the activity indicator if we start again
				[[self class] performSelector:@selector(hideNetworkActivityIndicator) withObject:nil afterDelay:0.5];
			}
		}

		[self setReadStreamIsScheduled:NO];

		if (![self connectionCanBeReused]) {
			[[self readStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:[self runLoopMode]];
			[[self readStream] close];
		}
		[self setReadStream:nil];
		[connectionsLock unlock];
    }	
}

- (void)scheduleReadStream
{
	if ([self readStream] && ![self readStreamIsScheduled]) {

		[connectionsLock lock];
		runningRequestCount++;
		if (shouldUpdateNetworkActivityIndicator) {
			[NSObject cancelPreviousPerformRequestsWithTarget:[self class] selector:@selector(hideNetworkActivityIndicator) object:nil];
			[[self class] showNetworkActivityIndicator];
		}
		[connectionsLock unlock];

		// Reset the timeout
		[self setLastActivityTime:[NSDate date]];
		[[self readStream] scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:[self runLoopMode]];
		[self setReadStreamIsScheduled:YES];
	}
}


- (void)unscheduleReadStream
{
	if ([self readStream] && [self readStreamIsScheduled]) {

		[connectionsLock lock];
		runningRequestCount--;
		if (shouldUpdateNetworkActivityIndicator && runningRequestCount == 0) {
			// Wait half a second before turning off the indicator
			// This can prevent flicker when you have a single request finish and then immediately start another request
			// We will cancel hiding the activity indicator if we start again
			[[self class] performSelector:@selector(hideNetworkActivityIndicator) withObject:nil afterDelay:0.5];
		}
		[connectionsLock unlock];

		[[self readStream] removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:[self runLoopMode]];
		[self setReadStreamIsScheduled:NO];
	}
}

#pragma mark persistent connections

- (NSNumber *)connectionID
{
	return [[self connectionInfo] objectForKey:@"id"];
}

+ (void)expirePersistentConnections
{
	[connectionsLock lock];
	NSUInteger i;
	for (i=0; i<[persistentConnectionsPool count]; i++) {
		NSDictionary *existingConnection = [persistentConnectionsPool objectAtIndex:i];
		if (![existingConnection objectForKey:@"request"] && [[existingConnection objectForKey:@"expires"] timeIntervalSinceNow] <= 0) {
#if DEBUG_PERSISTENT_CONNECTIONS
			NSLog(@"Closing connection #%i because it has expired",[[existingConnection objectForKey:@"id"] intValue]);
#endif
			NSInputStream *stream = [existingConnection objectForKey:@"stream"];
			if (stream) {
				[stream close];
			}
			[persistentConnectionsPool removeObject:existingConnection];
			i--;
		}
	}	
	[connectionsLock unlock];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	// Don't forget - this will return a retained copy!
	ASIHTTPRequest *newRequest = [[[self class] alloc] initWithURL:[self url]];
	[newRequest setDelegate:[self delegate]];
	[newRequest setRequestMethod:[self requestMethod]];
	[newRequest setPostBody:[self postBody]];
	[newRequest setShouldStreamPostDataFromDisk:[self shouldStreamPostDataFromDisk]];
	[newRequest setPostBodyFilePath:[self postBodyFilePath]];
	[newRequest setRequestHeaders:[[[self requestHeaders] mutableCopyWithZone:zone] autorelease]];
	[newRequest setRequestCookies:[[[self requestCookies] mutableCopyWithZone:zone] autorelease]];
	[newRequest setUseCookiePersistence:[self useCookiePersistence]];
	[newRequest setUseKeychainPersistence:[self useKeychainPersistence]];
	[newRequest setUseSessionPersistence:[self useSessionPersistence]];
	[newRequest setAllowCompressedResponse:[self allowCompressedResponse]];
	[newRequest setDownloadDestinationPath:[self downloadDestinationPath]];
	[newRequest setTemporaryFileDownloadPath:[self temporaryFileDownloadPath]];
	[newRequest setUsername:[self username]];
	[newRequest setPassword:[self password]];
	[newRequest setDomain:[self domain]];
	[newRequest setProxyUsername:[self proxyUsername]];
	[newRequest setProxyPassword:[self proxyPassword]];
	[newRequest setProxyDomain:[self proxyDomain]];
	[newRequest setProxyHost:[self proxyHost]];
	[newRequest setProxyPort:[self proxyPort]];
	[newRequest setProxyType:[self proxyType]];
	[newRequest setUploadProgressDelegate:[self uploadProgressDelegate]];
	[newRequest setDownloadProgressDelegate:[self downloadProgressDelegate]];
	[newRequest setShouldPresentAuthenticationDialog:[self shouldPresentAuthenticationDialog]];
	[newRequest setShouldPresentProxyAuthenticationDialog:[self shouldPresentProxyAuthenticationDialog]];
	[newRequest setPostLength:[self postLength]];
	[newRequest setHaveBuiltPostBody:[self haveBuiltPostBody]];
	[newRequest setDidStartSelector:[self didStartSelector]];
	[newRequest setDidFinishSelector:[self didFinishSelector]];
	[newRequest setDidFailSelector:[self didFailSelector]];
	[newRequest setTimeOutSeconds:[self timeOutSeconds]];
	[newRequest setShouldResetDownloadProgress:[self shouldResetDownloadProgress]];
	[newRequest setShouldResetUploadProgress:[self shouldResetUploadProgress]];
	[newRequest setShowAccurateProgress:[self showAccurateProgress]];
	[newRequest setDefaultResponseEncoding:[self defaultResponseEncoding]];
	[newRequest setAllowResumeForFileDownloads:[self allowResumeForFileDownloads]];
	[newRequest setUserInfo:[[[self userInfo] copyWithZone:zone] autorelease]];
	[newRequest setUseHTTPVersionOne:[self useHTTPVersionOne]];
	[newRequest setShouldRedirect:[self shouldRedirect]];
	[newRequest setValidatesSecureCertificate:[self validatesSecureCertificate]];
    [newRequest setClientCertificateIdentity:clientCertificateIdentity];
	[newRequest setClientCertificates:[[clientCertificates copy] autorelease]];
	[newRequest setPACurl:[self PACurl]];
	[newRequest setShouldPresentCredentialsBeforeChallenge:[self shouldPresentCredentialsBeforeChallenge]];
	[newRequest setNumberOfTimesToRetryOnTimeout:[self numberOfTimesToRetryOnTimeout]];
	[newRequest setShouldUseRFC2616RedirectBehaviour:[self shouldUseRFC2616RedirectBehaviour]];
	[newRequest setShouldAttemptPersistentConnection:[self shouldAttemptPersistentConnection]];
	[newRequest setPersistentConnectionTimeoutSeconds:[self persistentConnectionTimeoutSeconds]];
	return newRequest;
}

#pragma mark default time out

+ (NSTimeInterval)defaultTimeOutSeconds
{
	return defaultTimeOutSeconds;
}

+ (void)setDefaultTimeOutSeconds:(NSTimeInterval)newTimeOutSeconds
{
	defaultTimeOutSeconds = newTimeOutSeconds;
}


#pragma mark client certificate

- (void)setClientCertificateIdentity:(SecIdentityRef)anIdentity {
    if(clientCertificateIdentity) {
        CFRelease(clientCertificateIdentity);
    }
    
    clientCertificateIdentity = anIdentity;
    
	if (clientCertificateIdentity) {
		CFRetain(clientCertificateIdentity);
	}
}


#pragma mark session credentials

+ (NSMutableArray *)sessionProxyCredentialsStore
{
	[sessionCredentialsLock lock];
	if (!sessionProxyCredentialsStore) {
		sessionProxyCredentialsStore = [[NSMutableArray alloc] init];
	}
	[sessionCredentialsLock unlock];
	return sessionProxyCredentialsStore;
}

+ (NSMutableArray *)sessionCredentialsStore
{
	[sessionCredentialsLock lock];
	if (!sessionCredentialsStore) {
		sessionCredentialsStore = [[NSMutableArray alloc] init];
	}
	[sessionCredentialsLock unlock];
	return sessionCredentialsStore;
}

+ (void)storeProxyAuthenticationCredentialsInSessionStore:(NSDictionary *)credentials
{
	[sessionCredentialsLock lock];
	[self removeProxyAuthenticationCredentialsFromSessionStore:[credentials objectForKey:@"Credentials"]];
	[[[self class] sessionProxyCredentialsStore] addObject:credentials];
	[sessionCredentialsLock unlock];
}

+ (void)storeAuthenticationCredentialsInSessionStore:(NSDictionary *)credentials
{
	[sessionCredentialsLock lock];
	[self removeAuthenticationCredentialsFromSessionStore:[credentials objectForKey:@"Credentials"]];
	[[[self class] sessionCredentialsStore] addObject:credentials];
	[sessionCredentialsLock unlock];
}

+ (void)removeProxyAuthenticationCredentialsFromSessionStore:(NSDictionary *)credentials
{
	[sessionCredentialsLock lock];
	NSMutableArray *sessionCredentialsList = [[self class] sessionProxyCredentialsStore];
	NSUInteger i;
	for (i=0; i<[sessionCredentialsList count]; i++) {
		NSDictionary *theCredentials = [sessionCredentialsList objectAtIndex:i];
		if ([theCredentials objectForKey:@"Credentials"] == credentials) {
			[sessionCredentialsList removeObjectAtIndex:i];
			[sessionCredentialsLock unlock];
			return;
		}
	}
	[sessionCredentialsLock unlock];
}

+ (void)removeAuthenticationCredentialsFromSessionStore:(NSDictionary *)credentials
{
	[sessionCredentialsLock lock];
	NSMutableArray *sessionCredentialsList = [[self class] sessionCredentialsStore];
	NSUInteger i;
	for (i=0; i<[sessionCredentialsList count]; i++) {
		NSDictionary *theCredentials = [sessionCredentialsList objectAtIndex:i];
		if ([theCredentials objectForKey:@"Credentials"] == credentials) {
			[sessionCredentialsList removeObjectAtIndex:i];
			[sessionCredentialsLock unlock];
			return;
		}
	}
	[sessionCredentialsLock unlock];
}

- (NSDictionary *)findSessionProxyAuthenticationCredentials
{
	[sessionCredentialsLock lock];
	NSMutableArray *sessionCredentialsList = [[self class] sessionProxyCredentialsStore];
	for (NSDictionary *theCredentials in sessionCredentialsList) {
		if ([[theCredentials objectForKey:@"Host"] isEqualToString:[self proxyHost]] && [[theCredentials objectForKey:@"Port"] intValue] == [self proxyPort]) {
			[sessionCredentialsLock unlock];
			return theCredentials;
		}
	}
	[sessionCredentialsLock unlock];
	return nil;
}


- (NSDictionary *)findSessionAuthenticationCredentials
{
	[sessionCredentialsLock lock];
	NSMutableArray *sessionCredentialsList = [[self class] sessionCredentialsStore];
	// Find an exact match (same url)
	for (NSDictionary *theCredentials in sessionCredentialsList) {
		if ([[theCredentials objectForKey:@"URL"] isEqual:[self url]]) {
			// /Just a sanity check to ensure we never choose credentials from a different realm. Can't really do more than that, as either this request or the stored credentials may not have a realm when the other does
			if (![self responseStatusCode] || (![theCredentials objectForKey:@"AuthenticationRealm"] || [[theCredentials objectForKey:@"AuthenticationRealm"] isEqualToString:[self authenticationRealm]])) {
				[sessionCredentialsLock unlock];
				return theCredentials;
			}
		}
	}
	// Find a rough match (same host, port, scheme)
	NSURL *requestURL = [self url];
	for (NSDictionary *theCredentials in sessionCredentialsList) {
		NSURL *theURL = [theCredentials objectForKey:@"URL"];
		
		// Port can be nil!
		if ([[theURL host] isEqualToString:[requestURL host]] && ([theURL port] == [requestURL port] || ([requestURL port] && [[theURL port] isEqualToNumber:[requestURL port]])) && [[theURL scheme] isEqualToString:[requestURL scheme]]) {
			if (![self responseStatusCode] || (![theCredentials objectForKey:@"AuthenticationRealm"] || [[theCredentials objectForKey:@"AuthenticationRealm"] isEqualToString:[self authenticationRealm]])) {
				[sessionCredentialsLock unlock];
				return theCredentials;
			}
		}
	}
	[sessionCredentialsLock unlock];
	return nil;
}

#pragma mark keychain storage

+ (void)saveCredentials:(NSURLCredential *)credentials forHost:(NSString *)host port:(int)port protocol:(NSString *)protocol realm:(NSString *)realm
{
	NSURLProtectionSpace *protectionSpace = [[[NSURLProtectionSpace alloc] initWithHost:host port:port protocol:protocol realm:realm authenticationMethod:NSURLAuthenticationMethodDefault] autorelease];
	[[NSURLCredentialStorage sharedCredentialStorage] setDefaultCredential:credentials forProtectionSpace:protectionSpace];
}

+ (void)saveCredentials:(NSURLCredential *)credentials forProxy:(NSString *)host port:(int)port realm:(NSString *)realm
{
	NSURLProtectionSpace *protectionSpace = [[[NSURLProtectionSpace alloc] initWithProxyHost:host port:port type:NSURLProtectionSpaceHTTPProxy realm:realm authenticationMethod:NSURLAuthenticationMethodDefault] autorelease];
	[[NSURLCredentialStorage sharedCredentialStorage] setDefaultCredential:credentials forProtectionSpace:protectionSpace];
}

+ (NSURLCredential *)savedCredentialsForHost:(NSString *)host port:(int)port protocol:(NSString *)protocol realm:(NSString *)realm
{
	NSURLProtectionSpace *protectionSpace = [[[NSURLProtectionSpace alloc] initWithHost:host port:port protocol:protocol realm:realm authenticationMethod:NSURLAuthenticationMethodDefault] autorelease];
	return [[NSURLCredentialStorage sharedCredentialStorage] defaultCredentialForProtectionSpace:protectionSpace];
}

+ (NSURLCredential *)savedCredentialsForProxy:(NSString *)host port:(int)port protocol:(NSString *)protocol realm:(NSString *)realm
{
	NSURLProtectionSpace *protectionSpace = [[[NSURLProtectionSpace alloc] initWithProxyHost:host port:port type:NSURLProtectionSpaceHTTPProxy realm:realm authenticationMethod:NSURLAuthenticationMethodDefault] autorelease];
	return [[NSURLCredentialStorage sharedCredentialStorage] defaultCredentialForProtectionSpace:protectionSpace];
}

+ (void)removeCredentialsForHost:(NSString *)host port:(int)port protocol:(NSString *)protocol realm:(NSString *)realm
{
	NSURLProtectionSpace *protectionSpace = [[[NSURLProtectionSpace alloc] initWithHost:host port:port protocol:protocol realm:realm authenticationMethod:NSURLAuthenticationMethodDefault] autorelease];
	NSURLCredential *credential = [[NSURLCredentialStorage sharedCredentialStorage] defaultCredentialForProtectionSpace:protectionSpace];
	if (credential) {
		[[NSURLCredentialStorage sharedCredentialStorage] removeCredential:credential forProtectionSpace:protectionSpace];
	}
}

+ (void)removeCredentialsForProxy:(NSString *)host port:(int)port realm:(NSString *)realm
{
	NSURLProtectionSpace *protectionSpace = [[[NSURLProtectionSpace alloc] initWithProxyHost:host port:port type:NSURLProtectionSpaceHTTPProxy realm:realm authenticationMethod:NSURLAuthenticationMethodDefault] autorelease];
	NSURLCredential *credential = [[NSURLCredentialStorage sharedCredentialStorage] defaultCredentialForProtectionSpace:protectionSpace];
	if (credential) {
		[[NSURLCredentialStorage sharedCredentialStorage] removeCredential:credential forProtectionSpace:protectionSpace];
	}
}


+ (NSMutableArray *)sessionCookies
{
	if (!sessionCookies) {
		[ASIHTTPRequest setSessionCookies:[[[NSMutableArray alloc] init] autorelease]];
	}
	return sessionCookies;
}

+ (void)setSessionCookies:(NSMutableArray *)newSessionCookies
{
	[sessionCookiesLock lock];
	// Remove existing cookies from the persistent store
	for (NSHTTPCookie *cookie in sessionCookies) {
		[[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
	}
	[sessionCookies release];
	sessionCookies = [newSessionCookies retain];
	[sessionCookiesLock unlock];
}

+ (void)addSessionCookie:(NSHTTPCookie *)newCookie
{
	[sessionCookiesLock lock];
	NSHTTPCookie *cookie;
	NSUInteger i;
	NSUInteger max = [[ASIHTTPRequest sessionCookies] count];
	for (i=0; i<max; i++) {
		cookie = [[ASIHTTPRequest sessionCookies] objectAtIndex:i];
		if ([[cookie domain] isEqualToString:[newCookie domain]] && [[cookie path] isEqualToString:[newCookie path]] && [[cookie name] isEqualToString:[newCookie name]]) {
			[[ASIHTTPRequest sessionCookies] removeObjectAtIndex:i];
			break;
		}
	}
	[[ASIHTTPRequest sessionCookies] addObject:newCookie];
	[sessionCookiesLock unlock];
}

// Dump all session data (authentication and cookies)
+ (void)clearSession
{
	[sessionCredentialsLock lock];
	[[[self class] sessionCredentialsStore] removeAllObjects];
	[sessionCredentialsLock unlock];
	[[self class] setSessionCookies:nil];
	[[[self class] defaultCache] clearCachedResponsesForStoragePolicy:ASICacheForSessionDurationCacheStoragePolicy];
}

#pragma mark gzip decompression

//
// Contributed by Shaun Harrison of Enormego, see: http://developers.enormego.com/view/asihttprequest_gzip
// Based on this: http://deusty.blogspot.com/2007/07/gzip-compressiondecompression.html
//
+ (NSData *)uncompressZippedData:(NSData*)compressedData
{
	if ([compressedData length] == 0) return compressedData;
	
	NSUInteger full_length = [compressedData length];
	NSUInteger half_length = [compressedData length] / 2;
	
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	strm.next_in = (Bytef *)[compressedData bytes];
	strm.avail_in = (unsigned int)[compressedData length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (inflateInit2(&strm, (15+32)) != Z_OK) return nil;
	
	while (!done) {
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length]) {
			[decompressed increaseLengthBy: half_length];
		}
		strm.next_out = [decompressed mutableBytes] + strm.total_out;
		strm.avail_out = (unsigned int)([decompressed length] - strm.total_out);
		
		// Inflate another chunk.
		status = inflate (&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END) {
			done = YES;
		} else if (status != Z_OK) {
			break;
		}
	}
	if (inflateEnd (&strm) != Z_OK) return nil;
	
	// Set real length.
	if (done) {
		[decompressed setLength: strm.total_out];
		return [NSData dataWithData: decompressed];
	} else {
		return nil;
	}
}

// NOTE: To debug this method, turn off Data Formatters in Xcode or you'll crash on closeFile
+ (int)uncompressZippedDataFromFile:(NSString *)sourcePath toFile:(NSString *)destinationPath
{
	// Create an empty file at the destination path
	if (![[NSFileManager defaultManager] createFileAtPath:destinationPath contents:[NSData data] attributes:nil]) {
		return 1;
	}
	
	// Get a FILE struct for the source file
	NSFileHandle *inputFileHandle = [NSFileHandle fileHandleForReadingAtPath:sourcePath];
	FILE *source = fdopen([inputFileHandle fileDescriptor], "r");
	
	// Get a FILE struct for the destination path
	NSFileHandle *outputFileHandle = [NSFileHandle fileHandleForWritingAtPath:destinationPath];
	FILE *dest = fdopen([outputFileHandle fileDescriptor], "w");
	
	
	// Uncompress data in source and save in destination
	int status = [ASIHTTPRequest uncompressZippedDataFromSource:source toDestination:dest];
	
	// Close the files
	fclose(dest);
	fclose(source);
	[inputFileHandle closeFile];
	[outputFileHandle closeFile];	
	return status;
}

//
// From the zlib sample code by Mark Adler, code here:
//	http://www.zlib.net/zpipe.c
//
#define CHUNK 16384

+ (int)uncompressZippedDataFromSource:(FILE *)source toDestination:(FILE *)dest
{
    int ret;
    unsigned have;
    z_stream strm;
    unsigned char in[CHUNK];
    unsigned char out[CHUNK];
	
    /* allocate inflate state */
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.avail_in = 0;
    strm.next_in = Z_NULL;
    ret = inflateInit2(&strm, (15+32));
    if (ret != Z_OK)
        return ret;
	
    /* decompress until deflate stream ends or end of file */
    do {
        strm.avail_in = (unsigned int)fread(in, 1, CHUNK, source);
        if (ferror(source)) {
            (void)inflateEnd(&strm);
            return Z_ERRNO;
        }
        if (strm.avail_in == 0)
            break;
        strm.next_in = in;
		
        /* run inflate() on input until output buffer not full */
        do {
            strm.avail_out = CHUNK;
            strm.next_out = out;
            ret = inflate(&strm, Z_NO_FLUSH);
            assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
            switch (ret) {
				case Z_NEED_DICT:
					ret = Z_DATA_ERROR;     /* and fall through */
				case Z_DATA_ERROR:
				case Z_MEM_ERROR:
					(void)inflateEnd(&strm);
					return ret;
            }
            have = CHUNK - strm.avail_out;
            if (fwrite(&out, 1, have, dest) != have || ferror(dest)) {
                (void)inflateEnd(&strm);
                return Z_ERRNO;
            }
        } while (strm.avail_out == 0);
		
        /* done when inflate() says it's done */
    } while (ret != Z_STREAM_END);
	
    /* clean up and return */
    (void)inflateEnd(&strm);
    return ret == Z_STREAM_END ? Z_OK : Z_DATA_ERROR;
}


#pragma mark gzip compression

// Based on this from Robbie Hanson: http://deusty.blogspot.com/2007/07/gzip-compressiondecompression.html

+ (NSData *)compressData:(NSData*)uncompressedData
{
	if ([uncompressedData length] == 0) return uncompressedData;
	
	z_stream strm;
	
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.total_out = 0;
	strm.next_in=(Bytef *)[uncompressedData bytes];
	strm.avail_in = (unsigned int)[uncompressedData length];
	
	// Compresssion Levels:
	//   Z_NO_COMPRESSION
	//   Z_BEST_SPEED
	//   Z_BEST_COMPRESSION
	//   Z_DEFAULT_COMPRESSION
	
	if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) return nil;
	
	NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chunks for expansion
	
	do {
		
		if (strm.total_out >= [compressed length])
			[compressed increaseLengthBy: 16384];
		
		strm.next_out = [compressed mutableBytes] + strm.total_out;
		strm.avail_out = (unsigned int)([compressed length] - strm.total_out);
		
		deflate(&strm, Z_FINISH);  
		
	} while (strm.avail_out == 0);
	
	deflateEnd(&strm);
	
	[compressed setLength: strm.total_out];
	return [NSData dataWithData:compressed];
}

// NOTE: To debug this method, turn off Data Formatters in Xcode or you'll crash on closeFile
+ (int)compressDataFromFile:(NSString *)sourcePath toFile:(NSString *)destinationPath
{
	// Create an empty file at the destination path
	[[NSFileManager defaultManager] createFileAtPath:destinationPath contents:[NSData data] attributes:nil];
	
	// Get a FILE struct for the source file
	NSFileHandle *inputFileHandle = [NSFileHandle fileHandleForReadingAtPath:sourcePath];
	FILE *source = fdopen([inputFileHandle fileDescriptor], "r");

	// Get a FILE struct for the destination path
	NSFileHandle *outputFileHandle = [NSFileHandle fileHandleForWritingAtPath:destinationPath];
	FILE *dest = fdopen([outputFileHandle fileDescriptor], "w");

	// compress data in source and save in destination
	int status = [ASIHTTPRequest compressDataFromSource:source toDestination:dest];

	// Close the files
	fclose(dest);
	fclose(source);
	
	// We have to close both of these explictly because CFReadStreamCreateForStreamedHTTPRequest() seems to go bonkers otherwise
	[inputFileHandle closeFile];
	[outputFileHandle closeFile];

	return status;
}

//
// Also from the zlib sample code  at http://www.zlib.net/zpipe.c
// 
+ (int)compressDataFromSource:(FILE *)source toDestination:(FILE *)dest
{
    int ret, flush;
    unsigned have;
    z_stream strm;
    unsigned char in[CHUNK];
    unsigned char out[CHUNK];
	
    /* allocate deflate state */
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    ret = deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY);
    if (ret != Z_OK)
        return ret;
	
    /* compress until end of file */
    do {
        strm.avail_in = (unsigned int)fread(in, 1, CHUNK, source);
        if (ferror(source)) {
            (void)deflateEnd(&strm);
            return Z_ERRNO;
        }
        flush = feof(source) ? Z_FINISH : Z_NO_FLUSH;
        strm.next_in = in;
		
        /* run deflate() on input until output buffer not full, finish
		 compression if all of source has been read in */
        do {
            strm.avail_out = CHUNK;
            strm.next_out = out;
            ret = deflate(&strm, flush);    /* no bad return value */
            assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
            have = CHUNK - strm.avail_out;
            if (fwrite(out, 1, have, dest) != have || ferror(dest)) {
                (void)deflateEnd(&strm);
                return Z_ERRNO;
            }
        } while (strm.avail_out == 0);
        assert(strm.avail_in == 0);     /* all input will be used */
		
        /* done when last data in file processed */
    } while (flush != Z_FINISH);
    assert(ret == Z_STREAM_END);        /* stream will be complete */
	
    /* clean up and return */
    (void)deflateEnd(&strm);
    return Z_OK;
}

#pragma mark get user agent

+ (NSString *)defaultUserAgentString
{
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];

	// Attempt to find a name for this application
	NSString *appName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (!appName) {
		appName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];	
	}
	// If we couldn't find one, we'll give up (and ASIHTTPRequest will use the standard CFNetwork user agent)
	if (!appName) {
		return nil;
	}
	NSString *appVersion = nil;
	NSString *marketingVersionNumber = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *developmentVersionNumber = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
	if (marketingVersionNumber && developmentVersionNumber) {
		if ([marketingVersionNumber isEqualToString:developmentVersionNumber]) {
			appVersion = marketingVersionNumber;
		} else {
			appVersion = [NSString stringWithFormat:@"%@ rv:%@",marketingVersionNumber,developmentVersionNumber];
		}
	} else {
		appVersion = (marketingVersionNumber ? marketingVersionNumber : developmentVersionNumber);
	}
	
	
	NSString *deviceName;
	NSString *OSName;
	NSString *OSVersion;
	
	NSString *locale = [[NSLocale currentLocale] localeIdentifier];
	
#if TARGET_OS_IPHONE
	UIDevice *device = [UIDevice currentDevice];
	deviceName = [device model];
	OSName = [device systemName];
	OSVersion = [device systemVersion];
	
#else
	deviceName = @"Macintosh";
	OSName = @"Mac OS X";
	
	// From http://www.cocoadev.com/index.pl?DeterminingOSVersion
	// We won't bother to check for systems prior to 10.4, since ASIHTTPRequest only works on 10.5+
    OSErr err;
    SInt32 versionMajor, versionMinor, versionBugFix;
	err = Gestalt(gestaltSystemVersionMajor, &versionMajor);
	if (err != noErr) return nil;
	err = Gestalt(gestaltSystemVersionMinor, &versionMinor);
	if (err != noErr) return nil;
	err = Gestalt(gestaltSystemVersionBugFix, &versionBugFix);
	if (err != noErr) return nil;
	OSVersion = [NSString stringWithFormat:@"%u.%u.%u", versionMajor, versionMinor, versionBugFix];
	
#endif
	// Takes the form "My Application 1.0 (Macintosh; Mac OS X 10.5.7; en_GB)"
	return [NSString stringWithFormat:@"%@ %@ (%@; %@ %@; %@)", appName, appVersion, deviceName, OSName, OSVersion, locale];
}

#pragma mark proxy autoconfiguration

// Returns an array of proxies to use for a particular url, given the url of a PAC script
+ (NSArray *)proxiesForURL:(NSURL *)theURL fromPAC:(NSURL *)pacScriptURL
{
	// From: http://developer.apple.com/samplecode/CFProxySupportTool/listing1.html
	// Work around <rdar://problem/5530166>.  This dummy call to 
	// CFNetworkCopyProxiesForURL initialise some state within CFNetwork 
	// that is required by CFNetworkCopyProxiesForAutoConfigurationScript.
	CFRelease(CFNetworkCopyProxiesForURL((CFURLRef)theURL, NULL));
	
	NSStringEncoding encoding;
	NSError *err = nil;
	NSString *script = [NSString stringWithContentsOfURL:pacScriptURL usedEncoding:&encoding error:&err];
	if (err) {
		// If we can't fetch the PAC, we'll assume no proxies
		// Some people have a PAC configured that is not always available, so I think this is the best behaviour
		return [NSArray array];
	}
	// Obtain the list of proxies by running the autoconfiguration script
	CFErrorRef err2 = NULL;
	NSArray *proxies = NSMakeCollectable([(NSArray *)CFNetworkCopyProxiesForAutoConfigurationScript((CFStringRef)script,(CFURLRef)theURL, &err2) autorelease]);
	if (err2) {
		return nil;
	}
	return proxies;
}

#pragma mark mime-type detection

+ (NSString *)mimeTypeForFileAtPath:(NSString *)path
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		return nil;
	}
	// Borrowed from http://stackoverflow.com/questions/2439020/wheres-the-iphone-mime-type-database
	CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[path pathExtension], NULL);
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
	if (!MIMEType) {
		return @"application/octet-stream";
	}
    return NSMakeCollectable([(NSString *)MIMEType autorelease]);
}

#pragma mark bandwidth measurement / throttling

- (void)performThrottling
{
	if (![self readStream]) {
		return;
	}
	[ASIHTTPRequest measureBandwidthUsage];
	if ([ASIHTTPRequest isBandwidthThrottled]) {
		[bandwidthThrottlingLock lock];
		// Handle throttling
		if (throttleWakeUpTime) {
			if ([throttleWakeUpTime timeIntervalSinceDate:[NSDate date]] > 0) {
				if ([self readStreamIsScheduled]) {
					[self unscheduleReadStream];
					#if DEBUG_THROTTLING
					NSLog(@"Sleeping request %@ until after %@",self,throttleWakeUpTime);
					#endif
				}
			} else {
				if (![self readStreamIsScheduled]) {
					[self scheduleReadStream];
					#if DEBUG_THROTTLING
					NSLog(@"Waking up request %@",self);
					#endif
				}
			}
		} 
		[bandwidthThrottlingLock unlock];
		
	// Bandwidth throttling must have been turned off since we last looked, let's re-schedule the stream
	} else if (![self readStreamIsScheduled]) {
		[self scheduleReadStream];			
	}
}

+ (BOOL)isBandwidthThrottled
{
#if TARGET_OS_IPHONE
	[bandwidthThrottlingLock lock];

	BOOL throttle = isBandwidthThrottled || (!shouldThrottleBandwithForWWANOnly && (maxBandwidthPerSecond));
	[bandwidthThrottlingLock unlock];
	return throttle;
#else
	[bandwidthThrottlingLock lock];
	BOOL throttle = (maxBandwidthPerSecond);
	[bandwidthThrottlingLock unlock];
	return throttle;
#endif
}

+ (unsigned long)maxBandwidthPerSecond
{
	[bandwidthThrottlingLock lock];
	unsigned long amount = maxBandwidthPerSecond;
	[bandwidthThrottlingLock unlock];
	return amount;
}

+ (void)setMaxBandwidthPerSecond:(unsigned long)bytes
{
	[bandwidthThrottlingLock lock];
	maxBandwidthPerSecond = bytes;
	[bandwidthThrottlingLock unlock];
}

+ (void)incrementBandwidthUsedInLastSecond:(unsigned long)bytes
{
	[bandwidthThrottlingLock lock];
	bandwidthUsedInLastSecond += bytes;
	[bandwidthThrottlingLock unlock];
}

+ (void)recordBandwidthUsage
{
	if (bandwidthUsedInLastSecond == 0) {
		[bandwidthUsageTracker removeAllObjects];
	} else {
		NSTimeInterval interval = [bandwidthMeasurementDate timeIntervalSinceNow];
		while ((interval < 0 || [bandwidthUsageTracker count] > 5) && [bandwidthUsageTracker count] > 0) {
			[bandwidthUsageTracker removeObjectAtIndex:0];
			interval++;
		}
	}
	#if DEBUG_THROTTLING
	NSLog(@"===Used: %u bytes of bandwidth in last measurement period===",bandwidthUsedInLastSecond);
	#endif
	[bandwidthUsageTracker addObject:[NSNumber numberWithUnsignedLong:bandwidthUsedInLastSecond]];
	[bandwidthMeasurementDate release];
	bandwidthMeasurementDate = [[NSDate dateWithTimeIntervalSinceNow:1] retain];
	bandwidthUsedInLastSecond = 0;
	
	NSUInteger measurements = [bandwidthUsageTracker count];
	unsigned long totalBytes = 0;
	for (NSNumber *bytes in bandwidthUsageTracker) {
		totalBytes += [bytes unsignedLongValue];
	}
	averageBandwidthUsedPerSecond = totalBytes/measurements;		
}

+ (unsigned long)averageBandwidthUsedPerSecond
{
	[bandwidthThrottlingLock lock];
	unsigned long amount = 	averageBandwidthUsedPerSecond;
	[bandwidthThrottlingLock unlock];
	return amount;
}

+ (void)measureBandwidthUsage
{
	// Other requests may have to wait for this lock if we're sleeping, but this is fine, since in that case we already know they shouldn't be sending or receiving data
	[bandwidthThrottlingLock lock];

	if (!bandwidthMeasurementDate || [bandwidthMeasurementDate timeIntervalSinceNow] < -0) {
		[ASIHTTPRequest recordBandwidthUsage];
	}
	
	// Are we performing bandwidth throttling?
	if (
	#if TARGET_OS_IPHONE
	isBandwidthThrottled || (!shouldThrottleBandwithForWWANOnly && (maxBandwidthPerSecond))
	#else
	maxBandwidthPerSecond
	#endif
	) {
		// How much data can we still send or receive this second?
		long long bytesRemaining = (long long)maxBandwidthPerSecond - (long long)bandwidthUsedInLastSecond;
			
		// Have we used up our allowance?
		if (bytesRemaining < 0) {
			
			// Yes, put this request to sleep until a second is up, with extra added punishment sleeping time for being very naughty (we have used more bandwidth than we were allowed)
			double extraSleepyTime = (-bytesRemaining/(maxBandwidthPerSecond*1.0));
			[throttleWakeUpTime release];
			throttleWakeUpTime = [[NSDate alloc] initWithTimeInterval:extraSleepyTime sinceDate:bandwidthMeasurementDate];
		}
	}
	[bandwidthThrottlingLock unlock];
}
	
+ (unsigned long)maxUploadReadLength
{
	
	[bandwidthThrottlingLock lock];
	
	// We'll split our bandwidth allowance into 4 (which is the default for an ASINetworkQueue's max concurrent operations count) to give all running requests a fighting chance of reading data this cycle
	long long toRead = maxBandwidthPerSecond/4;
	if (maxBandwidthPerSecond > 0 && (bandwidthUsedInLastSecond + toRead > maxBandwidthPerSecond)) {
		toRead = (long long)maxBandwidthPerSecond-(long long)bandwidthUsedInLastSecond;
		if (toRead < 0) {
			toRead = 0;
		}
	}
	
	if (toRead == 0 || !bandwidthMeasurementDate || [bandwidthMeasurementDate timeIntervalSinceNow] < -0) {
		[throttleWakeUpTime release];
		throttleWakeUpTime = [bandwidthMeasurementDate retain];
	}
	[bandwidthThrottlingLock unlock];	
	return (unsigned long)toRead;
}
	

#if TARGET_OS_IPHONE
+ (void)setShouldThrottleBandwidthForWWAN:(BOOL)throttle
{
	if (throttle) {
		[ASIHTTPRequest throttleBandwidthForWWANUsingLimit:ASIWWANBandwidthThrottleAmount];
	} else {
		[ASIHTTPRequest unsubscribeFromNetworkReachabilityNotifications];
		[ASIHTTPRequest setMaxBandwidthPerSecond:0];
		[bandwidthThrottlingLock lock];
		isBandwidthThrottled = NO;
		shouldThrottleBandwithForWWANOnly = NO;
		[bandwidthThrottlingLock unlock];
	}
}

+ (void)throttleBandwidthForWWANUsingLimit:(unsigned long)limit
{	
	[bandwidthThrottlingLock lock];
	shouldThrottleBandwithForWWANOnly = YES;
	maxBandwidthPerSecond = limit;
	[ASIHTTPRequest registerForNetworkReachabilityNotifications];	
	[bandwidthThrottlingLock unlock];
	[ASIHTTPRequest reachabilityChanged:nil];
}

#pragma mark reachability

+ (void)registerForNetworkReachabilityNotifications
{
	[[Reachability reachabilityForInternetConnection] startNotifier];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
}


+ (void)unsubscribeFromNetworkReachabilityNotifications
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
}

+ (BOOL)isNetworkReachableViaWWAN
{
	return ([[Reachability reachabilityForInternetConnection] currentReachabilityStatus] == ReachableViaWWAN);	
}

+ (void)reachabilityChanged:(NSNotification *)note
{
	[bandwidthThrottlingLock lock];
	isBandwidthThrottled = [ASIHTTPRequest isNetworkReachableViaWWAN];
	[bandwidthThrottlingLock unlock];
}
#endif

#pragma mark queue

// Returns the shared queue
+ (NSOperationQueue *)sharedQueue
{
    return [[sharedQueue retain] autorelease];
}

#pragma mark cache

+ (void)setDefaultCache:(id <ASICacheDelegate>)cache
{
	[defaultCache release];
	defaultCache = [cache retain];
}

+ (id <ASICacheDelegate>)defaultCache
{
	return defaultCache;
}


#pragma mark network activity

+ (BOOL)isNetworkInUse
{
	[connectionsLock lock];
	BOOL inUse = (runningRequestCount > 0);
	[connectionsLock unlock];
	return inUse;
}

+ (void)setShouldUpdateNetworkActivityIndicator:(BOOL)shouldUpdate
{
	[connectionsLock lock];
	shouldUpdateNetworkActivityIndicator = shouldUpdate;
	[connectionsLock unlock];
}

+ (void)showNetworkActivityIndicator
{
#if TARGET_OS_IPHONE
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
#endif
}

+ (void)hideNetworkActivityIndicator
{
#if TARGET_OS_IPHONE
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];	
#endif
}


#pragma mark threading behaviour

// In the default implementation, all requests run in a single background thread
// Advanced users only: Override this method in a subclass for a different threading behaviour
// Eg: return [NSThread mainThread] to run all requests in the main thread
// Alternatively, you can create a thread on demand, or manage a pool of threads
// Threads returned by this method will need to run the runloop in default mode (eg CFRunLoopRun())
// Requests will stop the runloop when they complete
// If you have multiple requests sharing the thread or you want to re-use the thread, you'll need to restart the runloop
+ (NSThread *)threadForRequest:(ASIHTTPRequest *)request
{
	if (!networkThread) {
		networkThread = [[NSThread alloc] initWithTarget:self selector:@selector(runRequests) object:nil];
		[networkThread start];
	}
	return networkThread;
}

+ (void)runRequests
{
	// Should keep the runloop from exiting
	CFRunLoopSourceContext context = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
	CFRunLoopSourceRef source = CFRunLoopSourceCreate(kCFAllocatorDefault, 0, &context);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);

	while (1) {
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		CFRunLoopRun();
		[pool release];
	}

	// Should never be called, but anyway
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
	CFRelease(source);
}

#pragma mark miscellany 

// From: http://www.cocoadev.com/index.pl?BaseSixtyFour

+ (NSString*)base64forData:(NSData*)theData {
	
	const uint8_t* input = (const uint8_t*)[theData bytes];
	NSInteger length = [theData length];
	
    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
	
    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;
	
	NSInteger i;
    for (i=0; i < length; i += 3) {
        NSInteger value = 0;
		NSInteger j;
        for (j = i; j < (i + 3); j++) {
            value <<= 8;
			
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }
		
        NSInteger theIndex = (i / 3) * 4;
        output[theIndex + 0] =                    table[(value >> 18) & 0x3F];
        output[theIndex + 1] =                    table[(value >> 12) & 0x3F];
        output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
        output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }
	
    return [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
}

// Based on hints from http://stackoverflow.com/questions/1850824/parsing-a-rfc-822-date-with-nsdateformatter
+ (NSDate *)dateFromRFC1123String:(NSString *)string
{
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
	// Does the string include a week day?
	NSString *day = @"";
	if ([string rangeOfString:@","].location != NSNotFound) {
		day = @"EEE, ";
	}
	// Does the string include seconds?
	NSString *seconds = @"";
	if ([[string componentsSeparatedByString:@":"] count] == 3) {
		seconds = @":ss";
	}
	[formatter setDateFormat:[NSString stringWithFormat:@"%@dd MMM yyyy HH:mm%@ z",day,seconds]];
	return [formatter dateFromString:string];
}

#pragma mark ===

@synthesize username;
@synthesize password;
@synthesize domain;
@synthesize proxyUsername;
@synthesize proxyPassword;
@synthesize proxyDomain;
@synthesize url;
@synthesize originalURL;
@synthesize delegate;
@synthesize queue;
@synthesize uploadProgressDelegate;
@synthesize downloadProgressDelegate;
@synthesize useKeychainPersistence;
@synthesize useSessionPersistence;
@synthesize useCookiePersistence;
@synthesize downloadDestinationPath;
@synthesize temporaryFileDownloadPath;
@synthesize didStartSelector;
@synthesize didReceiveResponseHeadersSelector;
@synthesize didFinishSelector;
@synthesize didFailSelector;
@synthesize didReceiveDataSelector;
@synthesize authenticationRealm;
@synthesize proxyAuthenticationRealm;
@synthesize error;
@synthesize complete;
@synthesize requestHeaders;
@synthesize responseHeaders;
@synthesize responseCookies;
@synthesize requestCookies;
@synthesize requestCredentials;
@synthesize responseStatusCode;
@synthesize rawResponseData;
@synthesize lastActivityTime;
@synthesize timeOutSeconds;
@synthesize requestMethod;
@synthesize postBody;
@synthesize compressedPostBody;
@synthesize contentLength;
@synthesize partialDownloadSize;
@synthesize postLength;
@synthesize shouldResetDownloadProgress;
@synthesize shouldResetUploadProgress;
@synthesize mainRequest;
@synthesize totalBytesRead;
@synthesize totalBytesSent;
@synthesize showAccurateProgress;
@synthesize uploadBufferSize;
@synthesize defaultResponseEncoding;
@synthesize responseEncoding;
@synthesize allowCompressedResponse;
@synthesize allowResumeForFileDownloads;
@synthesize userInfo;
@synthesize postBodyFilePath;
@synthesize compressedPostBodyFilePath;
@synthesize postBodyWriteStream;
@synthesize postBodyReadStream;
@synthesize shouldStreamPostDataFromDisk;
@synthesize didCreateTemporaryPostDataFile;
@synthesize useHTTPVersionOne;
@synthesize lastBytesRead;
@synthesize lastBytesSent;
@synthesize cancelledLock;
@synthesize haveBuiltPostBody;
@synthesize fileDownloadOutputStream;
@synthesize authenticationRetryCount;
@synthesize proxyAuthenticationRetryCount;
@synthesize updatedProgress;
@synthesize shouldRedirect;
@synthesize validatesSecureCertificate;
@synthesize needsRedirect;
@synthesize redirectCount;
@synthesize shouldCompressRequestBody;
@synthesize proxyCredentials;
@synthesize proxyHost;
@synthesize proxyPort;
@synthesize proxyType;
@synthesize PACurl;
@synthesize authenticationScheme;
@synthesize proxyAuthenticationScheme;
@synthesize shouldPresentAuthenticationDialog;
@synthesize shouldPresentProxyAuthenticationDialog;
@synthesize authenticationNeeded;
@synthesize responseStatusMessage;
@synthesize shouldPresentCredentialsBeforeChallenge;
@synthesize haveBuiltRequestHeaders;
@synthesize inProgress;
@synthesize numberOfTimesToRetryOnTimeout;
@synthesize retryCount;
@synthesize shouldAttemptPersistentConnection;
@synthesize persistentConnectionTimeoutSeconds;
@synthesize connectionCanBeReused;
@synthesize connectionInfo;
@synthesize readStream;
@synthesize readStreamIsScheduled;
@synthesize shouldUseRFC2616RedirectBehaviour;
@synthesize downloadComplete;
@synthesize requestID;
@synthesize runLoopMode;
@synthesize statusTimer;
@synthesize downloadCache;
@synthesize cachePolicy;
@synthesize cacheStoragePolicy;
@synthesize didUseCachedResponse;
@synthesize secondsToCache;
@synthesize clientCertificates;
@end
