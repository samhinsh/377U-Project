//
//  ViewController.swift
//  377U Project
//
//  Created by Samuel Hinshelwood on 4/23/16.
//  Copyright © 2016 Samuel Hinshelwood. All rights reserved.
//

import UIKit
import MapKit

@IBDesignable class StartScreenViewController: UIViewController, MKMapViewDelegate, UITableViewDataSource, UITableViewDelegate, CLLocationManagerDelegate
{
    
    // MARK - Controller
    
    // CaptureEvent server location content
    
    /* ========= TODO: 1) Either change the url from data.json, or 2) use HTTP Request (or both?) ========= */
    
    private let appServerURL = NSBundle.mainBundle().URLForResource("data", withExtension: "json")
    
    // database that holds and fetches capture events from server
    private var database: CaptureEventDatabase?
    
    // User location manager
    private let locationManager = CLLocationManager()
    
    // map zoom factor
    private let mapZoom = 0.02
    
    // zoom to country
    private var defaultZoom = MKCoordinateRegion()
    
    /* expose revelant location */
    @IBOutlet private weak var mapView: MKMapView!
    
    /* expose relevant capture events */
    @IBOutlet private weak var captureEventsTable: UITableView!
    
    
    /* Segmented control displaying 'nearby' and 'trending' */
    @IBOutlet private weak var captureEventDisplayTab: UISegmentedControl!
    
    private var tabDisplay: String {
        get {
            switch captureEventDisplayTab.selectedSegmentIndex {
            case 0: return "nearby"
            case 1: return "trending"
            default: return "undefined"
            }
        }
    }
    
    /* Capture events being displayed currently */
    private var visibleCaptureEvents =  [CaptureEvent]()
        {
        didSet {
            print("Displaying visible capture events: \(visibleCaptureEvents)")
            print("CaptureEvent Database: \(database!.allCaptureEvents)")
            
            clearPinsFromMap(true)
            
            for event in visibleCaptureEvents {
                plotPinOnMap(event)
            }
            
            captureEventsTable.reloadData() // TODO add event to events table
        }
    }
    
    private func addMapPin(event: CaptureEvent)
    {
        let pin = MKPointAnnotation()
        pin.coordinate = CLLocationCoordinate2D(latitude: event.location.latitude,
                                                longitude: event.location.longitude)
        // set the attributes for this Map pin
        pin.title = event.title + " " + getDistanceFromHereOrEmptyString(locationManager,
                                                                         latitude: event.location.latitude,
                                                                         longitude: event.location.longitude
        )
        print(pin.title)
        pin.subtitle = event.hashtag + ": " + event.about // event.hashtag
        event.mapPin = pin
    }
    
    /* plots an event on the map */
    private func plotPinOnMap(event: CaptureEvent)
    {
        print("Pinning this event's mapPin: \(event)")
        if event.mapPin == nil {
            addMapPin(event)
        }
        
        mapView.addAnnotation(event.mapPin as! MKPointAnnotation)
    }
    
    /* Remove pins from map */
    private func clearPinsFromMap(removeUserLocation: Bool) {
        if removeUserLocation {
            let annotationsToRemove = mapView.annotations.filter { $0 !== mapView.userLocation }
            mapView.removeAnnotations( annotationsToRemove )
        } else {
            mapView.removeAnnotations(mapView.annotations)
        }
    }
    
    /* returns array of capture events happening nearby to user */
    private func getNearbyCaptureEvents() -> [CaptureEvent]
    {
        return database!.allCaptureEvents
        
        // TODO: get events from database
        // TODO: sort/filter them for nearby
        // return them
    }
    
    /* returns array of trending capture events */
    private func getTrendingCaptureEvents() -> [CaptureEvent]
    {
        return Array(database!.allCaptureEvents[0...1])
        
        // TODO: develop scheme for trending
        // get/sort from database
        // return "trending" events
    }
    
    /* Selector showing 'nearby' or 'trending' CaptureEvents has changed
     * Display appropriate CaptureEvents in the table */
    @IBAction private func captureEventDisplayChanged(sender: UISegmentedControl)
    {
        switch sender.selectedSegmentIndex {
        case 0: // 'nearby'
            print("Displaying events nearest to you")
            visibleCaptureEvents = getNearbyCaptureEvents()
            zoomToUserLocation(locationManager)
            
            
        case 1: // 'trending'
            print("Displaying trending events")
            visibleCaptureEvents = getTrendingCaptureEvents()
            zoomToCountry()
            
        default: break;
        }
    }
    
    // MARK: - UITableViewDataSource
    
    private struct CaptureBoard {
        
        // identifier of cells in CaptureBoard (captureEventsTable)
        static let CaptureEventCellIdentifier = "CaptureEvent"
    }
    
    /* next 3 methods are the heart of a dynamic table, get called on tableview.reloadData */
    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleCaptureEvents.count
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCellWithIdentifier(CaptureBoard.CaptureEventCellIdentifier, forIndexPath: indexPath)
        
