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
    var region: MKCoordinateRegion!
    
    // MARK:- View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        println(tabbedPin.lat)
        println(tabbedPin.lon)
        
        // TODO: Set mapView region
        
        
        // TODO: Add the pin to the mapView
        
    }

    // MARK:- Helpers
    

}
