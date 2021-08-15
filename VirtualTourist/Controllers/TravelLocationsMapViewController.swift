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
        
        setupLongPressGestureRecognizer()
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
    
    // MARK: Saving pins
    
    func savePin(coordinate: CLLocationCoordinate2D) {
        let pin = Pin(context: dataController.viewContext)
        pin.longitude = coordinate.longitude
        pin.latitude = coordinate.latitude
        dataController.saveContext(.viewContext)
    }

}

// MARK: Map View Helpers

extension TravelLocationsMapViewController {
    
    func addPinAnnotations() {
        mapView.removeAnnotations(mapView.annotations)

        for pin in pins {
            let latitude =  CLLocationDegrees(pin.latitude)
            let longitude =  CLLocationDegrees(pin.longitude)
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            addPinAnnotation(coordinate: coordinate)
        }
    }
    
    func addPinAnnotation(coordinate: CLLocationCoordinate2D) {
        let newAnnotation = MKPointAnnotation()
        newAnnotation.coordinate = coordinate
        mapView.addAnnotation(newAnnotation)
    }

}

// MARK: Map View Guestures

extension TravelLocationsMapViewController {
    
    func setupLongPressGestureRecognizer() {
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(sender:)))
        mapView.addGestureRecognizer(longPressRecognizer)
    }
    
    @objc func handleLongPress(sender: UILongPressGestureRecognizer) {
        let location = sender.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)
        
        savePin(coordinate: coordinate)
        addPinAnnotation(coordinate: coordinate)
    }
    
}

// MARK: Map View Delegate

extension TravelLocationsMapViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKPinAnnotationView

        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.pinTintColor = .red
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
}
