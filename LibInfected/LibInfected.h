//
//  LibInfected.h
//  LibInfected
//
//  Created by Matt Schulte on 4/23/15.
//  Copyright (c) 2015 Matt Schulte. All rights reserved.
//

@import CoreBluetooth;
#import <Foundation/Foundation.h>

extern NSString *const PERIPHERAL_MANAGER_IDENTIFIER;
extern NSString *const CENTRAL_MANAGER_IDENTIFIER;

@protocol LibInfectedDelgate

-(void)bleOff;
-(void)bleOn;
-(CBATTRequest*)receivedReadRequest:(CBATTRequest*) request;
-(void) receivedReadResponse:(NSData*) data;

@end

@interface LibInfected : NSObject

+(id) sharedLibInfected;

-(void) start;
-(void) stop;

-(BOOL) enabled;
-(BOOL) running;

@property (strong, nonatomic) CBPeripheralManager *myPeripheralManager;
@property (strong, nonatomic) CBCentralManager *myCentralManager;

@property (nonatomic, assign) id  delegate;

@end
