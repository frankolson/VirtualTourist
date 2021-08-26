//
//  FlickrPhoto.swift
//  VirtualTourist
//
//  Created by Will Olson on 8/16/21.
//

import Foundation

struct FlickrPhoto: Codable {
    let id: String
    let serverId: String
    let secret: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case serverId = "server"
        case secret
    }
}
