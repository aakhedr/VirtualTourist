//
//  TravelLocationsMapViewController.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/27/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tabPinToDeleteLabel: UILabel!
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    private var regionDataDictionay: [String : CLLocationDegrees]!
    private var tabbedPin: Pin!

    private struct regionDataDictionayKeys {
        static let Lat = "latitude"
        static let Lon = "longitude"
        static let LatDelta = "latitudeDelta"
        static let LonDelta = "longitudeDelta"
        
        static let NSUserDefaultsKey = "regionData"
    }

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
        configureLongPressGestureRecognizer()
        
        // Set the mapView region
        regionDataDictionay = readValue()
        if regionDataDictionay == nil {
            
            // First time app is used show worldmap
            let initialRegion = MKCoordinateRegionForMapRect(MKMapRectWorld)
            mapView.setRegion(initialRegion, animated: true)

        } else {
            
            // In case there's a previous region saved.
            // Set the mapView region to the last region.
            let region = setRegionCenterAndSpan()
            mapView.setRegion(region, animated: true)
        }
        
        // Set Fetched Results Controller delegate
        fetchedResultsController.delegate = self
        
        // Perform the fetch
        performFetch()
        
        // Fetch and show pins in the map view
        fetchAndShowPinAnnotations()
    }
    
    // MARK:- Gesture Recognizer Delegate
    
    func handleLongPressGesture(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .Ended {
            
            // Create MKPointAnnotation
            let touchPoint = recognizer.locationInView(mapView)
            let touchPointCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
            let annotation = MKPointAnnotationMake(coordinate: touchPointCoordinate)
            
            // TODO: Get flickr images associated with the coordinate
            
            // MARK:- Save context
            saveContext(annotation: annotation)
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
        
        // Animate sliding the map view up/ down
        animateMapViewSliding(newY: newY)
    }
    
    // MARK:- Map View Delegate
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if let annotation = annotation as? MKPointAnnotation {
            let identifier = "pin"
            var view: MKPinAnnotationView
            
            if let dequeuedView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier)
                as? MKPinAnnotationView {
                    dequeuedView.annotation = annotation
                    view = dequeuedView
            } else {
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
        
        // Save region data dictionary to NSUserDefaults
        regionDataDictionay = [
            regionDataDictionayKeys.Lat        : mapView.region.center.latitude,
            regionDataDictionayKeys.Lon        : mapView.region.center.longitude,
            regionDataDictionayKeys.LatDelta   : mapView.region.span.latitudeDelta,
            regionDataDictionayKeys.LonDelta   : mapView.region.span.longitudeDelta
        ]
        saveValue()
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        
        // Set the tabbedPin associated with the MKAnnotationView
        tabbedPin = searchForPinInCoreData(
            latitude: view.annotation.coordinate.latitude,
            longitude: view.annotation.coordinate.longitude
        )
        performSegueWithIdentifier("photoAlbumSegue", sender: self)
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        switch oldState {
            
            // Old coordinate
            case .Starting:
                let pinToBeDeleted = searchForPinInCoreData(
                    latitude: view.annotation.coordinate.latitude,
                    longitude: view.annotation.coordinate.longitude
                )
                
                // Delete old object
                sharedContext.deleteObject(pinToBeDeleted)
                
            // New coordinate
            case .Ending:
                
                // MARK: Save context after update
                saveContext(annotation: view.annotation)
                
                // TODO: Get new set of flickr images
                
                
            default:
                break
        }
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        if !tabPinToDeleteLabel.hidden {
            
            // Delete the pin from core data
            let pinToBeDeleted = searchForPinInCoreData(
                latitude: view.annotation.coordinate.latitude,
                longitude: view.annotation.coordinate.longitude
            )
            sharedContext.deleteObject(pinToBeDeleted)
            
            // MARK:- Save context after deletion
            CoreDataStackManager.sharedInstance().saveContext()
            
            // Remove annotation from mapView
            mapView.removeAnnotation(view.annotation)
        }
    }
    
    // MARK: - Fetched Results Controller Delegate
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
    }
    
    // MARK:- Helpers
    
    func saveValue() {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(regionDataDictionay, forKey: regionDataDictionayKeys.NSUserDefaultsKey)
    }
    
    func readValue() -> [String : CLLocationDegrees]? {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.objectForKey(regionDataDictionayKeys.NSUserDefaultsKey) as? [String : CLLocationDegrees]
    }
    
    func setRegionCenterAndSpan() -> MKCoordinateRegion {
        let center = CLLocationCoordinate2DMake(
            regionDataDictionay[regionDataDictionayKeys.Lat]!,
            regionDataDictionay[regionDataDictionayKeys.Lon]!
        )
        let span = MKCoordinateSpanMake(
            regionDataDictionay[regionDataDictionayKeys.LatDelta]!,
            regionDataDictionay[regionDataDictionayKeys.LonDelta]!
        )
        return MKCoordinateRegionMake(center, span)
    }
    
    func fetchAndShowPinAnnotations() {
        if let pins = fetchedResultsController.fetchedObjects as? [Pin] {
            mapView.removeAnnotations(mapView.annotations)
            for pin in pins {
                MKPointAnnotationMake(coordinate:
                    CLLocationCoordinate2DMake(
                        pin.lat as! CLLocationDegrees,
                        pin.lon as! CLLocationDegrees
                    )
                )
            }
        }
    }
    
    func configureLongPressGestureRecognizer() {
        longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongPressGesture:")
        longPressGestureRecognizer.minimumPressDuration = 1
        longPressGestureRecognizer.numberOfTouchesRequired = 1
        longPressGestureRecognizer.delegate = self
        mapView.addGestureRecognizer(longPressGestureRecognizer)
    }

    func performFetch() {
        var error: NSErrorPointer = nil
        fetchedResultsController.performFetch(error)
        if error != nil {
            println("error in performFetch: \(error)")
            abort()
        }
    }
    
    func animateMapViewSliding(#newY: CGFloat) {
        UIView.animateWithDuration(0.2) {
            self.mapView.frame = CGRectMake(
                self.mapView.frame.origin.x,
                newY,
                self.mapView.frame.width,
                self.mapView.frame.height
            )
        }
    }

    func MKPointAnnotationMake(#coordinate: CLLocationCoordinate2D) -> MKPointAnnotation {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Tap for Flickr images of this location!"
        annotation.subtitle = "Drag to change location!"
        mapView.addAnnotation(annotation)
        
        return annotation
    }
    
    func saveContext(#annotation: MKAnnotation) {
        let dictionary = [
            Pin.Keys.Lat   : annotation.coordinate.latitude as NSNumber,
            Pin.Keys.Lon   : annotation.coordinate.longitude as NSNumber
        ]
        let pinToBeAdded = Pin(dictionary: dictionary, context: sharedContext)
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    func searchForPinInCoreData(#latitude: CLLocationDegrees, longitude: CLLocationDegrees) -> Pin {
        let pins = fetchedResultsController.fetchedObjects as! [Pin]
        let lat = latitude as NSNumber
        let lon = longitude as NSNumber
        
        return pins.filter { pin in
            pin.lat == lat && pin.lon == lon
            }.first!
    }
}
