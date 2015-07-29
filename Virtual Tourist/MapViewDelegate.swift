//
//  MapViewDelegate.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/29/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import MapKit
import CoreData

extension TravelLocationsMapView {
    
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

}
