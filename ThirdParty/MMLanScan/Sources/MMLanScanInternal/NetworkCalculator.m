//
//  NetworkCalculator.m
//  MMLanScanDemo
//
//  Created by Michalis Mavris on 12/08/16.
//  Copyright © 2016 Miksoft. All rights reserved.
//

#import "NetworkCalculator.h"
#import <arpa/inet.h>

@implementation NetworkCalculator
+(NSArray *)getAllHostsForIP:(NSString *)ipAddress andSubnet:(NSString *)subnetMask {
    struct in_addr ip, mask;
    if (inet_pton(AF_INET, ipAddress.UTF8String, &ip) != 1 ||
        inet_pton(AF_INET, subnetMask.UTF8String, &mask) != 1) return nil;
    uint32_t address = ntohl(ip.s_addr), netmask = ntohl(mask.s_addr);
    uint32_t wildcard = ~netmask;
    if (wildcard < 3 || wildcard > 4095 || (wildcard & (wildcard + 1)) != 0) return nil;
    uint32_t first = (address & netmask) + 1;
    uint32_t last = (address | wildcard) - 1;
    NSMutableArray *hosts = [NSMutableArray array];
    for (uint32_t current = first; current <= last; current++) {
        if (current == address) continue;
        struct in_addr host = { .s_addr = htonl(current) };
        char text[INET_ADDRSTRLEN];
        if (inet_ntop(AF_INET, &host, text, sizeof(text)))
            [hosts addObject:[NSString stringWithUTF8String:text]];
    }
    return hosts;
}
@end
