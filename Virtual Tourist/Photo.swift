//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/28/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import CoreData
import UIKit

@objc(Photo)

class Photo: NSManagedObject {
    
    struct Keys {
        static let ImageURL = "imageURL"
    }
    
    @NSManaged var imageURL: String
    @NSManaged private var pin: Pin
    
    var image: UIImage? {
        get {
            return ImageCache.sharedCache().imageWithIdentifier(imageURL)
        }
        
        set {
            ImageCache.sharedCache().storeImage(newValue, withIdentifier: imageURL)
        }
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        imageURL = dictionary[Photo.Keys.ImageURL] as! String
    }
}