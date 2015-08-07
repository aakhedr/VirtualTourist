//
//  TravelLocationsMapViewController.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/27/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tapPinToDeleteLabel: UILabel!
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    private var regionDataDictionary: [String : CLLocationDegrees]!
    private var tappedPin: Pin!
    private var task: NSURLSessionDataTask!

    private struct regionDataDictionaryKeys {
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
        
        // tapPinToDeleteLabel
        tapPinToDeleteLabel.hidden = true

        // Set mapView delegate
        mapView.delegate = self

        // Long press gesture recognizer
        configureLongPressGestureRecognizer()
        
        // Set the mapView region
        regionDataDictionary = readValue()
        if regionDataDictionary == nil {
            
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
        // And set pinIsDraggable
        fetchAndShowPinAnnotations()
    }
    
    // MARK:- Prepare for segue
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "photoAlbumSegue" {

            // set the photo album view controller properties
            (segue.destinationViewController as! PhotoAlbumViewController).tappedPin = tappedPin

            // Cancel current task 
            // as another will start in the next controller
            if let task = task {
                task.cancel()
            }
        }
    }
    
    // MARK:- Actions
    
    @IBAction func deletePin(sender: UIBarButtonItem) {
        var newY: CGFloat

        if sender.title == "Edit" {
            tapPinToDeleteLabel.hidden = false
            sender.title = "Done"
            newY = mapView.frame.origin.y - tapPinToDeleteLabel.frame.height
        } else {
            newY = mapView.frame.origin.y + tapPinToDeleteLabel.frame.height
            tapPinToDeleteLabel.hidden = true
            sender.title = "Edit"
        }
        
        // Animate sliding the map view up/ down
        animateMapViewSliding(newY: newY)
    }
}

extension TravelLocationsMapViewController: UIGestureRecognizerDelegate {
    
    // MARK:- Gesture Recognizer Delegate
    
    func handleLongPressGesture(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .Ended {
            
            // Create MKPointAnnotation and add it to the map view
            let touchPoint = recognizer.locationInView(mapView)
            let touchPointCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
            let annotation = MKPointAnnotationMake(coordinate: touchPointCoordinate)
            let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            
            // Init Pin and save context
            let pin = self.pinFromAnnotation(annotation: annotation)
            CoreDataStackManager.sharedInstance().saveContext()
            
            // Start getting the photos
            getFlickrImagesAndSaveContext(pin: pin, annotationView: annotationView)
        }
    }
}

extension TravelLocationsMapViewController: MKMapViewDelegate {
    
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
                
                view.pinColor = MKPinAnnotationColor.Purple
                view.animatesDrop = true
                view.canShowCallout = false             // default is true!
                view.draggable = true                   // default is false
            }
            return view
        }
        return nil
    }
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        
        // Save region data dictionary to NSUserDefaults
        regionDataDictionary = [
            regionDataDictionaryKeys.Lat        : mapView.region.center.latitude,
            regionDataDictionaryKeys.Lon        : mapView.region.center.longitude,
            regionDataDictionaryKeys.LatDelta   : mapView.region.span.latitudeDelta,
            regionDataDictionaryKeys.LonDelta   : mapView.region.span.longitudeDelta
        ]
        saveValue()
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        switch oldState {
        
        // Old coordinate
        case .Starting:
            
            println("changDragState starting")
            
            let pinToBeDeleted = searchForPinInCoreData(
                latitude: view.annotation.coordinate.latitude,
                longitude: view.annotation.coordinate.longitude)
            
            // Delete old object
            sharedContext.deleteObject(pinToBeDeleted)
            CoreDataStackManager.sharedInstance().saveContext()

            println(pinToBeDeleted.photos.count)
            
        // New coordinate
        case .Ending:

            println("changDragState ending")
            
            // Init new pin and save context
            let pinToBeAdded = pinFromAnnotation(annotation: view.annotation)
            CoreDataStackManager.sharedInstance().saveContext()

            // Get Flickr images and Save context
            getFlickrImagesAndSaveContext(pin: pinToBeAdded, annotationView: view!)
            
        default:
            break
        }
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        if tapPinToDeleteLabel.hidden {
            
            // Set the tappedPin associated with the MKAnnotationView
            tappedPin = searchForPinInCoreData(
                latitude: view.annotation.coordinate.latitude,
                longitude: view.annotation.coordinate.longitude
            )
            mapView.deselectAnnotation(view.annotation, animated: false)
            performSegueWithIdentifier("photoAlbumSegue", sender: self)
        }
        
        if !tapPinToDeleteLabel.hidden {
            
            // Delete the pin from core data
            let pinToBeDeleted = searchForPinInCoreData(
                latitude: view.annotation.coordinate.latitude,
                longitude: view.annotation.coordinate.longitude
            )
            sharedContext.deleteObject(pinToBeDeleted)
            
            // Save context after deletion
            CoreDataStackManager.sharedInstance().saveContext()
            
            // Remove annotation from mapView
            mapView.removeAnnotation(view.annotation)
        }
    }
}

