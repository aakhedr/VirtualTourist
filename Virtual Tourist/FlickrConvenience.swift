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
            MethodArgumentKeys.BBOX             : createBoundingBoxString(
                                                    latitude: latitude,
                                                    longitude: longitude),
            MethodArgumentKeys.EXTRAS           : MethodArgumentValues.EXTRAS,
            MethodArgumentKeys.DATA_FORMAT      : MethodArgumentValues.DATA_FORMAT,
            MethodArgumentKeys.NO_JSON_CALLBACK : MethodArgumentValues.NO_JSON_CALLBACK,
            MethodArgumentKeys.PER_PAGE         : MethodArgumentValues.PER_PAGE
        ]
        
        // 2. Make the request
        taskForGETMethod(parameters: parameters) { JSONResult, error in
            
            // 3. Send the desired result(s) to compleitionHandler
            if let error = error {
                completionHandler(
                    data: nil,
                    error: NSError(
                        domain: "getPhotosForCoordinate",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "network error"]))
            } else {
                if let successMessage = JSONResult.valueForKey(JSONResponseKeys.SuccessMessage) as? String {
                    if successMessage == "ok" {
                        if let photosDictinoary = JSONResult.valueForKey(JSONResponseKeys.PhotosDictionary) as? [String : AnyObject] {
                            if let photosArray = photosDictinoary[JSONResponseKeys.PhotosArray] as? [[String : AnyObject]] {
                                if photosArray.count == 0 {
                                    println("No photos for this location")      // TODO: No photos for this location
                                }
                                var imagePaths = [String]()
                                
                                for dictionary in photosArray {
                                    if let imagePath = dictionary[JSONResponseKeys.ImagePath] as? String {
                                        imagePaths.append(imagePath)
                                    } else {
                                        completionHandler(data: nil, error: NSError(domain: "getPhotosForCoordinate", code: 6, userInfo: [NSLocalizedDescriptionKey : "Could not find imagePath"]))
                                    }
                                }
                                completionHandler(
                                    data: imagePaths,
                                    error: nil)
                            } else {
                                completionHandler(
                                    data: nil, error: NSError(
                                        domain: "getPhotosForCoordinate",
                                        code: 5,
                                        userInfo: [NSLocalizedDescriptionKey : "Could not find photos array"]))
                            }
                        } else {
                            completionHandler(
                                data: nil,
                                error: NSError(
                                    domain: "getPhotosForCoordinate",
                                    code: 4,
                                    userInfo: [NSLocalizedDescriptionKey : "Could not find phoots dictionary"]))
                        }
                    } else {
                        completionHandler(
                            data: nil,
                            error: NSError(
                                domain: "getPhotosForCoordinate",
                                code: 3,
                                userInfo: [NSLocalizedDescriptionKey : "success message is not ok!"]))
                        println("successMessage: \(successMessage)")
                    }
                } else {
                    completionHandler(
                        data: nil,
                        error: NSError(domain: "getPhotosForCoordinate",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey : "Could not find ok success message"]))
                }
            }
        }
    }
}



