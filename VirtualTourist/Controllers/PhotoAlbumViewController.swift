//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Will Olson on 8/14/21.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {
    
    // MARK: Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var photoCollectionView: UICollectionView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: Attributes
    
    var pin: Pin!
    var dataController: DataController!
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    private var blockOperation = BlockOperation()
    
    // MARK: Lifecycle events
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        photoCollectionView.delegate = self
        photoCollectionView.dataSource = self

        setupFetchedResultesController()
        setMapAnnotation()
        fetchPhotosIfMissing()
    }
    
    // MARK: Helpers
    
    func setMapAnnotation() {
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        mapView.addAnnotation(annotation)
        mapView.showAnnotations([annotation], animated: true)
    }
    
    func setupFetchedResultesController() {
        let fetchRequest:NSFetchRequest<Photo> = generatePhotoFetchRequest() as! NSFetchRequest<Photo>
        
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataController.viewContext, sectionNameKeyPath: nil, cacheName: "\(pin.objectID)-photos")
        fetchedResultsController.delegate = self

        do {
            try fetchedResultsController.performFetch()
        } catch {
            fatalError("The fetch could not be performed: \(error.localizedDescription)")
        }
    }
    
    func fetchPhotosIfMissing() {
        if (pin.photos?.count ?? 0) == 0 {
            fetchNewPhotos()
        }
    }
    
    func fetchNewPhotos() {
        let backgroundContext:NSManagedObjectContext! = dataController.backgroundContext
        
        backgroundContext.perform {
            let backgroundPin = backgroundContext.object(with: self.pin.objectID) as! Pin
            print("FOUND BACKGROUND PIN: \(backgroundPin.objectID)")
            
            FlickrAPIClient.getPhotosFromLocation(latitude: backgroundPin.latitude, longitude: backgroundPin.longitude) { response, error in
                if let response = response {
                    for flickerPhoto in response.results.photos {
                        let photo = Photo(context: self.dataController.backgroundContext)
                        photo.flickrId = flickerPhoto.id
                        photo.serverId = flickerPhoto.serverId
                        photo.secret = flickerPhoto.secret
                        photo.pin = backgroundPin
                    }
                    
                    try? backgroundContext.save()
                } else {
                    print("error: \(String(describing: error?.localizedDescription))")
                }
            }
        }
    }
    
    func generatePhotoFetchRequest() -> NSFetchRequest<NSFetchRequestResult> {
        let fetchRequest:NSFetchRequest<NSFetchRequestResult> = Photo.fetchRequest()
        let predicate = NSPredicate(format: "pin == %@", pin)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = []
        
        return fetchRequest
    }
}

// MARK: - Toolbar

extension PhotoAlbumViewController {

    @IBAction func newCollectionTapped(_ sender: Any) {
        deleteAllPhotos()
        activityIndicator.startAnimating()
        fetchNewPhotos()
    }
    
    func deleteAllPhotos() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = generatePhotoFetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        if let result = try? (dataController.backgroundContext.execute(deleteRequest) as! NSBatchDeleteResult) {
            let changes: [AnyHashable: Any] = [
                NSDeletedObjectsKey: result.result as! [NSManagedObjectID]
            ]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [dataController.viewContext])
        }
    }
    
}

// MARK: - Fetched Results Controller Delegate

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        blockOperation = BlockOperation()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        let sectionIndexSet = IndexSet(integer: sectionIndex)
        
        switch type {
        case .insert:
            blockOperation.addExecutionBlock {
                self.photoCollectionView.insertSections(sectionIndexSet)
            }
        case .update:
            blockOperation.addExecutionBlock {
                self.photoCollectionView.reloadSections(sectionIndexSet)
            }
        case .delete:
            blockOperation.addExecutionBlock {
                self.photoCollectionView.deleteSections(sectionIndexSet)
            }
        case .move:
            assertionFailure()
            break
        default:
            fatalError("Only insert, update, delete, and move collection change actions are supported.")
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else { break }
                        
            blockOperation.addExecutionBlock {
                self.photoCollectionView.insertItems(at: [newIndexPath])
            }
        case .update:
            guard let indexPath = indexPath else { break }
                        
            blockOperation.addExecutionBlock {
                self.photoCollectionView.reloadItems(at: [indexPath])
            }
        case .delete:
            guard let indexPath = indexPath else { break }
                        
            blockOperation.addExecutionBlock {
                self.photoCollectionView.deleteItems(at: [indexPath])
            }
        case .move:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath else { break }
                        
            blockOperation.addExecutionBlock {
                self.photoCollectionView.moveItem(at: indexPath, to: newIndexPath)
            }
        default:
            fatalError("Only insert, update, delete, and move collection change actions are supported.")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        photoCollectionView.performBatchUpdates({self.blockOperation.start()}, completion: nil)
    }
    
}

// MARK: - Map View Delegate

extension PhotoAlbumViewController: MKMapViewDelegate {
    
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

// MARK: - Collection View Delegate

extension PhotoAlbumViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultsController.sections?.count ?? 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let savedPhotosCount = fetchedResultsController.sections?[section].numberOfObjects ?? 0
        
        if savedPhotosCount == 0 {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
        
        return savedPhotosCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let backgroundContext:NSManagedObjectContext! = dataController.backgroundContext
        let photo = fetchedResultsController.object(at: indexPath)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
        
        // Set the image and loading state
        if let image = photo.image {
            cell.photoImageView.image = UIImage(data: image)
            cell.activityIndicator.stopAnimating()
        } else {
            cell.activityIndicator.startAnimating()
            
            backgroundContext.perform {
                let backgroundPhoto = backgroundContext.object(with: photo.objectID) as! Photo
                
                FlickrAPIClient.downloadPosterImage(serverId: backgroundPhoto.serverId!, id: backgroundPhoto.flickrId!, secret: backgroundPhoto.secret!) { imageData, error in
                    if let imageData = imageData {
                        backgroundPhoto.image = imageData
                        try? backgroundContext.save()
                    }
                }
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = view.frame.size.width * 0.3
        let height = width
        
        return CGSize(width: width, height: height)
    }
}
