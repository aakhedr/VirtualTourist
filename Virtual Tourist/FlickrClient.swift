//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/29/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import Foundation

class FlickrClient: NSObject {
    
    var session: NSURLSession
    
    override init() {
        session = NSURLSession.sharedSession()
        
        super.init()
    }
    
    func taskForGETMethod(apiKey: String, method: String, latitude: Double, longitude: Double, completionHandler: (result: AnyObject?, error: NSError?) -> Void) -> NSURLSessionDataTask {
        
        // 1. Set the parameters
        let methodArguments = [
            MethodArgumentKeys.METHOD           : Methods.SearchByLatLon,
            MethodArgumentKeys.API_KEY          : MethodArgumentValues.API_KEY,
            MethodArgumentKeys.BBOX             : FlickrClient.createBoundingBoxString(
                                                    latitude: latitude,
                                                    longitude: longitude),
            MethodArgumentKeys.EXTRAS           : MethodArgumentValues.EXTRAS,
            MethodArgumentKeys.DATA_FORMAT      : MethodArgumentValues.DATA_FORMAT,
            MethodArgumentKeys.NO_JSON_CALLBACK : MethodArgumentValues.NO_JSON_CALLBACK
        ]
        
        // 2/3. Build the URL and intialize the request
        let urlString = BaseURL.URL + FlickrClient.escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)

        // 4. Make the request
        let task = session.dataTaskWithRequest(request) { data, response, error in
            if let error = error {
                
                // 5/6. Parse the data and use the data
                let newError = FlickrClient.errorForData(data, response: response, error: error)
                completionHandler(result: nil, error: newError)
            } else {
                FlickrClient.parseJSONWithCompletionHandler(data, completionHandler: completionHandler)
            }
        }
        
        // 7. Start the request
        task.resume()
        
        return task
    }

    // MARK: - Helpers
    
    class func escapedParameters(parameters: [String : AnyObject]) -> String {
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLPathAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
        }
        return (!urlVars.isEmpty ? "?" : "") + join("&", urlVars)
    }
    
    class func errorForData(data: NSData?, response: NSURLResponse?, error: NSError) -> NSError {
        if let parsedResult = NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments, error: nil) as? [String : AnyObject] {
            
            if let errorMessage = parsedResult[FlickrClient.JSONResponseKeys.StatusMessage] as? String {
                let userInfo = [NSLocalizedDescriptionKey : errorMessage]
                
                return NSError(domain: "Flickr Error", code: 0, userInfo: userInfo)
            }
        }
        return error
    }
    
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: (result: AnyObject!, error: NSError?) -> Void) {
        var parsingError: NSError? = nil
        
        let parsedResult: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError)
        
        if let error = parsingError {
            completionHandler(result: nil, error: error)
        } else {
            completionHandler(result: parsedResult, error: nil)
        }
    }
    
    class func createBoundingBoxString(#latitude: Double, longitude: Double) -> String {
        let bottom_left_lon = max(
            longitude - BoundingBox.BOUNDING_BOX_HALF_WIDTH,
            BoundingBox.LON_MIN
        )
        let bottom_left_lat = max(
            latitude - BoundingBox.BOUNDING_BOX_HALF_HEIGHT,
            BoundingBox.LAT_MIN
        )
        let top_right_lon = min(
            longitude + BoundingBox.BOUNDING_BOX_HALF_HEIGHT,
            BoundingBox.LON_MAX
        )
        let top_right_lat = min(
            latitude + BoundingBox.BOUNDING_BOX_HALF_HEIGHT,
            BoundingBox.LAT_MAX
        )
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
    
    // MARK: - Shared instance

    class func sharedInstance() -> FlickrClient {
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        return Singleton.sharedInstance
    }
}