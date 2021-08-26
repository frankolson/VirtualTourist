//
//  FlickrResponse.swift
//  VirtualTourist
//
//  Created by Will Olson on 8/16/21.
//

import Foundation

struct FlickrResponse: Codable {
    let status: String
    let code: Int
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case status = "stat"
        case code
        case message
    }
}

extension FlickrResponse: LocalizedError {
    var errorDescription: String? {
        return "(\(status)) \(message)"
    }
    
}
