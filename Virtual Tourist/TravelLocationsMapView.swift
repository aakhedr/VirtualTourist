//
//  TravelLocationsMapView.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/27/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import MapKit
import CoreData

private struct RegionData {
    static let Lat = "lat"
    static let Lon = "lon"
    static let LatDelta = "latDelta"
    static let LonDelta = "lonDelta"
    
    static let Key = "regionData"
}

class TravelLocationsMapView: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tabPinToDeleteLabel: UILabel!
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    private var regionDataDictinoary: [String : CLLocationDegrees]!
    private var tabbedPin: Pin!
    
    // Shared Context
    private var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    // Fetched Results Controller
    lazy private var fetchedResultsController: NSFetchedResultsController = {
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
    
    // MARK:- Map View Delegate
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if let annotation = annotation as? MKPointAnnotation {
            println("annotation is MKPointAnnoration")
            
            let identifier = "pin"
            var view: MKPinAnnotationView
            
            if let dequeuedView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier)
                as? MKPinAnnotationView {
                    println("annotation was dequeued")
                    
                    dequeuedView.annotation = annotation
                    view = dequeuedView
            } else {
                println("annotation could not be dequeued")
            
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true          // default value is already true!
                view.calloutOffset = CGPoint(x: -5, y: 5)
                view.rightCalloutAccessoryView = UIButton.buttonWithType(.DetailDisclosure) as! UIView
                
                view.pinColor = MKPinAnnotationColor.Purple
                view.animatesDrop = true
                view.draggable = true
            }
            return view
        }
        return nil
    }
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        println("regionDidChangeAnimated called")
        
        // Save region data dictionary to NSUserDefaults
        regionDataDictinoary = [
            RegionData.Lat        : mapView.region.center.latitude,
            RegionData.Lon        : mapView.region.center.longitude,
            RegionData.LatDelta   : mapView.region.span.latitudeDelta,
            RegionData.LonDelta   : mapView.region.span.longitudeDelta
        ]
        saveValue()
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        println("calloutAccessoryControlTapped called")
        
        // Set the tabbedPin associated with the MKAnnotationView
        let pins = fetchedResultsController.fetchedObjects as! [Pin]
        let lat = view.annotation.coordinate.latitude as NSNumber
        let lon = view.annotation.coordinate.longitude as NSNumber
        tabbedPin = pins.filter { pin in
            pin.lat == lat && pin.lon == lon
        }.first
        performSegueWithIdentifier("photoAlbumSegue", sender: self)
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        println("didChangeDragState called")
        
        switch oldState {
            
        // Old coordinate
        case .Starting:
            let pins = fetchedResultsController.fetchedObjects as! [Pin]
            
            let lat = view.annotation.coordinate.latitude as NSNumber
            let lon = view.annotation.coordinate.longitude as NSNumber
            let pinToBeDeleted = pins.filter { pin in
                pin.lat == lat && pin.lon == lon
            }.first!
            println("old coordinate: \(pinToBeDeleted.lat) \(pinToBeDeleted.lon)")
            
            // Delete old object
            sharedContext.deleteObject(pinToBeDeleted)

        // New coordinate
        case .Ending:
            
            // TODO: Get new set of flickr images

            
            // MARK: Save context after update
            let dictionary = [
                Pin.Keys.Lat   : view.annotation.coordinate.latitude as NSNumber,
                Pin.Keys.Lon   : view.annotation.coordinate.longitude as NSNumber
            ]
            let pinToBeAdded = Pin(dictionary: dictionary, context: sharedContext)
            CoreDataStackManager.sharedInstance().saveContext()
            
        default:
            break
        }
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        if !tabPinToDeleteLabel.hidden {
            
            // Delete the pin from core data
            let pins = fetchedResultsController.fetchedObjects as! [Pin]
            let lat = view.annotation.coordinate.latitude as NSNumber
            let lon = view.annotation.coordinate.longitude as NSNumber
            let pinToBeDeleted = pins.filter { pin in
                pin.lat == lat && pin.lon == lon
                }.first!
            sharedContext.deleteObject(pinToBeDeleted)
            
            // MARK:- Save context after deletion
            CoreDataStackManager.sharedInstance().saveContext()

            // Remove annotation from mapView
            mapView.removeAnnotation(view.annotation)
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
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
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
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
    }
    
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
