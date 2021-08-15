//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Will Olson on 8/14/21.
//

import UIKit
import MapKit

class PhotoAlbumViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var photoCollectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        photoCollectionView.delegate = self
    }

}

// MARK: Map View Delegate

extension PhotoAlbumViewController: MKMapViewDelegate {
    
}

// MARK: Collection View Delegate

extension PhotoAlbumViewController: UICollectionViewDelegate {
    
}
