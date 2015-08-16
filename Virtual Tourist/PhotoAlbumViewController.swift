//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/28/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {

    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var photoCollectionView: UICollectionView!
    @IBOutlet private weak var newCollectionButton: UIBarButtonItem!
    @IBOutlet weak var noImageLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var tappedPin: Pin!
    
    private var sharedContext : NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy private var fetchedResultsController : NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        /* Sort by data/time added to core data */
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "addedAt", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.tappedPin);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    // MARK:- View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /* Add the tapped pin from TravelLocationsMapViewController to mapView */
        addTappedPinToMapView()
        
        /* Set mapView region from the tapped pin lat/ lon properties */
        setMapViewRegion()
        
        /* Set photoCollectionView data srouce and delegate */
        photoCollectionView.dataSource = self
        photoCollectionView.delegate = self
        
        /* Set fetchedResultsController delegate */
        fetchedResultsController.delegate = self
        
        /* Perform the fetch */
        performFetch()
        
        /* No Image Label shows up in case a pin has no photos - Initially hidden */
        noImageLabel.hidden = true
        
        /* Activity indicator for the photoCollectionView (NOT individual cells) */
        activityIndicator.hidesWhenStopped = true
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        /* Subscribe to NSNotifications */
        
        /* PhotoAlbumViewController is set to receive notifications named "reloadData" (from TravelLocationsMapViewController) everytime the function getFlickrImagesAndSaveContext sets the image property of a Photo instance - So that photoCollectionView reloads its data, hence show the new image as soon as it's downloaded. */
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reloadData", name: "reloadData", object: nil)
        
        /* PhotoAlbumViewController set to receive notifications (from TravelLocationsMapVIewControlelr getFlickrImagesAndSaveContext) to enable or disable the newCollectionButton according to whether pin is/ is not  downloading photos. 
        If pin is downloading photos, newColelctionButton disabled - If pin is done downloading images, newCollectionButton is enabled. */
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "enableOrDisableNewCollectionButton", name: "enableOrDisableNewCollectionButton", object: nil)
        
        /* Check how many photo objects for this pin (either 0 or more) and handle current view/ subViews according to all possible use cases. */
        checkPhotosCount()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        /* Unsubscribe */
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "reloadData", object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "enableNewCollectionButton", object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        if photoCollectionView.hidden {
            return
        }
        
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        layout.minimumLineSpacing = 4
        layout.minimumInteritemSpacing = 1
        
        let width = floor((photoCollectionView.frame.size.width / 3) - 5)
        layout.itemSize = CGSize(width: width, height: width)
        
        photoCollectionView.collectionViewLayout = layout
    }
    
    // MARK: - Actions
    
    @IBAction func addNewCollection(sender: UIBarButtonItem) {
        tappedPin.page = tappedPin.page + 1
        
        /* Delete previous set of photo objects */
        deleteAllPhotos()

        /* This pin now cannot be deleted or any its associated images. Until this property is set back to false. */
        self.tappedPin.isDownloadingPhotos = true
        
        /* Toggle newCollectionButton.enabled property. */
        self.enableOrDisableNewCollectionButton()

        FlickrClient.sharedInstance().getPhotosForCoordinate(latitude: tappedPin.lat as Double, longitude: tappedPin.lon as Double, page: tappedPin.page) { photosArray, error in
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
                
                /* Download the new set of images */
                self.parsePhotosArray(photosArray!)
            }
        }
    }
}


extension PhotoAlbumViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    // MARK: - Collection View Data Source
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        let identifier = "photoCell"
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(identifier, forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        // Configure the cell
        configureCell(cell: cell, photo: photo)
        
        return cell
    }
    
    // MARK: - Collection View Delegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo

        /* Allow user to delete an image iff no other images are yet downloading */
        if !photo.pin.isDownloadingPhotos {
            let cell = photoCollectionView.cellForItemAtIndexPath(indexPath)!
            
            /* Ensure image file path is deleted in .DocumentDirectory */
            photo.image = nil
            
            sharedContext.deleteObject(photo)
            CoreDataStackManager.sharedInstance().saveContext()
            photoCollectionView.reloadData()
        }
        
        /* Inform the user */
        else {
            let alertController = UIAlertController(
                title: nil,
                message: "Cannot delete a photo while rest of the photos are being downloaded",
                preferredStyle: .Alert
            )
            let okAction = UIAlertAction(
                title: "OK",
                style: .Default,
                handler: nil
            )
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
}

