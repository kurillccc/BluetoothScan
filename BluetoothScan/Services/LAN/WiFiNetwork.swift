//
//  WiFiNetwork.swift
//  BluetoothScan
//
//  Created by Кирилл Чернов on 10.11.2026.
//

import Foundation
import Darwin

struct WiFiNetwork: Equatable {
    let address: String
    let subnetMask: String

    var supportsScanning: Bool {
        var mask = in_addr()
        guard inet_pton(AF_INET, subnetMask, &mask) == 1 else { return false }
        let wildcard = ~UInt32(bigEndian: mask.s_addr)
        return wildcard >= 3 && wildcard <= 4095 && (wildcard & (wildcard &+ 1)) == 0
    }

    static func current() -> WiFiNetwork? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { return nil }
        defer { freeifaddrs(interfaces) }
        var current = interfaces
        while let entry = current {
            defer { current = entry.pointee.ifa_next }
            let interface = entry.pointee
            guard String(cString: interface.ifa_name) == "en0",
                  interface.ifa_flags & UInt32(IFF_UP | IFF_RUNNING) == UInt32(IFF_UP | IFF_RUNNING),
                  let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_INET),
                  let mask = interface.ifa_netmask,
                  let ip = string(from: address), let subnet = string(from: mask) else { continue }
            return WiFiNetwork(address: ip, subnetMask: subnet)
        }
        return nil
    }

    private static func string(from address: UnsafeMutablePointer<sockaddr>) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(address, socklen_t(address.pointee.sa_len), &buffer,
                          socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
        return String(cString: buffer)
    }
}
