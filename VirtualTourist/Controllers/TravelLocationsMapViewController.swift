//
//  TravelLocationsMapViewController.swift
//  VirtualTourist
//
//  Created by Will Olson on 8/14/21.
//

import UIKit
import CoreData
import MapKit

class TravelLocationsMapViewController: UIViewController {

    // MARK: Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    
    // MARK: Properties
    
    var dataController: DataController!
    var pins: [Pin] = []
    
    // MARK: Lifecycle events

    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadPinFromCoreData()
    }
    
    // MARK: Loading pins
    
    func loadPinFromCoreData() {
        let fetchRequest:NSFetchRequest<Pin> = Pin.fetchRequest()
        
        do {
            pins = try dataController.viewContext.fetch(fetchRequest)
            addPinAnnotations()
            
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }

}

// MARK: Map View Helpers

extension TravelLocationsMapViewController {
    
    func addPinAnnotations() {
        var annotations = [MKPointAnnotation]()
        
        for pin in pins {
            let latitude =  CLLocationDegrees(pin.latitude)
            let longitude =  CLLocationDegrees(pin.longitude)
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate

            annotations.append(annotation)
        }
        
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotations(annotations)
    }

}
