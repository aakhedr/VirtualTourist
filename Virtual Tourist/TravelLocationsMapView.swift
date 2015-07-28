//
//  MapViewController.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/27/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import UIKit
import MapKit

class TravelLocationsMapView: UIViewController, MKMapViewDelegate, UIGestureRecognizerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    var longPressGestureRecognizer: UILongPressGestureRecognizer!
    var lat: CLLocationDegrees!
    var lon: CLLocationDegrees!
    var latDelta: CLLocationDegrees!
    var lonDelta: CLLocationDegrees!
    
    // MARK: - View lifecycle
    
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
        lat = readValue(key: "lat")
        lon = readValue(key: "lon")
        latDelta = readValue(key: "latDelta")
        lonDelta = readValue(key: "lonDelta")

        if lat == 0.0 && lon == 0.0 && latDelta == 0.0 && lonDelta == 0.0 {
            println("First time app is used")
            
            let initialRegion = MKCoordinateRegionForMapRect(MKMapRectWorld)
            mapView.setRegion(initialRegion, animated: true)
        } else {
            
            // In case there's a previous region saved.
            // Set the mapView region to the last region.
            let span = MKCoordinateSpanMake(latDelta, lonDelta)
            let center = CLLocationCoordinate2DMake(lat, lon)
            let region = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(region, animated: true)
        }
    }
    
    // MARK: - Gesture Recognizer Delegate
    
    func handleLongPressGesture(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state == .Ended {
            println("handleLongPressGesture called")
            
            // Create MKPointAnnotation
            let touchPoint = recognizer.locationInView(mapView)
            let touchPointCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
            let annotation = MKPointAnnotation()
            annotation.coordinate = touchPointCoordinate
            
            // Add the annotation to the map view
            mapView.addAnnotation(annotation)
        }
    }
    
    // MARK: - Map View Delegate
    
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
                view.canShowCallout = true
                view.calloutOffset = CGPoint(x: -5, y: 5)
                view.rightCalloutAccessoryView = UIButton.buttonWithType(.DetailDisclosure) as! UIView
            }
            return view
        }
        return nil
    }
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        println("regionDidChangeAnimated called")
        
        // Save region params to NSUserDefaults
        saveValue(value: mapView.region.center.latitude, key: "lat")
        saveValue(value: mapView.region.center.longitude, key: "lon")
        saveValue(value: mapView.region.span.latitudeDelta, key: "latDelta")
        saveValue(value: mapView.region.span.longitudeDelta, key: "lonDelta")
    }
    
    //MARK: - Helpers
    
    func saveValue(#value: Double, key: String) {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        userDefaults.setDouble(value, forKey: key)
    }
    
    func readValue(#key: String) -> Double {
        let userDefaults = NSUserDefaults.standardUserDefaults()
        return userDefaults.doubleForKey(key) as CLLocationDegrees
    }

}
