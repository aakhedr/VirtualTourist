//
//  Pin.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/28/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import MapKit
import CoreData

@objc(Pin)

class Pin: NSManagedObject {
    
    @NSManaged private var lat: NSNumber!
    @NSManaged private var lon: NSNumber!
    @NSManaged private var photos: [Photo]!
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        lat = dictionary["lat"] as! NSNumber
        lon = dictionary["lon"] as! NSNumber
    }
}
