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
    var regionDataDictionay: [String : CLLocationDegrees]!
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
        configureLongPressGestureRecognizer()
        
        // Set fetchResultsController delegate
        fetchedResultsController.delegate = self
        
        // Perform the fetch
        performFetch()
        
        // Fetch and show pins in the map view
        fetchAndShowPinAnnotations()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set the mapView region
        regionDataDictionay = readValue()
        if regionDataDictionay == nil {
            
            // First time app is used show worldmap
            let initialRegion = MKCoordinateRegionForMapRect(MKMapRectWorld)
            mapView.setRegion(initialRegion, animated: true)
        } else {
            
            // In case there's a previous region saved.
            // Set the mapView region to the last region.
            let region = setRegionData()
            mapView.setRegion(region, animated: true)
        }
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
    
    // MARK:- Helpers
    
    func saveValue() {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(regionDataDictionay, forKey: RegionData.Key)
    }
    
    func readValue() -> [String : CLLocationDegrees]? {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.objectForKey(RegionData.Key) as? [String : CLLocationDegrees]
    }
    
    func setRegionData() -> MKCoordinateRegion {
        let center = CLLocationCoordinate2DMake(
            regionDataDictionay[RegionData.Lat]!,
            regionDataDictionay[RegionData.Lon]!
        )
        let span = MKCoordinateSpanMake(
            regionDataDictionay[RegionData.LatDelta]!,
            regionDataDictionay[RegionData.LonDelta]!
        )
        return MKCoordinateRegionMake(center, span)
    }
    
    func fetchAndShowPinAnnotations() {
        mapView.removeAnnotations(mapView.annotations)
        if let pins = fetchedResultsController.fetchedObjects as? [Pin] {
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
