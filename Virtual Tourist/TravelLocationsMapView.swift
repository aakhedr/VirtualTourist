//
//  MapViewController.swift
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
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    private var regionDataDictinoary: [String : CLLocationDegrees]!
    
    // Shared Context
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    // Fetched Results Controller
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Pin.Keys.Lat, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        }()
    
    // MARK:- View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set mapView delegate
        mapView.delegate = self

        // Long press gesture recognizer
        
        longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongPressGesture:")
        longPressGestureRecognizer.minimumPressDuration = 1
        longPressGestureRecognizer.numberOfTouchesRequired = 1
        longPressGestureRecognizer.delegate = self
        mapView.addGestureRecognizer(longPressGestureRecognizer)
        
        // Set the mapView region
        
        regionDataDictinoary = readValue()

        if regionDataDictinoary == nil {
            println("First time app is used")
            
            let initialRegion = MKCoordinateRegionForMapRect(MKMapRectWorld)
            mapView.setRegion(initialRegion, animated: true)
        } else {
            
            // In case there's a previous region saved.
            // Set the mapView region to the last region.
            let span = MKCoordinateSpanMake(
                regionDataDictinoary[RegionData.LatDelta]!,
                regionDataDictinoary[RegionData.LonDelta]!
            )
            let center = CLLocationCoordinate2DMake(
                regionDataDictinoary[RegionData.Lat]!,
                regionDataDictinoary[RegionData.Lon]!
            )
            let region = MKCoordinateRegion(center: center, span: span)
            mapView.setRegion(region, animated: true)
        }
        
        // Set fetchResultsController delegate
        fetchedResultsController.delegate = self
        
        // Perform the fetch
        
        var error: NSErrorPointer = nil
        fetchedResultsController.performFetch(error)
        
        if error != nil {
            println("error in performFetch: \(error)")
        }

        // Add the fetched pins to the map view
        
        mapView.removeAnnotations(mapView.annotations)
        
        if let pins = fetchedResultsController.fetchedObjects as? [Pin] {
            println("pins.count: \(pins.count)")
            
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
            
            // MARK:- Save context
            
            var dictionary = [
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
            
//            if let dequeuedView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier)
//                as? MKPinAnnotationView {
//                    println("annotation was dequeued")
//                    
//                    dequeuedView.annotation = annotation
//                    view = dequeuedView
//            } else {
                println("annotation could not be dequeued")
            
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.canShowCallout = true          // default value is already true!
                view.calloutOffset = CGPoint(x: -5, y: 5)
                view.rightCalloutAccessoryView = UIButton.buttonWithType(.DetailDisclosure) as! UIView
                
                view.pinColor = MKPinAnnotationColor.Purple
                view.animatesDrop = true
                view.draggable = true
//            }
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

        performSegueWithIdentifier("photosAlbumSegue", sender: self)
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        println("didChangeDragState called")
        
        println("newState")
        println(view.annotation.coordinate.latitude)
        println(view.annotation.coordinate.longitude)
    
        println("oldState")
        println(view.annotation.coordinate.latitude)
        println(view.annotation.coordinate.longitude)
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
    
    // MARK:- Helpers
    
    func saveValue() {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(regionDataDictinoary, forKey: RegionData.Key)
    }
    
    func readValue() -> [String : CLLocationDegrees]? {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.objectForKey(RegionData.Key) as? [String : CLLocationDegrees]
    }
}
