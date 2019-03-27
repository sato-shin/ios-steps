// 
// Copyright (c) 2018 Asken Inc. All rights reserved.
//

import UIKit
import HealthKit
import CoreMotion

class ViewController: UIViewController {
    
    @IBOutlet weak var pedometerSteps: UILabel!
    @IBOutlet weak var sampleQuerySteps: UILabel!
    @IBOutlet weak var statisticsQuerySteps: UILabel!
    @IBOutlet weak var avoidingCheatSteps: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let readType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!
        store.requestAuthorization(toShare: [], read: [readType]) { _, _ in }
        
        let calendar = Calendar(identifier: .gregorian)
        let dc = calendar.dateComponents(in: .current, from: Date())
        let startOfDate = DateComponents(calendar: calendar, timeZone: .current, year: dc.year, month: dc.month, day: dc.day).date!
        let endOfDate = calendar.date(byAdding: DateComponents(day: 1), to: startOfDate)!
        
        updateStepLabel(start: startOfDate, end: endOfDate)
    }
    
    @IBAction func valueChanged(_ sender: UIDatePicker) {
        let calendar = Calendar(identifier: .gregorian)
        let dc = calendar.dateComponents(in: .current, from: sender.date)
        let startOfDate = DateComponents(calendar: calendar, timeZone: .current, year: dc.year, month: dc.month, day: dc.day).date!
        let endOfDate = calendar.date(byAdding: DateComponents(day: 1), to: startOfDate)!

        updateStepLabel(start: startOfDate, end: endOfDate)
    }

    let store = HKHealthStore()
    func getCountStepUsingSampleQuery(from start: Date, to end: Date, completion handler: @escaping (HKSampleQuery, [HKSample]?, Error?) -> Void) {
        let type = HKSampleType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil, resultsHandler: handler)
        store.execute(query)
    }
    
    func getCountStepUsingStatisticsQuery(from start: Date, to end: Date, completion handler: @escaping (HKStatisticsQuery, HKStatistics?, Error?) -> Void) {
        let type = HKSampleType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum, completionHandler: handler)
        store.execute(query)
    }
    
    func getCountStepUsingStatisticsQueryWithoutThirdpartyData(from start: Date, to end: Date, completion hander: @escaping (HKStatisticsQuery, HKStatistics?, Error?) -> Void) {
        let type = HKSampleType.quantityType(forIdentifier: .stepCount)!
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: datePredicate, options: .separateBySource) { (query, data, error) in
            if let sources = data?.sources?.filter({ $0.bundleIdentifier.hasPrefix("com.apple.health") }) {
                let sourcesPredicate = HKQuery.predicateForObjects(from: Set(sources))
                let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, sourcesPredicate])
                let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum, completionHandler: hander)
                self.store.execute(query)
            }
        }
        store.execute(query)
    }
    
    
    let pedometer = CMPedometer()
    func getCountStepByPedometer(from start: Date, to end: Date, completion handler: @escaping CMPedometerHandler) {
        pedometer.queryPedometerData(from: start, to: end, withHandler: handler)
    }
    
    
    func updateStepLabel(start: Date, end: Date) {
        getCountStepByPedometer(from: start, to: end) { (data, error) in
            DispatchQueue.main.async {
                if let value = data {
                    self.pedometerSteps.text = "\(value.numberOfSteps) steps"
                } else {
                    self.statisticsQuerySteps.text = "nil"
                }
            }
        }
        
        getCountStepUsingSampleQuery(from: start, to: end) { (query, samples, error) in
            DispatchQueue.main.async {
                if let samples = samples as? [HKQuantitySample] {
                    let steps = samples.reduce(0) { $0 + $1.quantity.doubleValue(for: .count()) }
                    self.sampleQuerySteps.text = "\(Int(steps)) steps"
                } else {
                    self.sampleQuerySteps.text = "nil"
                }
            }
        }
        
        getCountStepUsingStatisticsQuery(from: start, to: end) { (query, statistics, error) in
            DispatchQueue.main.async {
                if let value = statistics?.sumQuantity()?.doubleValue(for: .count()) {
                    self.statisticsQuerySteps.text = "\(Int(value)) steps"
                } else {
                    self.statisticsQuerySteps.text = "nil"
                }
            }
        }
        
        getCountStepUsingStatisticsQueryWithoutThirdpartyData(from: start, to: end) { (query, statistics, error) in
            DispatchQueue.main.async {
                if let value = statistics?.sumQuantity()?.doubleValue(for: .count()) {
                    self.avoidingCheatSteps.text = "\(Int(value)) steps"
                } else {
                    self.avoidingCheatSteps.text = "nil"
                }
            }
        }
    }
}