// MARK: - Fetched Results Controller Delegate

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {   }
}

extension PhotoAlbumViewController {
    
    // MARK: - Helpers
    
    func addTappedPinToMapView() {
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2DMake(
            tappedPin.lat as! CLLocationDegrees,
            tappedPin.lon as! CLLocationDegrees
        )
        mapView.addAnnotation(annotation)
    }
    
    func setMapViewRegion() {
        let center = CLLocationCoordinate2DMake(
            tappedPin.lat as! CLLocationDegrees,
            tappedPin.lon as! CLLocationDegrees
        )
        let span = MKCoordinateSpanMake(1.0, 1.0)
        mapView.setRegion(MKCoordinateRegionMake(center, span), animated: false)
    }
    
    func performFetch() {
        var error: NSErrorPointer = nil
        fetchedResultsController.performFetch(error)
        if error != nil {
            println("error performing the fetch in PhotoAlbumViewController: \(error)")
            abort()
        }
    }
    
    func configureCell(#cell: PhotoCollectionViewCell, photo: Photo) {
        cell.activityIndicator.startAnimating()
        
        if photo.image == nil {
            cell.image.image = UIImage(named: "placeholder")
        } else {
            cell.image.image = photo.image
            cell.activityIndicator.stopAnimating()
        }
    }
    
    func reloadData() {
        photoCollectionView.reloadData()
        
        if tappedPin.photos.count > 0 && photoCollectionView.hidden {
            photoCollectionView.hidden = false
            noImageLabel.hidden = true
        }
    }
    
    func enableOrDisableNewCollectionButton() {
        newCollectionButton.enabled = !tappedPin.isDownloadingPhotos
    }
    
    func deleteAllPhotos() {
        
        /* Show activity indicator spinning and hide collection view */
        photoCollectionView.hidden = true
        activityIndicator.startAnimating()

        for photo in fetchedResultsController.fetchedObjects as! [Photo] {
            
            /* Must delete image in the .DocumentDirectory */
            photo.image = nil
            
            self.sharedContext.deleteObject(photo)
            CoreDataStackManager.sharedInstance().saveContext()
        }
        photoCollectionView.reloadData()
    }
    
    func parsePhotosArray(photosArray: AnyObject) {
        
        /* Use this to track how many images have been downloaded. Hence enable newCollectionButton and set isDowloadingPhotos tappedPin property */
        var counter = 0
        
        if let photosArray = photosArray as? [[String : AnyObject]] {

            /* In case photos array is empty -> No images for this location.
            pin.photos NSSet has been emptied in the previous step (deleteAllPhotos). */
            if photosArray.count == 0 {
                dispatch_async(dispatch_get_main_queue()) {
                    self.showNoImageLabel()
                }
                return
            }
            photosArray.map { (photosDictionary: [String : AnyObject]) -> Photo in
                var dictionary = [String : String]()
                
                if let imageURL = photosDictionary[FlickrClient.JSONResponseKeys.ImagePath] as? String {
                    if let imageID = photosDictionary[FlickrClient.JSONResponseKeys.ImageID] as? String {
                        dictionary[Photo.Keys.ImageID]      = imageID
                        dictionary[Photo.Keys.ImageURL]      = imageURL
                    }
                }
                
                /* Init the Photo object */
                let photo = Photo(dictionary: dictionary, context: self.sharedContext)

                dispatch_async(dispatch_get_main_queue()) {
                    photo.pin = self.tappedPin
                }
                
                /* Get that image on a background thread */
                
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
                            
                            /* Stop indicator animation and show the newly downloaded image. */
                            self.photoCollectionView.reloadData()
                            self.activityIndicator.stopAnimating()
                            self.photoCollectionView.hidden = false
                            
                            /* Increment counter variable everytime photo.image is set (i.e. image is downloaded) */
                            counter += 1
                            
                            /* If done downloading all images */
                            if counter == photosArray.count {
                                
                                /* Now user can delete pin and any of its associated images */
                                self.tappedPin.isDownloadingPhotos = false
                                
                                /* Save all photos' relation to this pin and save the new isDownloadingPhotos managed property for next time this pin is tapped */
                                CoreDataStackManager.sharedInstance().saveContext()

                                /* Enable newCollectionButton. Hence user is now able to download new set of images again. */
                                self.newCollectionButton.enabled = true
                            }
                        }
                    }
                }
                task.resume()
                
