//
//  TravelLocationsMapView.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/27/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import MapKit
import CoreData

class TravelLocationsMapView: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tabPinToDeleteLabel: UILabel!
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    var regionDataDictinoary: [String : CLLocationDegrees]!
    var tabbedPin: Pin!

    struct RegionData {
        static let Lat = "lat"
        static let Lon = "lon"
        static let LatDelta = "latDelta"
        static let LonDelta = "lonDelta"
        
        static let Key = "regionData"
    }

    // Shared Context
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    // Fetched Results Controller
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Pin.Keys.Lat, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        return fetchedResultsController
        }()
    
    // MARK:- View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // tabPinToDeleteLabel
        tabPinToDeleteLabel.hidden = true

        // Set mapView delegate
        mapView.delegate = self

        // Long press gesture recognizer
        longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongPressGesture:")
        longPressGestureRecognizer.minimumPressDuration = 1
        longPressGestureRecognizer.numberOfTouchesRequired = 1
        longPressGestureRecognizer.delegate = self
        mapView.addGestureRecognizer(longPressGestureRecognizer)
        
        // Set fetchResultsController delegate
        fetchedResultsController.delegate = self
        
        // Perform the fetch
        var error: NSErrorPointer = nil
        fetchedResultsController.performFetch(error)
        if error != nil {
            println("error in performFetch: \(error)")
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set the mapView region
        regionDataDictinoary = readValue()
        if regionDataDictinoary == nil {
            println("First time app is used")
            
            let initialRegion = MKCoordinateRegionForMapRect(MKMapRectWorld)
            mapView.setRegion(initialRegion, animated: true)
        } else {
            
            // In case there's a previous region saved.
            // Set the mapView region to the last region.
            let center = CLLocationCoordinate2DMake(
                regionDataDictinoary[RegionData.Lat]!,
                regionDataDictinoary[RegionData.Lon]!
            )
            let span = MKCoordinateSpanMake(
                regionDataDictinoary[RegionData.LatDelta]!,
                regionDataDictinoary[RegionData.LonDelta]!
            )
            let region = MKCoordinateRegionMake(center, span)
            mapView.setRegion(region, animated: true)
        }
        
        // Add the fetched pins to the map view
        mapView.removeAnnotations(mapView.annotations)
        if let pins = fetchedResultsController.fetchedObjects as? [Pin] {
            for pin in pins {
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2DMake(
                    pin.lat as! CLLocationDegrees,
                    pin.lon as! CLLocationDegrees
                )
                annotation.title = "Tap for Flickr images of this location!"
                annotation.subtitle = "Drag to change location!"
                
                mapView.addAnnotation(annotation)
            }
        }
    }
    
    // MARK:- Gesture Recognizer Delegate
    
    func handleLongPressGesture(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .Ended {
            println("handleLongPressGesture called")
            
            // Create MKPointAnnotation
            let touchPoint = recognizer.locationInView(mapView)
            let touchPointCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchPointCoordinate
            annotation.title = "Tap for Flickr images of this location!"
            annotation.subtitle = "Drag to change location!"
            
            // Add the annotation to the map view
            mapView.addAnnotation(annotation)
            
            // TODO: Get flickr images associated with the coordinate
            
            // MARK:- Save context
            let dictionary = [
                Pin.Keys.Lat   : annotation.coordinate.latitude as NSNumber,
                Pin.Keys.Lon   : annotation.coordinate.longitude as NSNumber
            ]
            let pinToBeAdded = Pin(dictionary: dictionary, context: sharedContext)
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
    
    // MARK:- Prepare for segue
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "photoAlbumSegue" {

            // set the photo album view controller properties
            (segue.destinationViewController as! PhotoAlbumViewController).tabbedPin = tabbedPin
        }
    }
    
    // MARK:- Actions
    
    @IBAction func deletePin(sender: UIBarButtonItem) {
        var newY: CGFloat

        if sender.title == "Edit" {
            tabPinToDeleteLabel.hidden = false
            sender.title = "Done"
            newY = mapView.frame.origin.y - tabPinToDeleteLabel.frame.height
        } else {
            newY = mapView.frame.origin.y + tabPinToDeleteLabel.frame.height
            tabPinToDeleteLabel.hidden = true
            sender.title = "Edit"
        }
        
        // Animate sliding up/ down
        UIView.animateWithDuration(0.2) {
            self.mapView.frame = CGRectMake(
                self.mapView.frame.origin.x,
                newY,
                self.mapView.frame.width,
                self.mapView.frame.height
            )
        }
    }
    
    // MARK:- Fetched Results Controller Delegate
    
//    func controllerWillChangeContent(controller: NSFetchedResultsController) {
//    }
//    
//    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
//
//        let pin = anObject as! Pin
//        let annotation = MKPointAnnotation()
//        annotation.coordinate = CLLocationCoordinate2DMake(
//            pin.lat as CLLocationDegrees,
//            pin.lon as CLLocationDegrees
//        )
//
//        switch type {
//
//        case NSFetchedResultsChangeType.Insert:
//            mapView.addAnnotation(annotation)
//
//        case NSFetchedResultsChangeType.Delete:
//            mapView.removeAnnotation(annotation)
//        
//        case NSFetchedResultsChangeType.Update:
//            mapView.removeAnnotation(annotation)
//            mapView.addAnnotation(annotation)
//        
//        default:
//            break
//        }
//    }
//    
//    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
//    }
//    
//    func controllerDidChangeContent(controller: NSFetchedResultsController) {
//    }
    
    // MARK:- Helpers (NSUserDefaults)
    
    func saveValue() {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(regionDataDictinoary, forKey: RegionData.Key)
    }
    
    func readValue() -> [String : CLLocationDegrees]? {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.objectForKey(RegionData.Key) as? [String : CLLocationDegrees]
    }
}
