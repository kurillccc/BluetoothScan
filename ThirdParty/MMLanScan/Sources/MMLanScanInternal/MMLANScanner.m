//
//  LANScanner.m
//
//  Created by Michalis Mavris on 05/08/16.
//  Copyright © 2016 Miksoft. All rights reserved.
//

#import "MMLANScanner.h"
#import "LANProperties.h"
#import "PingOperation.h"
#import "MMDevice.h"

@interface MMLANScanner ()
@property(nonatomic, strong) NSOperationQueue *queue;
@property(nonatomic, assign, readwrite) BOOL isScanning;
@property(nonatomic, assign) NSUInteger generation;
@property(nonatomic, assign) NSUInteger completed;
@end

@implementation MMLANScanner
-(instancetype)initWithDelegate:(id<MMLANScannerDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 32;
    }
    return self;
}

-(void)start {
    [self stop];
    MMDevice *local = [LANProperties localIPAddress];
    NSArray *hosts = local ? [LANProperties getAllHostsForIP:local.ipAddress andSubnet:local.subnetMask] : nil;
    if (!hosts || hosts.count == 0) {
        [self.delegate lanScanDidFailedToScan];
        return;
    }
    self.isScanning = YES;
    self.completed = 0;
    NSUInteger generation = self.generation;
    NSUInteger total = hosts.count;
    [self.delegate lanScanDidFindNewDevice:local];
    __weak MMLANScanner *weakSelf = self;
    for (NSString *ip in hosts) {
        PingOperation *operation = [[PingOperation alloc] initWithIPToPing:ip andCompletionHandler:^(NSError *error, NSString *address) {
            dispatch_async(dispatch_get_main_queue(), ^{
                MMLANScanner *scanner = weakSelf;
                if (!scanner.isScanning || scanner.generation != generation) return;
                if (!error) {
                    MMDevice *device = [[MMDevice alloc] init];
                    device.ipAddress = address;
                    [scanner.delegate lanScanDidFindNewDevice:device];
                }
                scanner.completed++;
                if ([scanner.delegate respondsToSelector:@selector(lanScanProgressPinged:from:)])
                    [scanner.delegate lanScanProgressPinged:scanner.completed from:total];
                if (scanner.completed == total) {
                    scanner.isScanning = NO;
                    [scanner.delegate lanScanDidFinishScanningWithStatus:MMLanScannerStatusFinished];
                }
            });
        }];
        [self.queue addOperation:operation];
    }
}

-(void)stop {
    self.generation++;
    BOOL wasScanning = self.isScanning;
    self.isScanning = NO;
    [self.queue cancelAllOperations];
    if (wasScanning) [self.delegate lanScanDidFinishScanningWithStatus:MMLanScannerStatusCancelled];
}
@end
