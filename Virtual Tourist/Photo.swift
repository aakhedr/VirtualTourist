//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/28/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import CoreData

@objc(Photo)

class Photo: NSManagedObject {
    
    struct Keys {
        static let ImageURL = "imageURL"
    }
    
    @NSManaged private var imageURL: String!
    @NSManaged var imageData: NSData!
    @NSManaged private var pin: Pin
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        imageURL = dictionary[Photo.Keys.ImageURL] as! String
        
        // Set imageData property
        let url = NSURL(string: imageURL)!
        let imageData = NSData(contentsOfURL: url)!
        
        self.imageData = imageData
    }
}