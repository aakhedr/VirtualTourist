//
//  Pin.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/28/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import CoreData

@objc(Pin)

class Pin: NSManagedObject {
    
    struct Keys {
        static let Lat = "latitude"
        static let Lon = "longitude"
    }
    
    @NSManaged var lat: NSNumber
    @NSManaged var lon: NSNumber
    @NSManaged var photos: [Photo]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        lat = dictionary[Pin.Keys.Lat] as! NSNumber
        lon = dictionary[Pin.Keys.Lon] as! NSNumber
        
        // TODO: Get photos from Flickr
    }
}
