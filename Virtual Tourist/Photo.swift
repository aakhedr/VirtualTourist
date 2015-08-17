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
        static let ImageID  = "imageID"
    }
    
    @NSManaged var imageURL : String
    @NSManaged var imageID  : String
    @NSManaged var addedAt  : NSDate
    @NSManaged var error    : Bool
    
    @NSManaged var pin: Pin

    var selected            : Bool!
    var image: UIImage? {
        get {
            return ImageCache.sharedCache().imageWithIdentifier(imageID)
        }
        
        set {
            ImageCache.sharedCache().storeImage(newValue, withIdentifier: imageID)
        }
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        imageURL = dictionary[Photo.Keys.ImageURL] as! String
        imageID = dictionary[Photo.Keys.ImageID] as! String
        addedAt = NSDate()
    }
}