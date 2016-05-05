//
//  LocationManager.swift
//  alexa-location-finder
//
//  Created by Andrew Monshizadeh on 4/24/16.
//  Copyright © 2016 amonshiz. All rights reserved.
//

import Foundation
import CoreLocation

class LocationManager : NSObject {
    static private let sharedManager = LocationManager()

    private var _completion: ((location: CLLocation?) -> Void)?
    private var _manager: CLLocationManager

    override init() {
        _manager = CLLocationManager()
        _manager.allowsBackgroundLocationUpdates = true
        super.init()

        _manager.delegate = self
    }

    static func getCurrentLocation(completion: (location: CLLocation?) -> Void) {
        sharedManager._completion = completion

        sharedManager._manager.requestLocation()
    }
}

extension LocationManager : CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("locations: \(locations)")
        guard let loc = locations.first else {
            _completion?(location: nil)
            return
        }

        self._completion?(location: loc)
    }

    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print("error: \(error)")
        _completion?(location: nil)
    }
}