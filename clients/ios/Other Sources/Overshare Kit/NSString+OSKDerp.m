//
//  NSString+Derp.m
//  DerpKit
//
//  Created by Steve Streza on 7/15/12.
//  Copyright (c) 2012 Steve Streza
//  
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
//  DEALINGS IN THE SOFTWARE.
//

#import "NSString+OSKDerp.h"
#import "NSData+OSKDerp.h"
#import <CommonCrypto/CommonHMAC.h>

@implementation NSString (OSKDerp)

-(NSString *)osk_derp_stringByEscapingPercents{
    NSString *result = (__bridge NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
																					(CFStringRef)self,
																					NULL,
																					CFSTR("!*'();:@&=+$,/?%#[]"),
																					kCFStringEncodingUTF8);
	return result;
}

-(NSString *)osk_derp_stringByUnscapingPercents{
    NSString *result = (__bridge NSString *)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
																									(CFStringRef)self,
																									CFSTR(""),
																									kCFStringEncodingUTF8);
	return result;
}

-(NSString *)osk_derp_HMAC_SHA1SignatureWithKey:(NSString *)signingKey{
	const char *keyBytes = [signingKey cStringUsingEncoding:NSUTF8StringEncoding];
    const char *baseStringBytes = [self cStringUsingEncoding:NSUTF8StringEncoding];
    unsigned char digestBytes[CC_SHA1_DIGEST_LENGTH];
    
	CCHmacContext ctx;
    CCHmacInit(&ctx, kCCHmacAlgSHA1, keyBytes, strlen(keyBytes));
	CCHmacUpdate(&ctx, baseStringBytes, strlen(baseStringBytes));
	CCHmacFinal(&ctx, digestBytes);
    
	NSData *digestData = [NSData dataWithBytes:digestBytes length:CC_SHA1_DIGEST_LENGTH];
	NSString *signatureString = [digestData osk_derp_stringByBase64EncodingData];
	return signatureString;
}

+(NSString *)osk_derp_randomStringWithLength:(NSUInteger)length{
	static NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	
	NSMutableString *randomString = [NSMutableString stringWithCapacity: length];
	
	for (int i=0; i<length; i++) {
		[randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
	}
	
	return [randomString copy];
}

-(NSString *)osk_derp_stringByBase64EncodingString{
	return [[self osk_derp_UTF8Data] osk_derp_stringByBase64EncodingData];
}

-(NSString *)osk_derp_stringByBase64DecodingString{
	return [[self osk_derp_dataByBase64DecodingString] osk_derp_UTF8String];
}

static const char encodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

-(NSData *)osk_derp_dataByBase64DecodingString{
	if ([self length] == 0)
		return [NSData data];
	
	static char *decodingTable = NULL;
	if (decodingTable == NULL)
	{
		decodingTable = malloc(256);
		if (decodingTable == NULL)
			return nil;
		memset(decodingTable, CHAR_MAX, 256);
		NSUInteger i;
		for (i = 0; i < 64; i++)
			decodingTable[(short)encodingTable[i]] = i;
	}
	
	const char *characters = [self cStringUsingEncoding:NSASCIIStringEncoding];
	if (characters == NULL)     //  Not an ASCII string!
		return nil;
	char *bytes = malloc((([self length] + 3) / 4) * 3);
	if (bytes == NULL)
		return nil;
	NSUInteger length = 0;
	
	NSUInteger i = 0;
	while (YES)
	{
		char buffer[4];
		short bufferLength;
		for (bufferLength = 0; bufferLength < 4; i++)
		{
			if (characters[i] == '\0')
				break;
			if (isspace(characters[i]) || characters[i] == '=')
				continue;
			buffer[bufferLength] = decodingTable[(short)characters[i]];
			if (buffer[bufferLength++] == CHAR_MAX)      //  Illegal character!
			{
				free(bytes);
				return nil;
			}
		}
		
		if (bufferLength == 0)
			break;
		if (bufferLength == 1)      //  At least two characters are needed to produce one byte!
		{
			free(bytes);
			return nil;
		}
		
		//  Decode the characters in the buffer to bytes.
		bytes[length++] = (buffer[0] << 2) | (buffer[1] >> 4);
		if (bufferLength > 2)
			bytes[length++] = (buffer[1] << 4) | (buffer[2] >> 2);
		if (bufferLength > 3)
			bytes[length++] = (buffer[2] << 6) | buffer[3];
	}
	
	realloc(bytes, length);
	return [NSData dataWithBytesNoCopy:bytes length:length];
}

-(NSData *)osk_derp_UTF8Data{
	return [self dataUsingEncoding:NSUTF8StringEncoding];
}

@end