                return photo
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
    
    func showNoImageLabel() {
        photoCollectionView.hidden = true
        activityIndicator.stopAnimating()
        noImageLabel.hidden = false

        /* User cannot get new images for the locaiton. And this pin is done downloading! */
        tappedPin.isDownloadingPhotos = false
        newCollectionButton.enabled = false
    }
    
    func handlePreviousConnectionErrors() {
        
        /* Keep track of how many photos have errors */
        var photosWithErrorCounter = 0
        
        /* Keep track of total number of image downloads to compare to total number number of photos with Errors. Hence be able to toggle isDownloading Pin property and newCollectionButton enabled property */
        var counter = 0

        for object in tappedPin.photos {
            let photo = object as! Photo
            
            if photo.error == true {
                photosWithErrorCounter++
                
                /* get that image */
                let session = FlickrClient.sharedInstance().session
                let url = NSURL(string: photo.imageURL)!
                let task = session.dataTaskWithURL(url) { data, response, error in
                    if let error = error {
                        
                        /* errors due to bad Internet again? */
                        if error.code == -1001 || error.code == -1005 || error.code == -1009 {
                            
                            /* Just for reconfirmation :)
                            Could have simply left this if body blank as photo.error won't change from true to false */
                            dispatch_async(dispatch_get_main_queue()) {
                                photo.error = true
                                CoreDataStackManager.sharedInstance().saveContext()
                            }
                        } else {
                            println("error code: \(error.code)")
                            println("error description: \(error.localizedDescription)")
                        }
                    } else {
                        
                        /* Got the image?
                        Set it, toggle photo.error proprty and save the context */
                        let image = UIImage(data: data)
                        
                        dispatch_async(dispatch_get_main_queue()) {
                            photo.image = image
                            photo.error = false
                            
                            /* Reload collection view data to show the image */
                            self.photoCollectionView.reloadData()
                            
                            /* Save new value of photo.error */
                            CoreDataStackManager.sharedInstance().saveContext()
                        }
                        
                        /* Now that an image is downloaded, increment image downloads counter */
                        counter++
                        
                        /* Are we done downloading all images with errors? */
                        if counter == photosWithErrorCounter {

                            /* isDownloadingPhotos property is no longer false and user can download new set of images for the location by tapping the newCollectionButton */
                            dispatch_async(dispatch_get_main_queue()) {
                                self.tappedPin.isDownloadingPhotos = false
                                self.newCollectionButton.enabled = true
                                
                                /* save new value of tappedPin.isDownloadingPhotos */
                                CoreDataStackManager.sharedInstance().saveContext()
                            }
                        }
                    }
                }
                task.resume()
            }
        }
    }
    
    func checkPhotosCount() {
        
        /* If Flickr API call return some photos for the pin. */
        if tappedPin.photos.count != 0 {
            
            /* And is still downloading the photos */
            if tappedPin.isDownloadingPhotos {
                
                /* newCollectionButton must be disabled */
                newCollectionButton.enabled = false
            }
            
            /* Check and handle Internet connection errors from the last time in case any image could not be downloaded before for either a slow connection, lost connection, timed-out requests. */
            handlePreviousConnectionErrors()
        }
        
        /* In case of slow Internet connection, check if Flickr API call returned or not. */
        if tappedPin.photos.count == 0 {
            
            /* App is just opened? */
            if tappedPin.flickrAPICallDidReturn == nil {
                showNoImageLabel()
            }
            
            /* If Flickr API Call returned with no photos for this location. */
            if let flickrAPICallDidReturn = tappedPin.flickrAPICallDidReturn {
                if flickrAPICallDidReturn == true {
                    showNoImageLabel()
                }
            }
            
            /* If Flickr API call == false (TODO: - revisit with activity indicator!) disable the newCollectionButton and wait for the execution of the API call in TravelLocationsViewController */
            else {
                newCollectionButton.enabled = false
            }
        }
    }
}