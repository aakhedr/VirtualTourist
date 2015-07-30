//
//  FlickrConstants.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/29/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import Foundation

extension FlickrClient {
    
    struct BaseURL {
        static let URL = "https://api.flickr.com/services/rest/"
    }
    
    struct Methods {
        static let SearchByLatLon = "flickr.photos.search"
    }
    
    struct MethodArgumentKeys {
        static let METHOD           = "method"
        static let API_KEY          = "api_key"
        static let BBOX             = "bbox"
        static let SAFE_SEARCH      = "safe_search"
        static let EXTRAS           = "extras"
        static let DATA_FORMAT      = "format"
        static let NO_JSON_CALLBACK = "nojsoncallback"
    }
    
    struct MethodArgumentValues {
        static let API_KEY          = "8043ac58d9221bbab7136f4b7399aebb"
        static let SAFE_SEARCH      = "1"
        static let EXTRAS           = "url_m"
        static let DATA_FORMAT      = "json"
        static let NO_JSON_CALLBACK = "1"
    }
    
    struct BoundingBox {
        static let BOUNDING_BOX_HALF_WIDTH = 1.0
        static let BOUNDING_BOX_HALF_HEIGHT = 1.0
        static let LAT_MIN = -90.0
        static let LAT_MAX = 90.0
        static let LON_MIN = -180.0
        static let LON_MAX = 180.0
    }
    
    struct JSONResponseKeys {
        static let StatusMessage    = "message"      // TODO: Test!
    }
    
}
