//
//  ImageCache.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 8/1/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import UIKit

class ImageCache {
    
    private var inMemoryCache = NSCache()
    
    // MARK: - Retreiving images
    
    func imageWithIdentifier(identifier: String) -> UIImage? {
        
        let path = pathForIdentifier(identifier)
        var data: NSData?
        
        // First try the memory cache
        if let image = inMemoryCache.objectForKey(path) as? UIImage {
            return image
        }
        
        // Next Try the hard drive
        if let data = NSData(contentsOfFile: path) {
            return UIImage(data: data)
        }
        return nil
    }
    
    // MARK: - Saving images
    
    func storeImage(image: UIImage?, withIdentifier identifier: String) {
        let path = pathForIdentifier(identifier)
        
        // If the image is nil, remove images from the cache
        if image == nil {
            
            inMemoryCache.removeObjectForKey(path)
            NSFileManager.defaultManager().removeItemAtPath(path, error: nil)
            return
        }
        
        // Otherwise, keep the image in memory
        inMemoryCache.setObject(image!, forKey: path)
        
        // And in documents directory
        let data = UIImagePNGRepresentation(image!)

        var error: NSError?
        if !data.writeToFile(path, options: .DataWritingAtomic, error: &error) {
            println("error writing file: \(error)")
        }
    }
    
    // MARK: - Helper
    
    func pathForIdentifier(identifier: String) -> String {
        let fileManager = NSFileManager.defaultManager()
        let documentDirectoryURL: NSURL = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        let fullURL = documentDirectoryURL.URLByAppendingPathComponent(identifier)
        
        return fullURL.path!
    }
    
    // MARK: - Shared Cache
    
    class func sharedCache() -> ImageCache {
        
        struct Singleton {
            static var sharedCache = ImageCache()
        }
        
        return Singleton.sharedCache
    }
}