//
//  Timer.h
//  Untitled
//
//  Created by Moritz Venn on 09.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Service.h"
#import "Event.h"

@interface Timer : NSObject
{
@private
	NSString *_eit;
	NSDate *_begin;
	NSDate *_end;
	BOOL _disabled;
	NSString *_title;
	NSString *_tdescription;
	int _repeated;
	BOOL _justplay;
	Service *_service;
	NSString *_sref;
	int _state;
}

+ (Timer *)withEvent: (Event *)ourEvent;
+ (Timer *)withEventAndService: (Event *)ourEvent: (Service *)ourService;
+ (Timer *)new;

- (NSString *)getStateString;
- (void)setBeginFromString: (NSString *)newBegin;
- (void)setEndFromString: (NSString *)newEnd;
- (void)setDisabledFromString: (NSString *)newDisabled;
- (void)setJustplayFromString: (NSString *)newJustplay;
- (void)setRepeatedFromString: (NSString *)newRepeated;
- (void)setServiceFromSname: (NSString *)newSname;
- (void)setStateFromString: (NSString *)newState;

@property (nonatomic, retain) NSString *eit;
@property (nonatomic, retain) NSDate *begin;
@property (nonatomic, retain) NSDate *end;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *tdescription;
@property (assign) BOOL disabled;
@property (assign) int repeated;
@property (assign) BOOL justplay;
@property (nonatomic, retain) Service *service;
@property (nonatomic, retain) NSString *sref;
@property (assign) int state;

@end
