//
//  NSArray+ArrayFromData.m
//  dreaMote
//
//  Created by Moritz Venn on 21.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import "NSArray+ArrayFromData.h"

@implementation NSArray(ArrayFromData)

+ (id)arrayWithData:(NSData *)data
{
	return [[[NSArray alloc] initWithData:data] autorelease];
}

- (id)initWithData:(NSData *)data
{
	NSPropertyListSerialization *plist = nil;
	float currentVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
	if(currentVersion >= 4.0)
	{
		plist = [NSPropertyListSerialization propertyListWithData:data
														  options:NSPropertyListImmutable
														   format:nil
															error:nil];
	}
	else
	{
		plist = [NSPropertyListSerialization propertyListFromData:data
												 mutabilityOption:NSPropertyListImmutable
														   format:nil
												 errorDescription:nil];
	}
	return [self initWithArray:(NSArray *)plist];
}

@end