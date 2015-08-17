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

    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var tapPinToDeleteLabel: UILabel!
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    private var regionDataDictionary: [String : CLLocationDegrees]!
    private var tappedPin: Pin!
    
    // Keys of the regionDataDictionary, to be saved in NSUserDefaults
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
        
        // tapPinToDeleteLabel hidden unless edit button is tapped
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
            
            // In case there's a previous region saved. Set the mapView region to the last region.
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

    // MARK:- Prepare for segue
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "photoAlbumSegue" {

            // set the photo album view controller properties
            (segue.destinationViewController as! PhotoAlbumViewController).tappedPin = tappedPin
        }
    }
    
    // MARK:- Actions
    
    @IBAction func deletePin(sender: UIBarButtonItem) {
        println(sender.valueForKey("systemItem") as! Int)
        
        var newY: CGFloat

        if sender.valueForKey("systemItem") as! Int == 2 {      // 2 is UIBarButtonSystemItem.Edit
            tapPinToDeleteLabel.hidden = false
            let doneButton = UIBarButtonItem(barButtonSystemItem: .Done, target: self, action: "deletePin:")
            self.navigationItem.rightBarButtonItem = doneButton
            sender.enabled = false
            newY = mapView.frame.origin.y - tapPinToDeleteLabel.frame.height
        } else {
            newY = mapView.frame.origin.y + tapPinToDeleteLabel.frame.height
            tapPinToDeleteLabel.hidden = true
            let editButton = UIBarButtonItem(barButtonSystemItem: .Edit, target: self, action: "deletePin:")
            self.navigationItem.rightBarButtonItem = editButton
            sender.enabled = false
        }
        
        // Animate sliding the map view up/ down
        animateMapViewSliding(newY: newY)
    }
}

// MARK:- Gesture Recognizer Delegate

extension TravelLocationsMapViewController: UIGestureRecognizerDelegate {
    
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

// MARK:- Map View Delegate

extension TravelLocationsMapViewController: MKMapViewDelegate {
    
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
                
                view.pinColor = .Purple
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
            mapView.deselectAnnotation(view.annotation, animated: false)        // Important to be reselected later
            performSegueWithIdentifier("photoAlbumSegue", sender: self)
        }
        
        if !tapPinToDeleteLabel.hidden {
            let pinToBeDeleted = searchForPinInCoreData(
                latitude: view.annotation.coordinate.latitude,
                longitude: view.annotation.coordinate.longitude
            )

            if pinToBeDeleted.isDownloadingPhotos {
                
                // Inform the user
                let alertController = UIAlertController(
                    title: nil,
                    message: "Cannot delete a pin while its photos are being downloaded",
                    preferredStyle: .Alert
                )
                let okAction = UIAlertAction(
                    title: "OK",
                    style: .Default,
                    handler: nil
                )
                alertController.addAction(okAction)
                self.presentViewController(alertController, animated: true, completion: nil)
 
                mapView.deselectAnnotation(view.annotation, animated: false)    // Important to be reselected later
                return
            }

            // Delete the pin and save context
            for object in pinToBeDeleted.photos {
                let photo = object as! Photo
                photo.image = nil
            }
            sharedContext.deleteObject(pinToBeDeleted)
            CoreDataStackManager.sharedInstance().saveContext()
            
            // Remove annotation from mapView
            mapView.removeAnnotation(view.annotation)
        }
    }
}

// MARK: - Fetched Results Controller Delegate

extension TravelLocationsMapViewController: NSFetchedResultsControllerDelegate {
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {   }
}

// MARK:- Helpers

