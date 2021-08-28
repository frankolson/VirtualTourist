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
    private var blockOperations: [BlockOperation] = []
    
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
    
    deinit {
        for blockOperation in blockOperations {
            blockOperation.cancel()
        }
        
        blockOperations.removeAll(keepingCapacity: false)
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
        let backgroundContext = dataController.backgroundContext!
        
        backgroundContext.perform {
            let backgroundPin = backgroundContext.object(with: self.pin.objectID) as? Pin
            
            if let backgroundPin = backgroundPin {
                FlickrAPIClient.getPhotosFromLocation(latitude: backgroundPin.latitude, longitude: backgroundPin.longitude) { response, error in
                    if let response = response {
                        for flickerPhoto in response.results.photos {
                            print("flicker ID: \(flickerPhoto.id), server ID: \(flickerPhoto.serverId), secret: \(flickerPhoto.secret)")
                            let photo = Photo(context: backgroundContext)
                            photo.flickrId = flickerPhoto.id
                            photo.serverId = flickerPhoto.serverId
                            photo.secret = flickerPhoto.secret
                            photo.pin = backgroundPin
                        }
                        
                        self.dataController.saveContext(.backgroundContext)
                    } else {
                        print("error: \(String(describing: error?.localizedDescription))")
                    }
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
    
    func deletePhoto(_ photo: Photo) {
        dataController.viewContext.delete(photo)
        try? dataController.viewContext.save()
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

// MARK: - Toolbar

extension PhotoAlbumViewController {

    @IBAction func newCollectionTapped(_ sender: Any) {
        deleteAllPhotos()
        activityIndicator.startAnimating()
        fetchNewPhotos()
    }
    
}

// MARK: - Fetched Results Controller Delegate

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        let sectionIndexSet = IndexSet(integer: sectionIndex)
        
        switch type {
        case .insert:
            blockOperations.append(
                BlockOperation(block: { [weak self] in
                    self?.photoCollectionView.insertSections(sectionIndexSet)
                })
            )
        case .update:
            blockOperations.append(
                BlockOperation(block: { [weak self] in
                    self?.photoCollectionView.reloadSections(sectionIndexSet)
                })
            )
        case .delete:
            blockOperations.append(
                BlockOperation(block: { [weak self] in
                    self?.photoCollectionView.deleteSections(sectionIndexSet)
                })
            )
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
                        
            blockOperations.append(
                BlockOperation(block: { [weak self] in
                    self?.photoCollectionView.insertItems(at: [newIndexPath])
                })
            )
        case .update:
            guard let indexPath = indexPath else { break }
                
            blockOperations.append(
                BlockOperation(block: { [weak self] in
                    self?.photoCollectionView.reloadItems(at: [indexPath])
                })
            )
        case .delete:
            guard let indexPath = indexPath else { break }
                   
            blockOperations.append(
                BlockOperation(block: { [weak self] in
                    self?.photoCollectionView.deleteItems(at: [indexPath])
                })
            )
        case .move:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath else { break }
                        
            blockOperations.append(
                BlockOperation(block: { [weak self] in
                    self?.photoCollectionView.moveItem(at: indexPath, to: newIndexPath)
                })
            )
        default:
            fatalError("Only insert, update, delete, and move collection change actions are supported.")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        photoCollectionView.performBatchUpdates {
            for blockOperation in self.blockOperations {
                blockOperation.start()
            }
        } completion: { _ in
            self.blockOperations.removeAll(keepingCapacity: false)
        }
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
        let photo = fetchedResultsController.object(at: indexPath)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCollectionViewCell", for: indexPath) as! PhotoCollectionViewCell
        
        // Set the image and loading state
        if let image = photo.image {
            cell.photoImageView.image = UIImage(data: image)
            cell.activityIndicator.stopAnimating()
        } else {
            cell.activityIndicator.startAnimating()
            downloadImageAsync(photo: photo)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photo: Photo = fetchedResultsController.object(at: indexPath)
        presentDeletePhoto(photo)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = view.frame.size.width * 0.3
        let height = width

        return CGSize(width: width, height: height)
    }
    
    func downloadImageAsync(photo: Photo) {
        let backgroundContext = dataController.backgroundContext
        
        backgroundContext?.perform {
            let backgroundPhoto = backgroundContext?.object(with: photo.objectID) as? Photo
            
            if let backgroundPhoto = backgroundPhoto,
               let id = backgroundPhoto.flickrId,
               let serverId = backgroundPhoto.serverId,
               let secret = backgroundPhoto.secret {
                FlickrAPIClient.downloadPosterImage(serverId: serverId, id: id, secret: secret) { imageData, error in
                    if let imageData = imageData {
                        photo.image = imageData
                        try? backgroundContext?.save()
                    }
                }
            }
        }
    }
    
    func presentDeletePhoto(_ photo: Photo) {
        let alert = UIAlertController(title: "Delete Photo", message: "Are you sure you want to delete this photo?", preferredStyle: .alert)

        // delete actions
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let deleteAction = UIAlertAction(title: "Delete", style: .default) { [weak self] action in
            self?.deletePhoto(photo)
        }

        alert.addAction(cancelAction)
        alert.addAction(deleteAction)
        present(alert, animated: true, completion: nil)
    }
}