extension TravelLocationsMapViewController: NSFetchedResultsControllerDelegate {
    
    // MARK: - Fetched Results Controller Delegate
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {   }
}

extension TravelLocationsMapViewController {
    
    // MARK:- Helpers
    
    func saveValue() {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(regionDataDictionary, forKey: regionDataDictionaryKeys.NSUserDefaultsKey)
    }
    
    func readValue() -> [String : CLLocationDegrees]? {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.objectForKey(regionDataDictionaryKeys.NSUserDefaultsKey) as? [String : CLLocationDegrees]
    }
    
    func setRegionCenterAndSpan() -> MKCoordinateRegion {
        let center = CLLocationCoordinate2DMake(
            regionDataDictionary[regionDataDictionaryKeys.Lat]!,
            regionDataDictionary[regionDataDictionaryKeys.Lon]!
        )
        let span = MKCoordinateSpanMake(
            regionDataDictionary[regionDataDictionaryKeys.LatDelta]!,
            regionDataDictionary[regionDataDictionaryKeys.LonDelta]!
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
        mapView.addAnnotation(annotation)
        
        return annotation
    }
    
    func pinFromAnnotation(#annotation: MKAnnotation) -> Pin {
        let dictionary = [
            Pin.Keys.Lat    : annotation.coordinate.latitude as NSNumber,
            Pin.Keys.Lon    : annotation.coordinate.longitude as NSNumber,
        ]
        return Pin(dictionary: dictionary, context: sharedContext)
    }
    
    func searchForPinInCoreData(#latitude: CLLocationDegrees, longitude: CLLocationDegrees) -> Pin {
        let pins = fetchedResultsController.fetchedObjects as! [Pin]
        let lat = latitude as NSNumber
        let lon = longitude as NSNumber
        
        return pins.filter { pin in
            pin.lat == lat && pin.lon == lon
            }.first!
    }
    
    func getFlickrImagesAndSaveContext(#pin: Pin, annotationView: MKAnnotationView) {
        FlickrClient.sharedInstance().getPhotosForCoordinate(latitude: annotationView.annotation.coordinate.latitude, longitude: annotationView.annotation.coordinate.longitude) { imageURLs, error in
            
            if let error = error {
                if error.code == -1001 || error.code == -1005 || error.code == -1009 {
                    
                    // TODO: - Internet connection problem
                    
                    
                } else {
                    println("error code: \(error.code)")
                    println("error domain: \(error.domain)")
                    println("error description: \(error.localizedDescription)")
                }
            } else {
                
                println("photos = \(imageURLs!.count)")
                
                if let imageURLs = imageURLs as? [String] {
                    imageURLs.map { (imageURL: String) -> Photo in
                        let dictionary = [ Photo.Keys.ImageURL    : imageURL ]
                        
                        // Init the Photo object
                        let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                        photo.pin = pin
                        
                        // Get that image on a background thread
                        let session = FlickrClient.sharedInstance().session
                        let url = NSURL(string: photo.imageURL)!
                        
                        self.task = session.dataTaskWithURL(url) { data, response, error in
                            if let error = error {
                                
                                // Task is cancelled
                                if error.code == -999 {
                                    return
                                } else if error.code == -1001 || error.code == -1005 || error.code == -1009 {
                                    
                                    // TODO: - Internet connection problem
                                    
                                } else {
                                    println("************* TravelLocationsMapViewController")
                                    println("error code: \(error.code)")
                                    println("error domain: \(error.domain)")
                                    println("error description: \(error.localizedDescription)")
                                }
                            } else {
                                photo.image = UIImage(data: data)
                            }
                        }
                        self.task.resume()
                        
                        return photo
                    }
                }
            }
        }
    }
}