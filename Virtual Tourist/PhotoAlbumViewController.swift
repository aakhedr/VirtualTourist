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
    
    var tabbedPin: Pin!
    
    private var sharedContext : NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy private var fetchedResultsController : NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        // TODO: Change key as you add new properties to Photo
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "imageURL", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.tabbedPin);
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    // MARK:- View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the tabbedPin to the mapView
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
    
    // MARK: - Helpers
    
    func addTabbedPinToMapView() {
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2DMake(
            tabbedPin.lat as! CLLocationDegrees,
            tabbedPin.lon as! CLLocationDegrees
        )
        mapView.addAnnotation(annotation)
    }
    
    func setMapViewRegion() {
        let center = CLLocationCoordinate2DMake(
            tabbedPin.lat as! CLLocationDegrees,
            tabbedPin.lon as! CLLocationDegrees
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
        
        // Image placeholder
        cell.image.image = UIImage(named: "placeholder")
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
                    println("error code: \(error.code)")
                    println("error domain: \(error.domain)")
                    println("error description: \(error.localizedDescription)")
                } else {
                    let image = UIImage(data: data)
                    
                    // Show to user and save context asap
                    dispatch_async(dispatch_get_main_queue()) {
                        photo.image = image
                        cell.image.image = image
                        cell.activityIndicator.hidden = true
                        cell.activityIndicator.stopAnimating()
                        CoreDataStackManager.sharedInstance().saveContext()
                    }
                }
            }
            task.resume()
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
        configureCell(cell, photo: photo)
        
        return cell
    }
}

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    // MARK: - Fetched Results Controller Delegate
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        println("controllerWillChangeContent in PhotoAlbumViewController called")
    }
    
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        switch type {
            
        case .Insert:
            photoCollectionView.insertSections(NSIndexSet(index: sectionIndex))
            
        case .Delete:
            photoCollectionView.insertSections(NSIndexSet(index: sectionIndex))
            
        default:
            return
        }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            
        case .Insert:
            photoCollectionView.insertItemsAtIndexPaths([newIndexPath!])
            
        case .Delete:
            photoCollectionView.deleteItemsAtIndexPaths([indexPath!])
            
        default:
            return
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        println("controllerDidChangeContent in PhotoAlbumViewController called")
    }
}