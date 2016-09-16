//
//  GPSManager.swift
//  Beiwe
//
//  Created by Keary Griffin on 3/29/16.
//  Copyright © 2016 Rocketfarm Studios. All rights reserved.
//

import Foundation
import CoreLocation
import Darwin
import PromiseKit

protocol DataServiceProtocol {
    func initCollecting() -> Bool;
    func startCollecting();
    func pauseCollecting();
    func finishCollecting() -> Promise<Void>;
}

class DataServiceStatus {
    let onDurationSeconds: Double;
    let offDurationSeconds: Double;
    var currentlyOn: Bool;
    var nextToggleTime: NSDate?;
    let handler: DataServiceProtocol;

    init(onDurationSeconds: Int, offDurationSeconds: Int, handler: DataServiceProtocol) {
        self.onDurationSeconds = Double(onDurationSeconds);
        self.offDurationSeconds = Double(offDurationSeconds);
        self.handler = handler;
        currentlyOn = false;
        nextToggleTime = NSDate();
        // nextToggleTime = NSDate().dateByAddingTimeInterval(self.offDurationSeconds);
    }
}

class GPSManager : NSObject, CLLocationManagerDelegate, DataServiceProtocol {
    let locationManager = CLLocationManager();
    var lastLocations: [CLLocation]?;
    var isCollectingGps: Bool = false;
    var dataCollectionServices: [DataServiceStatus] = [ ];
    var gpsStore: DataStorage?;
    var areServicesRunning = false;
    static let headers = [ "timestamp", "latitude", "longitude", "altitude", "accuracy"];
    var isDeferringUpdates = false;
    var nextSurveyUpdate: NSTimeInterval = 0, nextServiceDate: NSTimeInterval = 0;
    var timer: NSTimer?;

    func gpsAllowed() -> Bool {
        return CLLocationManager.locationServicesEnabled() &&  CLLocationManager.authorizationStatus() == .AuthorizedAlways;
    }

    func startGpsAndTimer() -> Bool {

        locationManager.delegate = self;
        locationManager.activityType = CLActivityType.Other;
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = true
        } else {
            // Fallback on earlier versions
        };
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = 99999;
        locationManager.requestAlwaysAuthorization();
        locationManager.pausesLocationUpdatesAutomatically = false;
        locationManager.startUpdatingLocation();
        locationManager.startMonitoringSignificantLocationChanges()

        if (!gpsAllowed()) {
            return false;
        }

        areServicesRunning = true
        startPollTimer(1.0)

