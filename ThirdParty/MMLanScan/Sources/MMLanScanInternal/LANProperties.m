//
//  LANProperties.m
//
//  Created by Michalis Mavris on 05/08/16.
//  Copyright © 2016 Miksoft. All rights reserved.
//

#import <SystemConfiguration/CaptiveNetwork.h>
#import "NetworkCalculator.h"
#import "LANProperties.h"
#import "MMDevice.h"
#import <ifaddrs.h>
#import <arpa/inet.h>
#include <netdb.h>

@implementation LANProperties

#pragma mark - Public methods
+(MMDevice*)localIPAddress {
    
    MMDevice *localDevice = [[MMDevice alloc]init];
    
    localDevice.ipAddress = @"error";
    
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    
    if (success == 0) {
        
        temp_addr = interfaces;
        
        while(temp_addr != NULL) {
            
            // check if interface is en0 which is the wifi connection on the iPhone
            if(temp_addr->ifa_addr && temp_addr->ifa_netmask && temp_addr->ifa_addr->sa_family == AF_INET) {
                
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    
                    localDevice.ipAddress = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                    localDevice.subnetMask = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_netmask)->sin_addr)];
                    localDevice.hostname = nil;
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    
    //In case we failed to fetch IP address
    if ([localDevice.ipAddress isEqualToString:@"error"]) {
        return nil;
    }
    
    //Mark the device as the local IP
    localDevice.isLocalDevice = YES;

    return localDevice;
}

+(NSString*)fetchSSIDInfo {
    
    NSArray *ifs = (__bridge_transfer NSArray *)CNCopySupportedInterfaces();

    NSDictionary *info;
    
    for (NSString *ifnam in ifs) {
        
        info = (__bridge_transfer NSDictionary *)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        
        if (info && [info count]) {
    
            return [info objectForKey:@"SSID"];
            break;
        }
    }
    
    return @"No WiFi Available";
}
//Getting all the hosts to ping and returns them as array
+(NSArray*)getAllHostsForIP:(NSString*)ipAddress andSubnet:(NSString*)subnetMask {
    
    return [NetworkCalculator getAllHostsForIP:ipAddress andSubnet:subnetMask];
}

//Not working
#pragma mark - Get Host from IP
 +(NSString *)getHostFromIPAddress:(NSString *)ipAddress {
    struct sockaddr_in address = {0};
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    if (inet_pton(AF_INET, ipAddress.UTF8String, &address.sin_addr) != 1) return nil;
    char hostname[NI_MAXHOST];
    int result = getnameinfo((struct sockaddr *)&address, sizeof(address), hostname, sizeof(hostname), NULL, 0, NI_NAMEREQD);
    return result == 0 ? [NSString stringWithUTF8String:hostname] : nil;
}
@end
