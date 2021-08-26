//
//  FlickrAPIClient.swift
//  VirtualTourist
//
//  Created by Will Olson on 8/15/21.
//

import Foundation

class FlickrAPIClient {
    
    enum Endpoints {
        private static let apiKey = Bundle.main.infoDictionary?["FLICKR_API_KEY"] ?? ""
        private static let photoBase = "https://live.staticflickr.com"
        private static let searchBase = "https://www.flickr.com/services/rest"
        
        case downloadPhotoImage(serverId: String, id: String, secret: String)
        case getPhotosFromLocation(latitude: Double, longitude: Double)
        
        var stringValue: String {
            switch self {
            case .downloadPhotoImage(let serverId, let id, let secret):
                return Endpoints.photoBase + "/\(serverId)/\(id)_\(secret)_q.jpg"
            case .getPhotosFromLocation(let latitude, let longitude):
                return
                    Endpoints.searchBase +
                    "/?method=flickr.photos.search" +
                    "&api_key=\(Endpoints.apiKey)" +
                    "&format=json&nojsoncallback=1" +
                    "&bbox=\(FlickrAPIClient.getBoundingBox(latitude: latitude, longitude: longitude))" +
                    "&lat=\(latitude)&lon=\(longitude)" +
                    "&page=\(Int.random(in: 1...10))&per_page=15"
            }
        }
        
        var url: URL {
            return URL(string: stringValue)!
        }
        
    }
    
    class func downloadPosterImage(serverId: String, id: String, secret: String, completion: @escaping (Data?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: Endpoints.downloadPhotoImage(serverId: serverId, id: id, secret: secret).url) { data, response, error in
            DispatchQueue.main.async {
                completion(data, nil)
            }
        }
        task.resume()
    }
    
    class func getPhotosFromLocation(latitude: Double, longitude: Double, completion: @escaping (LocationSearchResponse?, Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: Endpoints.getPhotosFromLocation(latitude: latitude, longitude: longitude).url) { data, response, error in
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            let decoder = JSONDecoder()
            do {
                let responseObject = try decoder.decode(LocationSearchResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(responseObject, nil)
                }
            } catch {
                do {
                    let errorResponse = try decoder.decode(FlickrResponse.self, from: data)
                    DispatchQueue.main.async {
                        completion(nil, errorResponse)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }
        }
        task.resume()
    }
    
    private class func getBoundingBox(latitude: Double, longitude: Double) -> String {
        let boxSize = 0.1 // 10 kilometers
        let minLatitude = String(latitude - boxSize)
        let maxLatitude = String(latitude + boxSize)
        let minLongitude = String(longitude - boxSize)
        let maxLongitude = String(longitude + boxSize)
        
        return "\(minLongitude)%2C\(minLatitude)%2C\(maxLongitude)%2C\(maxLatitude)"
    }
}
