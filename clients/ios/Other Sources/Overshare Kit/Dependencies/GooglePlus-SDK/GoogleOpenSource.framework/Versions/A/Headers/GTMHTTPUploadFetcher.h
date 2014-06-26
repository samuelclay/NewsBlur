/* Copyright (c) 2010 Google Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

//
//  GTMHTTPUploadFetcher.h
//

#if (!GDATA_REQUIRE_SERVICE_INCLUDES) || GDATA_INCLUDE_DOCS_SERVICE || \
  GDATA_INCLUDE_YOUTUBE_SERVICE || GDATA_INCLUDE_PHOTOS_SERVICE

//
// This subclass of GTMHTTPFetcher simulates the series of fetches
// needed for chunked upload as a single fetch operation.
//
// Protocol document:
//   http://code.google.com/p/gears/wiki/ResumableHttpRequestsProposal
//
// To the client, the only fetcher that exists is this class; the subsidiary
// fetchers needed for uploading chunks are not visible (though the most recent
// chunk fetcher may be accessed via the -activeFetcher method, and
// -responseHeaders and -statusCode reflect results from the most recent chunk
// fetcher.)
//
// Chunk fetchers are discarded as soon as they have completed.
//

#pragma once

#import "GTMHTTPFetcher.h"
#import "GTMHTTPFetcherService.h"

// async retrieval of an http get or post
@interface GTMHTTPUploadFetcher : GTMHTTPFetcher {
  GTMHTTPFetcher *chunkFetcher_;

  // we'll call through to the delegate's sentData and finished selectors
  SEL delegateSentDataSEL_;
  SEL delegateFinishedSEL_;

  BOOL needsManualProgress_;

  // the initial fetch's body length and bytes actually sent are
  // needed for calculating progress during subsequent chunk uploads
  NSUInteger initialBodyLength_;
  NSUInteger initialBodySent_;

  NSURL *locationURL_;
#if NS_BLOCKS_AVAILABLE
  void (^locationChangeBlock_)(NSURL *);
#elif !__LP64__
  // placeholders: for 32-bit builds, keep the size of the object's ivar section
  // the same with and without blocks
#ifndef __clang_analyzer__
  id locationChangePlaceholder_;
#endif
#endif
  
  // uploadData_ or uploadFileHandle_ may be set, but not both
  NSData *uploadData_;
  NSFileHandle *uploadFileHandle_;
  NSInteger uploadFileHandleLength_;
  NSString *uploadMIMEType_;
  NSUInteger chunkSize_;
  BOOL isPaused_;
  BOOL isRestartedUpload_;

  // we keep the latest offset into the upload data just for
  // progress reporting
  NSUInteger currentOffset_;

  // we store the response headers and status code for the most recent
  // chunk fetcher
  NSDictionary *responseHeaders_;
  NSInteger statusCode_;
}

+ (GTMHTTPUploadFetcher *)uploadFetcherWithRequest:(NSURLRequest *)request
                                        uploadData:(NSData *)data
                                    uploadMIMEType:(NSString *)uploadMIMEType
                                         chunkSize:(NSUInteger)chunkSize
                                    fetcherService:(GTMHTTPFetcherService *)fetcherServiceOrNil;

+ (GTMHTTPUploadFetcher *)uploadFetcherWithRequest:(NSURLRequest *)request
                                  uploadFileHandle:(NSFileHandle *)fileHandle
                                    uploadMIMEType:(NSString *)uploadMIMEType
                                         chunkSize:(NSUInteger)chunkSize
                                    fetcherService:(GTMHTTPFetcherService *)fetcherServiceOrNil;

+ (GTMHTTPUploadFetcher *)uploadFetcherWithLocation:(NSURL *)locationURL
                                   uploadFileHandle:(NSFileHandle *)fileHandle
                                     uploadMIMEType:(NSString *)uploadMIMEType
                                          chunkSize:(NSUInteger)chunkSize
                                     fetcherService:(GTMHTTPFetcherService *)fetcherServiceOrNil;
- (void)pauseFetching;
- (void)resumeFetching;
- (BOOL)isPaused;

@property (retain) NSURL *locationURL;
@property (retain) NSData *uploadData;
@property (retain) NSFileHandle *uploadFileHandle;
@property (copy) NSString *uploadMIMEType;
@property (assign) NSUInteger chunkSize;
@property (assign) NSUInteger currentOffset;

#if NS_BLOCKS_AVAILABLE
// When the upload location changes, the optional locationChangeBlock will be
// called. It will be called with nil once upload succeeds or can no longer
// be attempted.
@property (copy) void (^locationChangeBlock)(NSURL *locationURL);
#endif

// the fetcher for the current data chunk, if any
@property (retain) GTMHTTPFetcher *chunkFetcher;

// the active fetcher is the last chunk fetcher, or the upload fetcher itself
// if no chunk fetcher has yet been created
@property (readonly) GTMHTTPFetcher *activeFetcher;

// the response headers from the most recently-completed fetch
@property (retain) NSDictionary *responseHeaders;

// the status code from the most recently-completed fetch
@property (assign) NSInteger statusCode;

@end

#endif // #if !GDATA_REQUIRE_SERVICE_INCLUDES
