//
//  FlickrConstants.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/29/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import Foundation

extension FlickrClient {
    
    struct Parameters {
        static let BaseURL = "https://api.flickr.com/services/rest/"
        static let API_KEY = "8043ac58d9221bbab7136f4b7399aebb"
    }
    
    struct Methods {
        static let SearchByLatLon = "flickr.photos.search"
    }
    
    
}
