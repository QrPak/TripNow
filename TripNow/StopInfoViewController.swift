//
//  StopInfoViewController.swift
//  TripNow
//
//  Created by Angus Yuen on 22/11/17.
//  Copyright © 2017 Angus Yuen. All rights reserved.
//

import MapKit
import UIKit
import EHHorizontalSelectionView

// might need to use stops.txt
// with GTFS realtime trip update to plot routes
// or just use shapes.txt once i figure how it works
class StopInfoViewController: UIViewController, UINavigationBarDelegate, EHHorizontalSelectionViewProtocol, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var destinationLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    var stopObj: Stop?
    var selectionList: EHHorizontalSelectionView!
    var busIdToStopEvent = [String: [StopEvent]]()
    var busIdToTripDesc = [String: TripDescriptor]()
    
    // the bus we tapped on in the horizontal list
    var selectedBus: String!
    var currTime: Date!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        self.navigationItem.title = stopObj?.getName()
        
        self.navigationController?.navigationBar.isTranslucent = false
        // self.edgesForExtendedLayout = []
 
        let selectionList = EHHorizontalSelectionView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 40))
        selectionList.registerCell(with: EHHorizontalLineViewCell.self)
        selectionList.textColor = UIColor.blue
        selectionList.altTextColor = UIColor.black
        EHHorizontalLineViewCell.updateColorHeight(2)
        EHHorizontalLineViewCell.updateFont(UIFont.systemFont(ofSize: 14))
        EHHorizontalLineViewCell.updateFontMedium(UIFont.systemFont(ofSize: 15))
        EHHorizontalLineViewCell.updateTintColor(UIColor.blue)
        self.selectionList = selectionList
        
        view.addSubview(selectionList)
        
        getDepartureRequest()
        
    }
    
    /*
     * Makes a GET request to /departure_mon
     * Obtains the departure details for each of the stops in stopFound
     *
     * NOTE: It's quite clear if I ever want more than 1 person using the app
     * this function isn't scalable at all...
     * Will easily exceed API rate limit
     */
    func getDepartureRequest() {
        let date = Date()
        let dateformatter = DateFormatter()
        print(dateformatter.timeZone)
        dateformatter.timeZone = TimeZone(secondsFromGMT: 60 * 60 * 11)
        print(dateformatter.timeZone)
        dateformatter.dateFormat = "yyyyMMdd"
        let timeformatter = DateFormatter()
        timeformatter.dateFormat = "HHmm"
        timeformatter.timeZone = TimeZone(secondsFromGMT: 60 * 60 * 11)
        let todayDate = dateformatter.string(from: date)    // in format yyyyMMdd
        let currentTime = timeformatter.string(from: date)  // in format hhmm
        currTime = date
        
        /*print("TODAY")
        print(todayDate)
        print(currentTime)*/
        
        guard let id = stopObj?.getID() else { return }
        
        // used to get which buses pass which stop
        let departureURL = "https://api.transport.nsw.gov.au/v1/tp/departure_mon?TfNSWDM=true&outputFormat=rapidJSON&coordOutputFormat=EPSG%3A4326&mode=direct&type_dm=stop&name_dm=" + id + "&depArrMacro=dep&itdDate=" + todayDate + "&itdTime=" + currentTime + "&version=10.2.2.48"
        
        var departureRequest = URLRequest(url: URL(string: departureURL)!)
        departureRequest.addValue("application/json", forHTTPHeaderField: "Accept")
        departureRequest.addValue("apikey 3VEunYsUS44g3bADCI6NnAGzLPfATBClAnmE", forHTTPHeaderField: "Authorization")
        
        let sem = DispatchSemaphore(value: 0)
        
        // get which buses pass the stop
        URLSession.shared.dataTask(with: departureRequest){(data: Data?, response: URLResponse?, error: Error?) -> Void in
            do {
                let resultJson = try JSONSerialization.jsonObject(with: data!, options: []) as? [String:AnyObject]
                print(resultJson!)
                
                let stopEvents = resultJson?["stopEvents"] as? [[String: Any]]
                
                let isoDateFormatter = ISO8601DateFormatter()
                
                if (stopEvents != nil) {
                    for j in 0...(stopEvents!.count - 1) {
                        let isRealTime = stopEvents?[j]["isRealtimeControlled"] as? Bool
                        let location = stopEvents?[j]["location"] as? [String: AnyObject]
                        let properties = location!["properties"] as? [String: AnyObject]
                        let occupancy = isRealTime == true ? properties?["occupancy"] as? String : nil
                        let parent = location?["parent"] as? [String: AnyObject]
                        let nestedParent = parent?["parent"] as? [String: AnyObject]
                        let parentName = nestedParent?["name"] as? String
                        let departureTimePlanned = isoDateFormatter.date(from: (stopEvents?[j]["departureTimePlanned"] as? String)!)
                        let departureTimeEstimated = isRealTime == true ? isoDateFormatter.date(from: (stopEvents?[j]["departureTimeEstimated"] as? String)!): nil
                        let transportation = stopEvents?[j]["transportation"] as? [String: AnyObject]
                        let busNumber = transportation?["number"] as? String
                        let description = transportation?["description"] as? String
                        let origin = transportation?["origin"] as? [String: AnyObject]
                        let destination = transportation?["destination"] as? [String: AnyObject]
                        let originName = origin?["name"] as? String
                        let destinationName = destination?["name"] as? String
                        
                        var shapeSuffix = transportation?["id"] as? String
                        var inboundOrOutbound = ""      // either R (inbound) or H (outbound)
                        var instance = ""
                        if shapeSuffix != nil {
                            shapeSuffix = shapeSuffix?.components(separatedBy: .whitespaces)[1]
                            let tokens = shapeSuffix?.components(separatedBy: ":")
                            if tokens != nil {
                                inboundOrOutbound = tokens![1]
                                instance = tokens![2]
                            }
                        }
                        
                        // initialize selected bus if nil
                        if (self.selectedBus == nil) {
                            self.selectedBus = busNumber
                            
                        }
                        
                        /*print(busNumber!)
                        print(originName!)
                        print(destinationName!)
                        print(description!)
                        print(departureTimePlanned!)*/
                        
                        let newStopEvent = StopEvent(busNumber: busNumber!, departureTimePlanned: departureTimePlanned!, departureTimeEstimated: departureTimeEstimated, occupancy: occupancy, inboundOrOutbound: inboundOrOutbound, instance: instance)
                        
                        // if the busId isn't in the map yet, we need to create a new array for it in the dictionary
                        if (self.busIdToStopEvent[busNumber!] == nil) {
                            var newBus = [StopEvent]()
                            newBus.append(newStopEvent)
                            self.busIdToStopEvent[busNumber!] = newBus
                            self.busIdToTripDesc[busNumber!] = TripDescriptor(origin: originName!, destination: destinationName!, description: description!, parent: parentName!)
                        } else {
                            // otherwise just append to the busNumber's vector
                            (self.busIdToStopEvent[busNumber!])?.append(newStopEvent)
                        }
                        
                        if (!(self.stopObj?.isBusExist(bus: busNumber!))!) {
                            self.stopObj?.addBus(bus: busNumber!)
                        }
                    }
                }
                sem.signal()
            } catch {
                print("Error -> \(error)")
            }
            }.resume()
        
        sem.wait()
        
        if (self.selectedBus != nil) {
            selectionList.delegate = self
            self.tableView.delegate = self
            self.tableView.dataSource = self
            self.destinationLabel?.text = "Destination: " + (self.busIdToTripDesc[self.selectedBus]?.destination)!
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /* Functions to implement for EHHorizontalSelectionViewProtocol */
    
    func numberOfItems(inHorizontalSelection hSelView: EHHorizontalSelectionView) -> UInt {
        guard let count = stopObj?.getBuses().count else { return 0 }
        return UInt(count)
    }
    
    func titleForItem(at index: UInt, forHorisontalSelection hSelView: EHHorizontalSelectionView) -> String? {
        return stopObj?.getBuses()[Int(index)]
    }
    
    /*
     * Callback for the selected item from horizontal view
     */
    func horizontalSelection(_ selectionView: EHHorizontalSelectionView, didSelectObjectAt index: UInt) {
        self.selectedBus = stopObj?.getBuses()[Int(index)]
        self.destinationLabel?.text = "Destination: " + (self.busIdToTripDesc[self.selectedBus]?.destination)!
        self.tableView.reloadData()
    }
    
    /* Functions for UITableView */
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.busIdToStopEvent[self.selectedBus]?.count)!
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CustomCell", for: indexPath) as! CustomTableViewCell
        let row = indexPath.row
        let table = self.busIdToStopEvent[self.selectedBus]
        
        let sydneyTimeFormatter = DateFormatter()
        sydneyTimeFormatter.dateFormat = "h:mm a"
        sydneyTimeFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        
        /*let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM"
        dateFormatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        
        let date = dateFormatter.string(from: (table?[row].getDepartureTimePlanned())!)*/
        
        // cell.dateLabel?.text = String(describing: date)
        
        // if estimated time is not nil, it is real time
        if (table?[row].getDepartureTimeEstimated() != nil) {
            let timeDifference = table?[row].getDepartureTimePlanned().timeIntervalSince((table?[row].getDepartureTimeEstimated())!)
            // if timeDifference is negative, bus must be late, otherwise early
            var isEarly = Int(timeDifference!) < 0 ? "Late by" : "Early by"
            if (Int(timeDifference!) == 0) {
                isEarly = "On time"
            }
            
            let hours = Int(abs(timeDifference!)) / 3600
            let minutes = (Int(abs(timeDifference!)) / 60) % 60
            var lateTimeStr = ""
            if (hours != 0) {
                lateTimeStr = lateTimeStr + String(hours) + " hours"
            }
            
            if (minutes != 0) {
                lateTimeStr = lateTimeStr + String(minutes) + " minute"
                if (minutes > 1) {
                    lateTimeStr = lateTimeStr + "s"
                }
            }
           
            /*if (lateTimeStr != "") {
                lateTimeStr = lateTimeStr + "."
            }*/
            
            cell.timeTopLabel?.text = String(describing: (sydneyTimeFormatter.string(from: (table?[row].getDepartureTimeEstimated())!)))
            cell.timeBottomLabel?.text = String(describing: (sydneyTimeFormatter.string(from: (table?[row].getDepartureTimePlanned())!))) + " " + isEarly + " " + lateTimeStr
            
            if (table?[row].getOccupancy() == nil) {
                cell.busCapImg1?.image = UIImage(named: "customer-40-grey")
                cell.busCapImg2?.image = UIImage(named: "customer-40-grey")
                cell.busCapImg3?.image = UIImage(named: "customer-40-grey")
            } else if (table?[row].getOccupancy() == "MANY_SEATS") {
                cell.busCapImg1?.image = UIImage(named: "customer-40-green")
                cell.busCapImg2?.image = UIImage(named: "customer-40-grey")
                cell.busCapImg3?.image = UIImage(named: "customer-40-grey")
            } else if (table?[row].getOccupancy() == "FEW_SEATS") {
                cell.busCapImg1?.image = UIImage(named: "customer-40-yellow")
                cell.busCapImg2?.image = UIImage(named: "customer-40-yellow")
                cell.busCapImg3?.image = UIImage(named: "customer-40-grey")
            } else {
                cell.busCapImg1?.image = UIImage(named: "customer-40-red")
                cell.busCapImg2?.image = UIImage(named: "customer-40-red")
                cell.busCapImg3?.image = UIImage(named: "customer-40-red")
            }
            
            cell.setWaitTimeLabel(time: (table?[row].getDepartureTimeEstimated())!, currentTime: self.currTime)
        } else {
            // no real time
            cell.setUINoRealTime(time: sydneyTimeFormatter.string(from: (table?[row].getDepartureTimePlanned())!))
            cell.setWaitTimeLabel(time: (table?[row].getDepartureTimePlanned())!, currentTime: self.currTime)
        }
        
        cell.parentLabel?.text = self.busIdToTripDesc[self.selectedBus]?.getParent()
        
        return cell
    }
}
