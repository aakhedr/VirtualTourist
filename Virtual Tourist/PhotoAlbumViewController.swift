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
    
    var tappedPin: Pin!
    
    private var sharedContext : NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy private var fetchedResultsController : NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
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
        
        // Add the tappedPin to the mapView
        addTappedPinToMapView()
        
        // Set mapView region
        setMapViewRegion()
        
        // Set photoCollectionView data srouce and delegate
        photoCollectionView.dataSource = self
        photoCollectionView.delegate = self
        
        // Set fetchedResultsController delegate 
        fetchedResultsController.delegate = self
        
        // Perform the fetch
        performFetch()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reloadData", name: "reloadData", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "enableOrDisableNewCollectionButton", name: "enableOrDisableNewCollectionButton", object: nil)
        
        if tappedPin.photos.count != 0 {
            if tappedPin.isDownloadingPhotos {
                newCollectionButton.enabled = false
            }
        }
        
        if tappedPin.photos.count == 0 {
            if !tappedPin.isDownloadingPhotos {
                showNoImageLabel()
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
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
        
        // Delete previous set of photo objects
        deleteAllPhotos()
        
        tappedPin.isDownloadingPhotos = true
        enableOrDisableNewCollectionButton()

        FlickrClient.sharedInstance().getPhotosForCoordinate(latitude: tappedPin.lat as Double, longitude: tappedPin.lon as Double, page: tappedPin.page) { photosArray, error in
            if let error = error {
                println("error code: \(error.code)")
                println("error description: \(error.localizedDescription)")
            } else {
                
                // Download the new set of images
                self.parsePhotosArray(photosArray!)
            }
        }
    }
}


extension PhotoAlbumViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    // MARK: - Collection View Data Source
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        
        println("sectionInfo.numberOfObjects: \(sectionInfo.numberOfObjects)")
        
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

        if !photo.pin.isDownloadingPhotos {
            let cell = photoCollectionView.cellForItemAtIndexPath(indexPath)!
            cell.contentView.backgroundColor = UIColor.redColor()
            
            // Ensure image file path is deleted in .DocumentDirectory
            photo.image = nil
            
            sharedContext.deleteObject(photo)
            CoreDataStackManager.sharedInstance().saveContext()
            photoCollectionView.reloadData()
        } else {
            
            // Add alert controller
            let alertController = UIAlertController(title: nil, message: "Cannot delete a photo while rest of the photos are being downloaded", preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alertController.addAction(okAction)
            self.presentViewController(alertController, animated: true, completion: nil)
            
            println("rest of pin images are still being downloaded")
        }
    }
}

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    // MARK: - Fetched Results Controller Delegate
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        println("controllerWillChangeContent called")
        println("fetchedResultsController.fetchedObjects!.count \(fetchedResultsController.fetchedObjects!.count)")
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        println("controllerDidChangeContent called")
        println("fetchedResultsController.fetchedObjects!.count \(fetchedResultsController.fetchedObjects!.count)")
    }
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
        mapView.region = MKCoordinateRegionMake(center, span)
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
        
        // Important in case of didSelectItemAtIndexPath is called
        cell.contentView.backgroundColor = UIColor.whiteColor()
    }
    
    func reloadData() {
        photoCollectionView.reloadData()
    }
    
    func enableOrDisableNewCollectionButton() {
        newCollectionButton.enabled = !tappedPin.isDownloadingPhotos
        
        println("Toggled newCollectionButton.enabled property: \(newCollectionButton.enabled)")
    }
    
    func deleteAllPhotos() {
        for photo in fetchedResultsController.fetchedObjects as! [Photo] {
            photo.image = nil
            self.sharedContext.deleteObject(photo)
        }
        photoCollectionView.reloadData()
    }
    
    func parsePhotosArray(photosArray: AnyObject) {
        
        println("isDownoading new set of images")
        
        var counter = 0
        if let photosArray = photosArray as? [[String : AnyObject]] {

            // No Images label
            if photosArray.count == 0 {
                dispatch_async(dispatch_get_main_queue()) {
                    self.showNoImageLabel()
                    self.tappedPin.photos = NSSet()
                    CoreDataStackManager.sharedInstance().saveContext()
                }
                return
            }
            photosArray.map { (photosDictionary: [String : AnyObject]) -> Photo in
                var dictionary = [String : String]()
                
                if let imageURL = photosDictionary[FlickrClient.JSONResponseKeys.ImagePath] as? String {
                    if let imageID = photosDictionary[FlickrClient.JSONResponseKeys.ImageID] as? String {
                        dictionary[Photo.Keys.ImageID]      = imageID
                        dictionary[Photo.Keys.ImageURL]      = imageURL
                    } else {
                        println("no imageID as String")
                    }
                } else {
                    println("no ImageURL as String")
                }
                
                // Init the Photo object
                let photo = Photo(dictionary: dictionary, context: self.sharedContext)

                dispatch_async(dispatch_get_main_queue()) {
                    photo.pin = self.tappedPin
                }
                
                // Get that image on a background thread
                let session = FlickrClient.sharedInstance().session
                let url = NSURL(string: photo.imageURL)!
                let task = session.dataTaskWithURL(url) { data, response, error in
                    
                    println("started dataTaskWithURL PhotoAlbum")
                    
                    if let error = error {
                        
                        // TODO: - Handle errors
                        self.handleErrors(error)
                    } else {
                        let image = UIImage(data: data)
                        
                        dispatch_async(dispatch_get_main_queue()) {
                            photo.image = image
                            NSNotificationCenter.defaultCenter().postNotificationName("reloadData", object: self)
                            
                            counter += 1
                            if counter == photosArray.count {
                                photo.pin = self.tappedPin
                                CoreDataStackManager.sharedInstance().saveContext()
                                
                                println("********* Done downloading images PhotoAlbum")
                                
                                self.tappedPin.isDownloadingPhotos = false
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
    
    func handleErrors(error: NSError) {
        if error.code == -1001 || error.code == -1005 || error.code == -1009 {
            println("error code: \(error.code)")
            println("error domain: \(error.domain)")
            println("error description: \(error.localizedDescription)")
        } else {
            println("error code: \(error.code)")
            println("error domain: \(error.domain)")
            println("error description: \(error.localizedDescription)")
        }
    }
    
    func showNoImageLabel() {
        photoCollectionView.hidden = true
        
        var label = UILabel(frame: CGRectMake(0, 0, 200, 21))
        label.center = self.view.center
        label.textAlignment = .Center
        label.text = "No Images"
        label.hidden = false
        self.view.addSubview(label)
        
        tappedPin.isDownloadingPhotos = false
        newCollectionButton.enabled = false
    }
}