//
//  FlickrConvenience.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/29/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import Foundation

extension FlickrClient {
    
    func getPhotosForCoordinate(latitude: Double, longitude: Double, completionHandler: (data: AnyObject?, error: NSError?) -> Void) {
        
        // 1. Set the parameters
        let parameters = [
            MethodArgumentKeys.METHOD           : Methods.SearchByLatLon,
            MethodArgumentKeys.API_KEY          : MethodArgumentValues.API_KEY,
            MethodArgumentKeys.BBOX             : FlickrClient.createBoundingBoxString(
                                                    latitude: latitude,
                                                    longitude: longitude),
            MethodArgumentKeys.EXTRAS           : MethodArgumentValues.EXTRAS,
            MethodArgumentKeys.DATA_FORMAT      : MethodArgumentValues.DATA_FORMAT,
            MethodArgumentKeys.NO_JSON_CALLBACK : MethodArgumentValues.NO_JSON_CALLBACK
        ]
        
        // 2. Make the request
        taskForGETMethod(parameters: parameters) { JSONResult, error in
            
            // 3. Send the desired result(s) to compleitionHandler
            if let error = error {
                completionHandler(
                    data: nil,
                    error: NSError(domain: "getPhotosForCoordinate", code: 1, userInfo: [NSLocalizedDescriptionKey: "network error"])
                )
            } else {
                
            }
        }
    }
}