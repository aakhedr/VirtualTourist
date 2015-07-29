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
            RegionData.Lat        : mapView.region.center.latitude,
            RegionData.Lon        : mapView.region.center.longitude,
            RegionData.LatDelta   : mapView.region.span.latitudeDelta,
            RegionData.LonDelta   : mapView.region.span.longitudeDelta
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

}