extension TravelLocationsMapViewController {
    
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
            mapView.removeAnnotations(mapView.annotations)      // Remove existing annotations before adding the fetched pins
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
        longPressGestureRecognizer.numberOfTouchesRequired = 1      // Ensure long press
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
            Pin.Keys.Page   : 1
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
        FlickrClient.sharedInstance().getPhotosForCoordinate(latitude: annotationView.annotation.coordinate.latitude, longitude: annotationView.annotation.coordinate.longitude, page: pin.page) { photosArray, error in
            
            /* Photo objects are bing downloaded, so user cannot delete neiher pin not any of the downloaded images - until done downloading */
            pin.isDownloadingPhotos = true
            
            /* Track how many images have been downloaded. Hence set isDowloadingPhotos tappedPin property and enable newCollectionButton via posting a notification to NSNotificationCenter (to be received/ observed by PhotoAbumViewController). */
            var counter = 0
            
            if let error = error {
                
                /* Internet connection error */
                if error.code == 1 {
                    
                    /* Inform the user */
                    let alertController = UIAlertController(
                        title: error.localizedDescription,
                        message: "Check your Internet connection",
                        preferredStyle: .Alert
                    )
                    let okAction = UIAlertAction(
                        title: "OK",
                        style: .Default,
                        handler: nil
                    )
                    alertController.addAction(okAction)
                    self.presentViewController(alertController, animated: true, completion: nil)
                } else {
                    
                    /* Another error */
                    println("error code: \(error.code)")
                    println("error description: \(error.localizedDescription)")
                }
            } else {

                /* Flickr API called did return indeed if execution flow reached this point here (test with breakpoint and println). */
                pin.flickrAPICallDidReturn = true
                
                if let photosArray = photosArray as? [[String : AnyObject]] {
                    if photosArray.count == 0 {
                        dispatch_async(dispatch_get_main_queue()) {
                            
                            /* User can now delete this pin. */
                            pin.isDownloadingPhotos = false
                            
                            /* Post notification to PhotoAlbumViewController to reload photoCollectionView and show no image label. */
                            NSNotificationCenter.defaultCenter().postNotificationName("reloadData", object: self)

                            /* Even if app termiantes and is reopened, isDownloadingPhotos property is false for this pin (savedin core data). */
                            CoreDataStackManager.sharedInstance().saveContext()
                        }
                        return
                    }
                    photosArray.map { (photoDictionary: [String : AnyObject]) -> Photo in
                        var dictionary = [String : String]()
                        
                        if let imageURL = photoDictionary[FlickrClient.JSONResponseKeys.ImagePath] as? String {
                            if let imageID = photoDictionary[FlickrClient.JSONResponseKeys.ImageID] as? String {
                                dictionary[Photo.Keys.ImageID]      = imageID
                                dictionary[Photo.Keys.ImageURL]     = imageURL
                            }
                        }
                        
                        // Init the Photo object
                        let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                        
                        dispatch_async(dispatch_get_main_queue()) {
                            photo.pin = pin
                        }
                        
                        // Get that image on a background thread
                        let session = FlickrClient.sharedInstance().session
                        let url = NSURL(string: photo.imageURL)!
                        
                        let task = session.dataTaskWithURL(url) { data, response, error in
                            if let error = error {
                                
                                /* If error is related to bad Internet connection, photo object must set its error property to true. And will then be downlaoded next time PhotoAlbumViewController appears (viewWillAppear) */
                                self.handleErrors(photo: photo, error: error)
                            }
                            else {
                                let image = UIImage(data: data)
                                
                                dispatch_async(dispatch_get_main_queue()) {
                                    photo.image = image
                                    
                                    /* Post notification to PhotoAlbumViewController to reload photoCollectionView and newly downloaded image. */
                                    NSNotificationCenter.defaultCenter().postNotificationName("reloadData", object: self)
                                }
                                
                                counter++
                                
                                /* If done downloading all images */
                                if counter == photosArray.count {
                                    dispatch_async(dispatch_get_main_queue()) {
                                        
                                        /* Now user can delete pin and any of its associated images */
                                        pin.isDownloadingPhotos = false
                                        
                                        /* Save all photos' relation to this pin and save the new isDownloadingPhotos managed property for next time this pin is tapped */
                                        CoreDataStackManager.sharedInstance().saveContext()
                                    
                                        /* Inform PhotoAlbumViewController to toggle enabled property of newCollectionButton */
                                        NSNotificationCenter.defaultCenter().postNotificationName("enableOrDisableNewCollectionButton", object: self)
                                    }
                                }
                            }
                        }
                        task.resume()
                        
                        return photo
                    }
                }
            }
        }
    }
    
    func handleErrors(#photo: Photo, error: NSError) {
        
        /* Errors caused by bad Internet connection */
        if error.code == -1001 || error.code == -1005 || error.code == -1009 {
            dispatch_async(dispatch_get_main_queue()) {
                photo.error = true
                CoreDataStackManager.sharedInstance().saveContext()
            }
        }

        /* Unknown error */
        else {
            println("error code: \(error.code)")
            println("error domain: \(error.domain)")
            println("error description: \(error.localizedDescription)")
        }
    }
}