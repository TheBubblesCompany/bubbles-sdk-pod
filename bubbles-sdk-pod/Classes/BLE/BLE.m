
/*
 
 BLE framework source code is placed under the MIT license
 
 Copyright (c) 2013 RedBearLab
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "BLE.h"

@implementation BLE

@synthesize delegate;
@synthesize CM;
@synthesize peripherals;
@synthesize activePeripheral;





- (void) controlSetup
{
    self.CM = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}


- (const char *) centralManagerStateToString: (int)state
{
    switch(state)
    {
        case CBCentralManagerStateUnknown:
            return "State unknown (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateResetting:
            return "State resetting (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateUnsupported:
            return "State BLE unsupported (CBCentralManagerStateResetting)";
        case CBCentralManagerStateUnauthorized:
            return "State unauthorized (CBCentralManagerStateUnauthorized)";
        case CBCentralManagerStatePoweredOff:
            return "State BLE powered off (CBCentralManagerStatePoweredOff)";
        case CBCentralManagerStatePoweredOn:
            return "State powered up and ready (CBCentralManagerStatePoweredOn)";
        default:
            return "State unknown";
    }
    
    return "Unknown state";
}



- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
#if TARGET_OS_IPHONE
    NSLog(@"Status of CoreBluetooth central manager changed %ld (%s)", (long)central.state, [self centralManagerStateToString:central.state]);
    
    
    
    
    NSString *stateString = nil;
    switch(CM.state)
    {
        case CBCentralManagerStateResetting:
            
            _bluetoothEnable = NO;
            stateString = @"The connection with the system service was momentarily lost, update imminent.";
            [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"bubbleStats"];
            [[NSUserDefaults standardUserDefaults] synchronize]; break;
            
        case CBCentralManagerStateUnsupported:
            
            _bluetoothEnable = NO; stateString = @"The platform doesn't support Bluetooth Low Energy."; [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"bubbleStats"];
            [[NSUserDefaults standardUserDefaults] synchronize]; break;
            
        case CBCentralManagerStateUnauthorized:
            _bluetoothEnable = NO; stateString = @"The app is not authorized to use Bluetooth Low Energy."; [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"bubbleStats"];
            [[NSUserDefaults standardUserDefaults] synchronize]; break;
            
        case CBCentralManagerStatePoweredOff:
            [[NSNotificationCenter defaultCenter]postNotificationName:@"BluetoothOFF" object:nil];
            _bluetoothEnable = NO; stateString = @"Bluetooth is currently powered off."; [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"bubbleStats"];
            [[NSUserDefaults standardUserDefaults] synchronize]; break;
            
            
        case CBCentralManagerStatePoweredOn:
            [[NSNotificationCenter defaultCenter]postNotificationName:@"BluetoothON" object:nil];
            _bluetoothEnable = YES; stateString = @"Bluetooth is currently powered on and available to use."; break;
            
        default: _bluetoothEnable = NO; stateString = @"State unknown, update imminent."; [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO] forKey:@"bubbleStats"];
            [[NSUserDefaults standardUserDefaults] synchronize]; break;
    }
    
#else
    [self isLECapableHardware];
#endif
}


@end
