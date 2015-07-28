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
        static let Lat = "lat"
        static let Lon = "lon"
    }
    
    @NSManaged private var lat: NSNumber!
    @NSManaged private var lon: NSNumber!
    
    @NSManaged private var photos: [Photo]!
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        lat = dictionary[Pin.Keys.Lat] as! Double
        lon = dictionary[Pin.Keys.Lon] as! Double
    }
}