        // configure the cell...
        let captureEvent = visibleCaptureEvents[indexPath.row]
        
        cell.textLabel?.text = captureEvent.title
        cell.detailTextLabel?.text = captureEvent.about
        
        return cell
    }
    
    // MARK: - Location Delegate methods
    
    /* zoom button on map */
    @IBAction func snapToLocation(sender: UIButton) {
        
        zoomToUserLocation(locationManager)
    }
    
    /* Zoom to worldview */
    private func zoomToCountry()
    {
        self.mapView.setRegion(defaultZoom, animated: true)
    }
    
    /* Zoom to user location given manager */
    private func zoomToUserLocation(manager: CLLocationManager)
    {
        guard manager.location != nil else { return }
        
        let lastLocation = manager.location
        
        let center = CLLocationCoordinate2D(latitude: lastLocation!.coordinate.latitude, longitude: lastLocation!.coordinate.longitude)
        
        // create circle for map to zoom to (1, 1)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: mapZoom, longitudeDelta: mapZoom))
        
        // bring map to the desired region
        self.mapView.setRegion(region, animated: true)
    }
    
    func getDistanceFromHereOrEmptyString(manager: CLLocationManager, latitude: CLLocationDegrees, longitude: CLLocationDegrees ) -> String {
        let distance = distanceFromHereToLocation(locationManager, latitude: latitude, longitude: longitude)
        if distance != nil {
            return distance!
        }
        
        return ""
    }
    
    func distanceFromHereToLocation(manager: CLLocationManager, latitude: CLLocationDegrees, longitude: CLLocationDegrees ) -> String? {
        
        // get the distance in meters
        let distanceToHereFromCurrentLocation = manager.location?.distanceFromLocation(CLLocation(
            latitude: latitude,
            longitude: longitude
            )
        )
        
        guard distanceToHereFromCurrentLocation != nil else { return nil }
        
        // convert to miles
        let distanceInMiles = Double(distanceToHereFromCurrentLocation! * 0.000621371)
        return "(" + String(format:"%.1f", distanceInMiles) + " mi)"
    }
    
    func zoomToUserLocation(manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        let location = locations.last
        
        guard location != nil else { return }
        
        let center = CLLocationCoordinate2D(latitude: location!.coordinate.latitude, longitude: location!.coordinate.longitude)
        
        // create circle for map to zoom to (1, 1)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: mapZoom, longitudeDelta: mapZoom))
        
        // bring map to the desired region
        self.mapView.setRegion(region, animated: true)
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        // zoom to user location only if 'nearby' tab selected
//        if tabDisplay == "nearby" {
//            zoomToUserLocation(manager, didUpdateLocations: locations)
//        }
        // self.locationManager.stopUpdatingLocation()
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("Location errors: \(error.localizedDescription)")
    }
    
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Model
    
    /* ask CaptureEventDatabase to setup an internal db
     * and download capture events from the specified server */
    private func setDatabase(url: NSURL)
    {
        database = CaptureEventDatabase()
        database!.fetchAllCaptureEvents(url)
        
    }
    
    // MARK: - View
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        setDatabase(appServerURL!)
        
        defaultZoom = mapView.region // save map general zoom
        
        self.captureEventsTable.delegate = self // init table view
        self.captureEventsTable.dataSource = self
        
        self.locationManager.delegate = self // init location
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
        
        mapView.showsUserLocation = true // display user location
        
        // display available nearby CaptureEvents
        if tabDisplay == "nearby" {
            visibleCaptureEvents = getNearbyCaptureEvents()
            zoomToUserLocation(locationManager)
        } else {
            visibleCaptureEvents = getTrendingCaptureEvents()
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        print("Main screen will appear!")
        self.navigationController?.setNavigationBarHidden(true, animated: false) // hide navbar
        
        let selectedRow = captureEventsTable.indexPathForSelectedRow
        if selectedRow != nil { // deselect selected row
            captureEventsTable.deselectRowAtIndexPath(selectedRow!, animated: true)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let destinationVC = segue.destinationViewController
        
        if let showEventVC = destinationVC as? CaptureDetailViewController {
            if let identifier = segue.identifier {
                
                switch identifier {
                case "Show Event":
                    if captureEventsTable.indexPathForSelectedRow != nil {
                        let selectedCaptureEvent = visibleCaptureEvents[captureEventsTable.indexPathForSelectedRow!.row] // get selected captureEvent from table
                        showEventVC.setModel(selectedCaptureEvent)
                        showEventVC.navigationItem.title = selectedCaptureEvent.title
                    }
                default: break
                }
            }
        } else if let addToEventVC = destinationVC as? CameraScreenViewController {
            if let identifier = segue.identifier {
                switch identifier {
                case "Add to Event" :
                    addToEventVC.setModel(visibleCaptureEvents)
                default: break
                }
            }
        } else if let newEventVC = destinationVC as? NewEventViewController {
            newEventVC.locationManager = self.locationManager
        }
    }
}