        return true;

    }

    func stopAndClear() -> Promise<Void> {
        locationManager.stopUpdatingLocation();
        areServicesRunning = false
        clearPollTimer();
        var promises: [Promise<Void>] = [];
        for dataStatus in dataCollectionServices {
            promises.append(dataStatus.handler.finishCollecting())
        }
        dataCollectionServices.removeAll();
        return when(promises)
    }

    func dispatchToServices() -> NSTimeInterval {
        let currentDate = NSDate().timeIntervalSince1970;
        var nextServiceDate = currentDate + (60 * 60);

        for dataStatus in dataCollectionServices {
            if let nextToggleTime = dataStatus.nextToggleTime {
                var serviceDate = nextToggleTime.timeIntervalSince1970;
                if (serviceDate <= currentDate) {
                    if (dataStatus.currentlyOn) {
                        dataStatus.handler.pauseCollecting();
                        dataStatus.currentlyOn = false;
                        dataStatus.nextToggleTime = NSDate(timeIntervalSince1970: currentDate + dataStatus.offDurationSeconds);
                    } else {
                        dataStatus.handler.startCollecting();
                        dataStatus.currentlyOn = true;
                        /* If there is no off time, we run forever... */
                        if (dataStatus.offDurationSeconds == 0) {
                            dataStatus.nextToggleTime = nil;
                        } else {
                            dataStatus.nextToggleTime = NSDate(timeIntervalSince1970: currentDate + dataStatus.onDurationSeconds);
                        }
                    }
                    serviceDate = dataStatus.nextToggleTime?.timeIntervalSince1970 ?? DBL_MAX;
                }
                nextServiceDate = min(nextServiceDate, serviceDate);
            }
        }
        return nextServiceDate;
    }

    func pollServices() {
        log.info("Polling...");
        clearPollTimer();
        if (!areServicesRunning) {
            return
        }

        nextServiceDate = dispatchToServices();

        let currentTime = NSDate().timeIntervalSince1970;
        StudyManager.sharedInstance.periodicNetworkTransfers();

        if (currentTime > nextSurveyUpdate) {
            nextSurveyUpdate = StudyManager.sharedInstance.updateActiveSurveys();
        }

        setTimerForService();

    }

    func setTimerForService() {
        nextServiceDate = min(nextSurveyUpdate, nextServiceDate);
        let currentTime = NSDate().timeIntervalSince1970;
        let nextServiceSeconds = max(nextServiceDate - currentTime, 1.0);
        startPollTimer(nextServiceSeconds)
    }

    func clearPollTimer() {
        if let timer = timer {
            timer.invalidate();
            self.timer = nil;
        }
    }

    func resetNextSurveyUpdate(time: Double) {
        nextSurveyUpdate = time
        if (nextSurveyUpdate < nextServiceDate) {
            setTimerForService();
        }
    }

    func startPollTimer(seconds: Double) {
        clearPollTimer();
        timer = NSTimer.scheduledTimerWithTimeInterval(seconds, target: self, selector: #selector(pollServices), userInfo: nil, repeats: false)
        log.info("Timer set for: \(seconds)");
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if (!areServicesRunning) {
            return
        }

        if (isCollectingGps) {
            recordGpsData(manager, locations: locations);
        }

        /*
        if (!isCollectingGps && !isDeferringUpdates) {
            locationManager.allowDeferredLocationUpdatesUntilTraveled(10000, timeout: nextServiceSeconds);
            isDeferringUpdates = true;
        }
        */

    }

    func locationManager(manager: CLLocationManager, didFinishDeferredUpdatesWithError error: NSError?) {
        isDeferringUpdates = false;
    }

    func recordGpsData(manager: CLLocationManager, locations: [CLLocation]) {
        //print("Record locations: \(locations)");
        for loc in locations {
            var data: [String] = [];

            //     static let headers = [ "timestamp", "latitude", "longitude", "altitude", "accuracy", "vert_accuracy"];

            data.append(String(Int64(loc.timestamp.timeIntervalSince1970 * 1000)))
            data.append(String(loc.coordinate.latitude))
            data.append(String(loc.coordinate.longitude))
            data.append(String(loc.altitude))
            data.append(String(loc.horizontalAccuracy))
            gpsStore?.store(data);
        }
    }

    func addDataService(on: Int, off: Int, handler: DataServiceProtocol) {
        let dataServiceStatus = DataServiceStatus(onDurationSeconds: on, offDurationSeconds: off, handler: handler);
        if  handler.initCollecting() {
            dataCollectionServices.append(dataServiceStatus);
        }

    }

    func addDataService(handler: DataServiceProtocol) {
        addDataService(1, off: 0, handler: handler);
    }
    /* Data service protocol */

    func initCollecting() -> Bool {
        guard  gpsAllowed() else {
            log.error("GPS not enabled.  Not initializing collection")
            return false;
        }
        gpsStore = DataStorageManager.sharedInstance.createStore("gps", headers: GPSManager.headers);
        isCollectingGps = false;
        return true;
    }
    func startCollecting() {
        log.info("Turning GPS collection on");
        isCollectingGps = true;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone;
    }
    func pauseCollecting() {
        log.info("Pausing GPS collection");
        isCollectingGps = false;
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = 99999;
        gpsStore?.flush();
    }
    func finishCollecting() -> Promise<Void> {
        pauseCollecting();
        isCollectingGps = false;
        gpsStore = nil;
        return DataStorageManager.sharedInstance.closeStore("gps");
    }
}