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
        static let Page = "page"
        static let Photos = "photos"
    }
    
    @NSManaged var lat                  : NSNumber
    @NSManaged var lon                  : NSNumber
    @NSManaged var page                 : Int
    @NSManaged var isDownloadingPhotos  : Bool
    
    @NSManaged var photos               : NSSet
    
    var flickrAPICallDidReturn          : Bool = false
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)

        lat = dictionary[Pin.Keys.Lat] as! NSNumber
        lon = dictionary[Pin.Keys.Lon] as! NSNumber
        page = dictionary[Pin.Keys.Page] as! Int
        
        isDownloadingPhotos = true
    }
}
