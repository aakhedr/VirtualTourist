//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Ahmed Khedr on 7/28/15.
//  Copyright (c) 2015 Ahmed Khedr. All rights reserved.
//

import MapKit

class PhotoAlbumViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    
    var tabbedPin: Pin!
    
    // MARK:- View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add the tabbedPin to the mapView
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2DMake(
            tabbedPin.lat as! CLLocationDegrees,
            tabbedPin.lon as! CLLocationDegrees
        )
        mapView.addAnnotation(annotation)
        
        // Set mapView region
        let center = CLLocationCoordinate2DMake(
            tabbedPin.lat as! CLLocationDegrees,
            tabbedPin.lon as! CLLocationDegrees
        )
        let span = MKCoordinateSpanMake(0.5, 0.5)
        mapView.region = MKCoordinateRegionMake(center, span)
    }
    
    // MARK:- Helpers
    

}
