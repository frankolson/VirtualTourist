//
//  TravelLocationsMapViewController.swift
//  VirtualTourist
//
//  Created by Will Olson on 8/14/21.
//

import UIKit
import MapKit

class TravelLocationsMapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
    }

}

// MARK: Map View Delegate

extension TravelLocationsMapViewController: MKMapViewDelegate {
    
}
