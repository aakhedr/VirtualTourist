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
    
    var tappedPin: Pin!
    
    private var sharedContext : NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy private var fetchedResultsController : NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        // TODO: Change key as you add new properties to Photo
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imageURL", ascending: true)]
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
        addTabbedPinToMapView()
        
        // Set mapView region
        setMapViewRegion()
        
        // Set photoCollectionView delegate and data srouce
        photoCollectionView.delegate = self
        photoCollectionView.dataSource = self
        
        // Set fetchedResultsController delegate 
        fetchedResultsController.delegate = self
        
        // Perform the fetch
        performFetch()
    }
}

extension PhotoAlbumViewController: UICollectionViewDataSource {
    
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
        configureCell(cell, photo: photo)
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        sharedContext.deleteObject(photo)
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {

        // Resize the cell accordig to the size of the image from Flickr
        collectionView.collectionViewLayout.invalidateLayout()
    }
}

extension PhotoAlbumViewController: UICollectionViewDelegateFlowLayout {
    
    // MARK: - Collection View Delegate Flow Layout
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        if var size = photo.image?.size {
            if size.width > collectionView.frame.width {
                size.width = collectionView.frame.width - 1
            }
            return size
        }
        
        // Default cell size
        return CGSize(width: 100, height: 100)
    }
}

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    // MARK: - Fetched Results Controller Delegate
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
            
        case .Insert:
            photoCollectionView.insertSections(NSIndexSet(index: sectionIndex))
            println("inserted section")
            
        case .Delete:
            photoCollectionView.deleteSections(NSIndexSet(index: sectionIndex))
            println("deleted section")
            
        default:
            return
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            
        case .Insert:
            photoCollectionView.insertItemsAtIndexPaths([newIndexPath!])
            println("inserted object")
            
        case .Update:
            println("updating object")
            
        case .Delete:
            photoCollectionView.deleteItemsAtIndexPaths([indexPath!])
            println("deleted object")
            
        default:
            return
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        println("fetchedResultsController.fetchedObjects!.count \(fetchedResultsController.fetchedObjects!.count)")
    }
}

extension PhotoAlbumViewController {
    
    // MARK: - Helpers
    
    func addTabbedPinToMapView() {
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
    
    func configureCell(cell: PhotoCollectionViewCell, photo: Photo) {
        
        // Setup the activity indicator
        cell.activityIndicator.hidden = false
        cell.activityIndicator.startAnimating()
        
        // If image is saved to DocumentDirectory
        if let image = photo.image  {
            cell.image.image = image
            cell.activityIndicator.hidden = true
            cell.activityIndicator.stopAnimating()
        } else {
            
            // Get that image on background thread
            let session = FlickrClient.sharedInstance().session
            let url = NSURL(string: photo.imageURL)!
            
            let task = session.dataTaskWithURL(url) { data, response, error in
                if let error = error {
                    
                    // Request timed out, Internet connection lost, Internet connection offline
                    if error.code == -1001 || error.code == -1005 || error.code == -1009 {
                        
                        // TODO: - Internet connection problem
                        println("error code in dataTaskWithURL PhotoAlbum: \(error.code)")

                    } else {
                        println("error code in dataTaskWithURL PhotoAlbum: \(error.code)")
                        println("error domain: \(error.domain)")
                        println("error description: \(error.localizedDescription)")
                    }
                } else {
                    let image = UIImage(data: data)
                    photo.image = image

                    // Show to user asap
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.image.image = image
                        cell.activityIndicator.hidden = true
                        cell.activityIndicator.stopAnimating()
                    }
                }
            }
            task.resume()
        }
    }
}