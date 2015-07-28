//
//  MapViewController.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/27/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import UIKit
import MapKit

private struct PinData {
    static let Lat = "lat"
    static let Lon = "lon"
    static let LatDelta = "latDelta"
    static let LonDelta = "lonDelta"
    
    static let Key = "pinLocationData"
}

class TravelLocationsMapView: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    private var longPressGestureRecognizer: UILongPressGestureRecognizer!
    private var pinLocationDataDictinoary: [String : CLLocationDegrees]!
    
    // MARK:- View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set mapView delegate
        mapView.delegate = self

        // Long press gesture recognizer
        longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongPressGesture:")
        longPressGestureRecognizer.minimumPressDuration = 1
        longPressGestureRecognizer.numberOfTouchesRequired = 1
        longPressGestureRecognizer.delegate = self
        mapView.addGestureRecognizer(longPressGestureRecognizer)
        
        // Set the mapView region
        pinLocationDataDictinoary = readValue()

        if pinLocationDataDictinoary == nil {
            println("First time app is used")
            
            let initialRegion = MKCoordinateRegionForMapRect(MKMapRectWorld)
            mapView.setRegion(initialRegion, animated: true)
        } else {
            
            // In case there's a previous region saved.
            // Set the mapView region to the last region.
            let span = MKCoordinateSpanMake(
                pinLocationDataDictinoary[PinData.LatDelta]!,
                pinLocationDataDictinoary[PinData.LonDelta]!
            )
            let center = CLLocationCoordinate2DMake(
                pinLocationDataDictinoary[PinData.Lat]!,
                pinLocationDataDictinoary[PinData.Lon]!
            )
            
            let region = MKCoordinateRegion(center: center, span: span)
            mapView.setRegion(region, animated: true)
        }
    }
    
    // MARK:- Gesture Recognizer Delegate
    
    func handleLongPressGesture(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .Ended {
            println("handleLongPressGesture called")
            
            // Create MKPointAnnotation
            let touchPoint = recognizer.locationInView(mapView)
            let touchPointCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchPointCoordinate
            annotation.title = "Tap for Flickr images"
            annotation.subtitle = "Drag to change location"
            
            // Add the annotation to the map view
            mapView.addAnnotation(annotation)
        }
    }
    
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
        
        // Save pin location data dictionary to NSUserDefaults
        pinLocationDataDictinoary = [
            PinData.Lat        : mapView.region.center.latitude,
            PinData.Lon        : mapView.region.center.longitude,
            PinData.LatDelta   : mapView.region.span.latitudeDelta,
            PinData.LonDelta   : mapView.region.span.longitudeDelta
        ]
        saveValue()
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        println("calloutAccessoryControlTapped called")

        performSegueWithIdentifier("photosAlbumSegue", sender: self)
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        println("didChangeDragState called")
        
        println("newState")
        println(view.annotation.coordinate.latitude)
        println(view.annotation.coordinate.longitude)
    
        println("oldState")
        println(view.annotation.coordinate.latitude)
        println(view.annotation.coordinate.longitude)
    }
    
    //MARK:- Helpers
    
    func saveValue() {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setObject(pinLocationDataDictinoary, forKey: PinData.Key)
    }
    
    func readValue() -> [String : CLLocationDegrees]? {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.objectForKey(PinData.Key) as? [String : CLLocationDegrees]
    }
}
