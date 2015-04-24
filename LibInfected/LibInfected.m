//
//  LibInfected.m
//  LibInfected
//
//  Created by Matt Schulte on 4/23/15.
//  Copyright (c) 2015 Matt Schulte. All rights reserved.
//

#import "LibInfected.h"

NSString *const PERIPHERAL_MANAGER_IDENTIFIER = @"myPeripheralManagerIdentifier";
NSString *const CENTRAL_MANAGER_IDENTIFIER    = @"myCentralMangerIdentifier";

NSString *const INFECTED_SERVICE_UUID = @"5E216DCB-0474-4A37-8935-64856A405569";
NSString *const INFECTED_CHARACTERISTIC_UUID = @"BB6537C6-0622-416C-BB54-79A3911897D0";

@interface LibInfected() <CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate>

@property NSMutableDictionary *peripherals;
@property NSMutableDictionary* rssis;
@property BOOL isRunning;

@end

@implementation LibInfected

- (id) init {
    if (self = [super init]) {
        self.peripherals = [NSMutableDictionary dictionary];
        self.rssis = [NSMutableDictionary dictionary];
        self.myPeripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil options:@{CBPeripheralManagerOptionShowPowerAlertKey:@YES, CBPeripheralManagerOptionRestoreIdentifierKey:PERIPHERAL_MANAGER_IDENTIFIER}];
        self.myCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey:@YES, CBCentralManagerOptionRestoreIdentifierKey:CENTRAL_MANAGER_IDENTIFIER}];
    }
    return self;
}

+(id) sharedLibInfected {
    static LibInfected *sharedLibInfected = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{sharedLibInfected = [[self alloc] init];});
    return sharedLibInfected;
}

-(void) start {
    
    // Advertising
    CBUUID *const infectedServiceUUID = [CBUUID UUIDWithString:INFECTED_SERVICE_UUID];
    CBUUID *const infectedCharacteristicUUID = [CBUUID UUIDWithString:INFECTED_CHARACTERISTIC_UUID];
    CBMutableCharacteristic *infectedCharacteristic = [[CBMutableCharacteristic alloc] initWithType:infectedCharacteristicUUID properties:CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsReadable];
    CBMutableService *infectedService = [[CBMutableService alloc] initWithType:infectedServiceUUID primary:YES];
    infectedService.characteristics  = @[infectedCharacteristic];
    
    [self.myPeripheralManager addService:infectedService];
    
    [self.myPeripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey: @[infectedServiceUUID]}];
    
    // Scanning
    [self.myCentralManager scanForPeripheralsWithServices:@[infectedServiceUUID] options:nil];
    
    self.isRunning = YES;
}

- (void) stop {
    // Stop scanning
    [self.myCentralManager stopScan];
    
    // Stop advertising
    [self.myPeripheralManager stopAdvertising];
    
    // Disconnect all peripherals
    for (CBPeripheral *peripheral in self.peripherals) {
        [self.myCentralManager cancelPeripheralConnection:peripheral];
    }
    
    self.isRunning = NO;
}

- (BOOL) enabled {
    return ([self.myCentralManager state] == CBCentralManagerStatePoweredOn) && ([self.myPeripheralManager state] == CBPeripheralManagerStatePoweredOn);
}

- (BOOL) running {
    return self.isRunning;
}

#pragma mark - CBPeripheralManagerDelegate
- (void) peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral {
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        [self.delegate bleOn];
    } else {
        [self.delegate bleOff];
    }
}

- (void) peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error {
    if (error) {
        NSLog(@"Error Starting Advertisement");
        self.isRunning = NO;
        return;
    }
}

- (void) peripheralManager:(CBPeripheralManager *)peripheral willRestoreState:(NSDictionary *)dict {
    NSDictionary *advData = dict[CBPeripheralManagerRestoredStateAdvertisementDataKey];
    [self.myPeripheralManager startAdvertising:advData];
    
    NSArray* services = dict[CBPeripheralManagerRestoredStateServicesKey];
    
    for (CBMutableService *service in services) {
        [self.myPeripheralManager addService:service];
    }
    self.isRunning = YES;
}

- (void) peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Error publishing service: %@", [error localizedDescription]);
        //@TODO: Handle error
    }
}

- (void) peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request {
    request = [self.delegate receivedReadRequest:request];
    [self.myPeripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
}

#pragma mark - CBCentralManagerDelegate
- (void) centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBCentralManagerStatePoweredOn) {
        [self.delegate bleOn];
    } else {
        [self.delegate bleOff];
    }
}

- (void) centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary *)dict {
    NSArray* peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey];
    NSArray *scanServices = dict[CBCentralManagerRestoredStateScanServicesKey];
    NSDictionary *scanOptions = dict[CBCentralManagerRestoredStateScanOptionsKey];
    
    for (CBPeripheral* peripheral in peripherals) {
        [self.myCentralManager connectPeripheral:peripheral options:nil];
    }
    
    [self.myCentralManager scanForPeripheralsWithServices:scanServices options:scanOptions];
}

- (void) centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Disconnected Device: %@", peripheral.identifier);
    [self.peripherals removeObjectForKey:[peripheral.identifier UUIDString]];
    [self.rssis removeObjectForKey:[peripheral.identifier UUIDString]];
}

- (void) centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Discovered Device: %@", peripheral.identifier);
    
    [self.peripherals setObject:peripheral forKey:[peripheral.identifier UUIDString]];
    [self.rssis setObject:RSSI forKey:[peripheral.identifier UUIDString]];
    [self.myCentralManager connectPeripheral:[self.peripherals objectForKey:[peripheral.identifier UUIDString]] options:nil];
}

- (void) centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect to %@: %@", peripheral.identifier, error.description);
    [self.peripherals removeObjectForKey:[peripheral.identifier UUIDString]];
    [self.rssis removeObjectForKey:[peripheral.identifier UUIDString]];
}

- (void) centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected: %@", peripheral.identifier);
    
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[[CBUUID UUIDWithString:INFECTED_SERVICE_UUID]]];
}

# pragma mark - CBPeripheralDelegate
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if (error) {
        NSLog(@"Error: Could not discover services: %@", error.description);
        [self.myCentralManager cancelPeripheralConnection:peripheral];
        [self.peripherals removeObjectForKey:[peripheral.identifier UUIDString]];
        [self.rssis removeObjectForKey:[peripheral.identifier UUIDString]];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:INFECTED_CHARACTERISTIC_UUID]] forService:service];
    }
}

-(void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    if (error) {
        NSLog(@"Error: Could not discover characteristics from service: %@", error.description);
        [self.myCentralManager cancelPeripheralConnection:peripheral];
        [self.peripherals removeObjectForKey:[peripheral.identifier UUIDString]];
        [self.rssis removeObjectForKey:[peripheral.identifier UUIDString]];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        [peripheral readValueForCharacteristic:characteristic];
    }
}

-(void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error: Could not update value for characteristic: %@", error.description);
    } else {
        [self.delegate receivedReadResponse:characteristic.value peripheralRSSI:self.rssis[[peripheral.identifier UUIDString]]];
    }
    [self.myCentralManager cancelPeripheralConnection:peripheral];
    [self.peripherals removeObjectForKey:[peripheral.identifier UUIDString]];
    [self.rssis removeObjectForKey:[peripheral.identifier UUIDString]];
}

- (void) peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    NSLog(@"Read RSSI: %@", RSSI);
}

@end
