//
//  Stop.swift
//  TripNow
//
//  Created by Angus Yuen on 21/11/17.
//  Copyright © 2017 Angus Yuen. All rights reserved.
//

import Foundation

/*
 * A Stop typically has
 * id - Unique identifier for the stop, postcode followed by stop number eg. 201718
 * name - Name of the stop (RoadName1 op RoadName2)
 * parent - Parent of the stop, eg. Kensington
 * latitude - Latitude of the stop
 * longitude - Longitude of the stop
 * buses - List of buses (strings) as unique identifiers
 */
class Stop {
    var id: String
    var name: String
    var parent: String
    var latitude: Double
    var longitude: Double
    var buses: [String]     // bus numbers used as identifier
    var distance: Double
    var type: String
    
    init(id: String, name: String, parent: String, latitude: Double, longitude: Double, distance: Double, type: String) {
        self.id = id
        self.name = name
        self.parent = parent
        self.latitude = latitude
        self.longitude = longitude
        self.buses = [String]()
        self.distance = distance
        self.type = type
    }
    
    public func addBus(bus: String) {
        buses.append(bus)
    }
    
    public func getID() -> String {
        return self.id
    }
    
    public func getName() -> String {
        return self.name
    }
    
    public func getParent() -> String {
        return self.parent
    }
    
    public func getLatitude() -> Double {
        return latitude
    }
    
    public func getLongitude() -> Double {
        return longitude
    }
    
    public func getDistance() -> Double {
        return distance
    }
    
    public func getType() -> String {
        return type
    }
    
    public func getBuses() -> [String] {
        return buses
    }
    
    /*
     * Returns true if the bus exists in list of buses
     * False otherwise
     */
    public func isBusExist(bus: String) -> Bool {
        return buses.contains(bus)
    }
}
