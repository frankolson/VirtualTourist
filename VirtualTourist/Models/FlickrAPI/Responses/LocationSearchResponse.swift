//
//  LocationSearchResponse.swift
//  VirtualTourist
//
//  Created by Will Olson on 8/16/21.
//

import Foundation

struct LocationSearchResponse: Codable {
    let status: String
    let results: FlickerPhotoResponse
    
    enum CodingKeys: String, CodingKey {
        case status = "stat"
        case results = "photos"
    }
}

struct FlickerPhotoResponse: Codable {
    let page: Int
    let pages: Int
    let perPage: Int
    let total: Int
    let photos: [FlickrPhoto]
    
    enum CodingKeys: String, CodingKey {
        case page
        case pages
        case perPage = "perpage"
        case total
        case photos = "photo"
    }
}
