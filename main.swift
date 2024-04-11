// Instructions for experiments on directional queries:
// 1) make sure you have all of the following csv files:
//    - sensorsWithId.csv
//    - NBAstats2WithId.csv
//    - synt2A1000000WithId.csv
//    - synt3A10000000WithId.csv
//    - synt3A1000000WithId.csv
//    - synt3A100000WithId.csv
//    - synt3A10000WithId.csv
//    - synt3A5000000WithId.csv
//    - synt3A500000WithId.csv
//    - synt3A50000WithId.csv
//    - synt4A1000000WithId.csv
//    - synt5A1000000WithId.csv
//    - synt6A1000000WithId.csv
// 2) Change the value of the variable datasetDir so as to reflect the folder containing the above files
// 3) Compile with no debug information for best results (in XCode, edit scheme and use Release as Build Configuration)
// The code will output comma-separated values to the console, corresponding to the quantities measured for the experiments.

import Foundation

// TODO: Adapt the following to the actual folder containing the datasets
fileprivate let datasetDir = "~/cleanData"

/// Parameters and defaults
fileprivate let allKs = [1,5,10,50,100]
fileprivate let allNs = [10000,50000,100000,500000,1000000,5000000,10000000]
fileprivate let allDs = [2,3,4,5,6]
fileprivate let allBetas = [1.0/3,0.5,2.0/3,1.0]
fileprivate let finestBetas = Array(1...20).map { Double($0) / 20.0 }
fileprivate let defaultK = 10
fileprivate let defaultN = 1000000
fileprivate let defaultD = 3
fileprivate let defaultBeta = 2.0/3.0

// MARK: - Experiments shown in the Figures
// Figure 7b
print("\n=== Data for Figure 7b")
experiment(name: "NBAstats2WithId", attributes: ["3PM", "OREB"], ks: allKs, betas: allBetas)

// Figure 6a, 7a, 11a, 13d
print("\n=== Data for Figures 6a, 7a, 11a, 13d")
experiment(name: "sensorsWithId", attributes: ["Global_active_power", "Global_reactive_power", "Voltage", "Global_intensity", "Sub_metering_1", "Sub_metering_2", "Sub_metering_3"], ks: allKs, betas: allBetas)

// Figure 6b
print("\n=== Data for Figure 6b")
var cumulAtt = ["Global_intensity"]
for att in ["Global_active_power", "Global_reactive_power", "Voltage", "Sub_metering_1", "Sub_metering_2", "Sub_metering_3"] {
    cumulAtt.append(att)
    experiment(name: "sensorsWithId", attributes: cumulAtt, ks: [defaultK], betas: allBetas)
}

// Figures 8a, 10a, 10b, 11b, 13a
print("\n=== Data for Figures 8a, 10a, 10b, 11b, 13a")
syntheticExperiment(ns: [defaultN], ds: [defaultD], ks: allKs, betas: allBetas)

// Figure 8b, 11c, 13b
print("\n=== Data for Figures 8b, 11c, 13b")
syntheticExperiment(ns: [defaultN], ds: allDs, ks: [defaultK], betas: allBetas)

// Figure 8c, 10c, 10d, 11d, 13c
print("\n=== Data for Figures 8c, 10c, 10d, 11d, 13c")
syntheticExperiment(ns: allNs, ds: [defaultD], ks: [defaultK], betas: allBetas)

// Figure 12a, 12b
print("\n=== Data for Figures 12a, 12b")
syntheticExperiment(ns: [defaultN], ds: [defaultD], ks: [1,10,100], betas: finestBetas)

// MARK: - Experiments shown only in the text
// rank of the closest skyline tuple
print("\n=== Experiment in the text about rank of the closest skyline tuple")
syntheticRankOfClosestSkylineTuple(ns: [defaultN], ds: [defaultD], betas: allBetas)


// MARK: - Formatting utilities
extension String {
    func padded(length: Int) -> String {
        let len = length-self.count
        return String(repeating: " ", count: len < 0 ? 0 : len) + self
    }
}

// MARK: - Random weight generator

/// Random weight generator
func randomWeights(dimensions: Int, runs: Int) -> [[Double]] {
    var weightRuns = [[Double]]()
    for _ in 1...runs {
        var weights = [Double]()
        var cumulative = 0.0
        for _ in 1...(dimensions-1) {
            let value = Double.random(in: 0.0...(1-cumulative))
            weights.append(value)
            cumulative += value
        }
        let sum = weights.reduce(0.0,+)
        weights.append(1.0 - sum)
        weightRuns.append(weights)
    }
    return weightRuns
}


// MARK: - Rank of closest skyline tuple

func syntheticRankOfClosestSkylineTuple(ns: [Int], ds: [Int], betas: [Double]) {
    for dimensions in ds {
        let attributes = {
            var atts = [String]()
            for i in 1...dimensions {
                atts.append("x\(i)")
            }
            return atts
        }()
        for size in ns {
            rankOfClosestSkylineTuple(name: "synt\(dimensions)A\(size)WithId", attributes: attributes, betas: betas)
        }
    }
}

func rankOfClosestSkylineTuple(name: String, attributes: [String], betas: [Double]) {
    let fileName = NSString(string: "\(datasetDir)/\(name).csv").expandingTildeInPath
    let start = Date()
    let runs = 100
    let dimensions = attributes.count
    let weightRuns = randomWeights(dimensions: dimensions, runs: runs)
    let csvHandler = CSVHandler()
    guard let table = csvHandler.loadAsMap(from: fileName) else {
        print("Impossible to load file \(fileName)")
        return
    }
    let dataSet = csvHandler.dataSet(from: table, with: attributes)
    var algorithm = SkyCalculator(dataSet: dataSet)
    algorithm.computeSkyline()
    guard let sky = algorithm.skyline else { return }
    let skyIds = Set(sky.points.map { $0.id })
    print("--- Experiment on \(name). Size: \(dataSet.points.count). Skyline tuples: \(skyIds.count)")
    print("  id, d,       N, beta, rank,          closest skyline tuple, weights")
    
    var counter = 0
    var allRanks = [Double:[Int]]()
    for beta in betas {
        allRanks[beta] = []
    }

    var allDifferences = [Int]()

    for weights in weightRuns {
        counter += 1

        let t = closestPoint(points: sky.points, weights: weights)
        var ranks = [Int]()
        for beta in betas {
            var k = 1
            var position: Int?
            repeat {
                k *= 10
                if k > dataSet.points.count {
                    k = dataSet.points.count
                }
                let topPoints = beta == 1.0 ? algorithm.computeTopKViaHeap(k: k, weights: weights) : algorithm.computeDirKViaHeap(k: k, weights: weights, beta: beta)
                position = topPoints.firstIndex(of: t)
            } while position == nil
            let rank = position! + 1
            ranks.append(rank)
            var list = allRanks[beta]!
            list.append(rank)
            allRanks[beta] = list
            
            print("{\(counter)".padded(length: 4) + ", " +
                  "\(dimensions)" + ", " +
                  "\(dataSet.points.count)".padded(length: 7) + ", " +
                  String(format: "%.2f", beta) + ", " +
                  "\(rank)".padded(length: 4) + "}," +
                  "\(t), \(weights)")
        }
        allDifferences.append(ranks.max()! - ranks.min()!)
        
    }
    print("Max rank difference: \(allDifferences.max()!)")
    print("Min rank difference: \(allDifferences.min()!)")
    print("Avg rank difference: \(allDifferences.reduce(0,+) / allDifferences.count)")
    for beta in betas {
        print("Max rank for beta = \(String(format: "%.2f", beta)): \(allRanks[beta]!.max()!)")
        print("Min rank for beta = \(String(format: "%.2f", beta)): \(allRanks[beta]!.min()!)")
        print("Avg rank for beta = \(String(format: "%.2f", beta)): \(allRanks[beta]!.reduce(0,+) / allRanks[beta]!.count)")
        let sortedRanks = allRanks[beta]!.sorted()
        let median = sortedRanks[sortedRanks.count/2]
        print("Median rank for beta = \(String(format: "%.2f", beta)): \(median)")
    }
    let elapsed = Date().timeIntervalSince(start)
    print("experiment finished in \(String(format: "%.2f", elapsed)) seconds")
}

func closestPoint(points: [Point], weights: [Double]) -> Point {
    let dirc = DirComparator(weights: weights, beta: 1.0) // beta is unused here
    var closest = points[0]
    var distance = Double.infinity
    for point in points {
        let dist = dirc.distFromPrefLine(values: point.values)
        if dist < distance {
            distance = dist
            closest = point
        }
    }
    return closest
}

// MARK: - Experiments for avgPrec, avgRec, avgDist, cumulRec, time, cumulEvol, cumulGrid
func experiment(name: String, attributes: [String], ks: [Int], betas: [Double]) {
    let fileName = NSString(string: "\(datasetDir)/\(name).csv").expandingTildeInPath
    let runs = 100
    let start = Date()
    let dimensions = attributes.count
    let weightRuns = randomWeights(dimensions: dimensions, runs: runs)
    let csvHandler = CSVHandler()
    guard let table = csvHandler.loadAsMap(from: fileName) else {
        print("Impossible to load file \(fileName)")
        return
    }
    let dataSet = csvHandler.dataSet(from: table, with: attributes)
    var algorithm = SkyCalculator(dataSet: dataSet)
    print("Computing skyline")
    algorithm.computeSkyline()
    guard let sky = algorithm.skyline else { return }
    print("Computing exclusive volume")
    algorithm.computeExclusiveVolume()
    print("Computing grid resistance")
    algorithm.computeGridResistance()
    let skyIds = Set(sky.points.map { $0.id })
    print("--- Experiment on \(name). Size: \(dataSet.points.count). Skyline tuples: \(skyIds.count)")
    print("   k, d,       N,     beta,  avgPrec,   avgRec,  avgDist, cumulRec,     time,cumulEvol,cumulGrid")

    for k in ks {
        var times = [Double]()
        for beta in betas {
            var totalPrecision = 0.0
            var totalRecall = 0.0
            var totalDistance = 0.0
            var cumulativeTopInSky = Set<Int>()
            var totalEvol = 0.0
            var totalGridResistance = 0.0

            for weights in weightRuns {
                let time = Date()
                let topPoints = beta == 1.0 ? algorithm.computeTopKViaHeap(k: k, weights: weights) : algorithm.computeDirKViaHeap(k: k, weights: weights, beta: beta)
                times.append(Date().timeIntervalSince(time))
                let topIds = Set(topPoints.map { $0.id })
                let topInSky = topIds.intersection(skyIds)
                let precision = Double(topInSky.count) / Double(k)
                let recall = Double(topInSky.count) / Double(skyIds.count)
                let dc = DirComparator(weights: weights, beta: beta)
                let distance = topPoints.map { dc.distFromPrefLine(values: $0.values) }
                    .reduce(0.0,+) / Double(topPoints.count)
                let evol = topPoints.filter { topIds.contains($0.id) }
                    .map { algorithm.exclusiveVolumeMap[$0] ?? 0.0 }
                    .reduce(0.0,+)
                let gridReistance = topPoints.filter { topIds.contains($0.id) }
                    .map { algorithm.gridResistanceMap[$0] ?? 0.0 }
                    .reduce(0.0,+)
                totalPrecision += precision
                totalRecall += recall
                totalDistance += distance
                totalEvol += evol
                totalGridResistance += gridReistance
                cumulativeTopInSky.formUnion(topInSky)
            }
            let averagePrecision = totalPrecision / Double(weightRuns.count)
            let averageRecall = totalRecall / Double(weightRuns.count)
            let averageDistance = totalDistance / Double(weightRuns.count)
            let cumulativeRecall = Double(cumulativeTopInSky.count) / Double(skyIds.count)
            let cumulativeTopPointsEvol = sky.points.filter { cumulativeTopInSky.contains($0.id) }
                .map { algorithm.exclusiveVolumeMap[$0] ?? 0.0 }
                .reduce(0.0,+)
            let allPointsEvol = sky.points.filter { skyIds.contains($0.id) }
                .map { algorithm.exclusiveVolumeMap[$0] ?? 0.0 }
                .reduce(0.0,+)
            let cumulativeEvolFraction = cumulativeTopPointsEvol / allPointsEvol
            let cumulativeTopPointsGridResistance = sky.points.filter { cumulativeTopInSky.contains($0.id) }
                .map { algorithm.gridResistanceMap[$0] ?? 0.0 }
                .reduce(0.0,+)
            let allPointsGridResistance = sky.points.filter { skyIds.contains($0.id) }
                .map { algorithm.gridResistanceMap[$0] ?? 0.0 }
                .reduce(0.0,+)
            let cumulativeGridResistanceFraction = cumulativeTopPointsGridResistance / allPointsGridResistance
            let avgTime = times.reduce(0.0,+) / Double(times.count)
            
            print("\(k)".padded(length: 4) + ", " +
                  "\(dimensions)" + ", " +
                  "\(dataSet.points.count)".padded(length: 7) + ", " +
                  String(format: "%.6f", beta) + ", " +
                  String(format: "%.6f", averagePrecision) + ", " +
                  String(format: "%.6f", averageRecall) + ", " +
                  String(format: "%.6f", averageDistance) + ", " +
                  String(format: "%.6f", cumulativeRecall) + ", " +
                  String(format: "%.6f", avgTime) + ", " +
                  String(format: "%.6f", cumulativeEvolFraction) + ", " +
                  String(format: "%.6f", cumulativeGridResistanceFraction))
        }
    }
    let elapsed = Date().timeIntervalSince(start)
    print("experiment finished in \(String(format: "%.2f", elapsed)) seconds")
}

func syntheticExperiment(ns: [Int], ds: [Int], ks: [Int], betas: [Double]) {
    for dimensions in ds {
        let attributes = {
            var atts = [String]()
            for i in 1...dimensions {
                atts.append("x\(i)")
            }
            return atts
        }()
        for size in ns {
            experiment(name: "synt\(dimensions)A\(size)WithId", attributes: attributes, ks: ks, betas: betas)
        }
    }
}

// MARK: -
// MARK: - Accessory data structures and algorithms

// MARK: - Point

typealias IdType = Int

struct Point {
    static var counter = 0
    
    var values: [Double]
    var sum = 0.0
    let id: IdType
    init(values: [Double]) {
        self.init(id: Point.counter, values: values)
        Point.counter += 1
    }
    init(id: IdType, values: [Double]) {
        self.id = id
        self.values = values
        sum = values.reduce(0.0) { $0 + $1 }
    }

    subscript(i: Int) -> Double { return values[i] }
    func dominates(point: Point) -> Bool {
        var hasStrict = false
        for i in 0..<values.count {
            if self[i] > point[i] {
                return false
            } else if self[i] < point[i] {
                hasStrict = true
            }
        }
        return hasStrict
    }
}
extension Point: CustomStringConvertible {
    var csv: String {
        var output = ""
        for value in values {
            output += String(format: "%.6f", value) + ", "
        }
        if output.count > 2 {
            return String(output[..<output.index(output.endIndex, offsetBy: -2)])
        }
        return output
    }
    var description: String {
        return "[" + csv + "]"
    }
}

extension Point: Equatable {}

extension Point: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(values)
    }
}

func == (lhs: Point, rhs: Point) -> Bool {
    for i in 0..<lhs.values.count {
        if lhs[i] != rhs[i] {
            return false
        }
    }
    return true
}

extension Point {
    static func random(dimensions: Int) -> Point {
        var values = [Double]()
        for _ in 1...dimensions {
            values.append(Double(arc4random_uniform(1_000_000))/1_000_000.0)
        }
        return Point(values: values)
    }
}

// MARK: - DataSet

struct DataSet {
    var points: [Point]
    var name = ""
    mutating func add(point: Point) {
        points.append(point)
    }
    var dimensions: Int {
        if points.isEmpty { return 0 }
        return points[0].values.count
    }
}

// MARK: - Dataset and CSV
extension DataSet {
    var csv: String {
        var output = ""
        for point in points {
            output += "\(point.csv)\n"
        }
        return output
    }
    var csvIds: String {
        var output = ""
        for point in points {
            output += "\(point.id),\(point.csv)\n"
        }
        return output
    }
}


// MARK: - CSVHandler

struct CSVHandler {
    func loadAsMap(from path: String, separator: String = ",") -> [[String:String]]? {
        if let aStreamReader = StreamReader(path: path) {
            defer {
                aStreamReader.close()
            }
            guard let firstLine = aStreamReader.nextLine() else { return [] }
            let attributeNames = firstLine.components(separatedBy: separator)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            var table = [[String:String]]()
            while let line = aStreamReader.nextLine() {
                if line == "" { continue }
                let values = line.components(separatedBy: separator)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                
                var row = [String:String]()
                for j in 0..<values.count {
                    row[attributeNames[j]] = values[j]
                }
                table.append(row)
            }
            return table
        }
        return nil
    }
    
    func dataSet(from map: [[String:String]], with attributes: [String], skipIfWrong: Bool = true) -> DataSet {
        var i = 1
        var points = [Point]()
        for row in map {
            var toSkip = false
            var values = [Double]()
            for attribute in attributes {
                if let value = Double(row[attribute] ?? "") {
                    values.append(value)
                } else {
                    print("Wrong value in \(row) for \(attribute)")
                    if skipIfWrong {
                        toSkip = true
                        break
                    } else {
                        return DataSet(points: [])
                    }
                }
            }
            if !toSkip {
                let point = Point(id: i, values: values)
                points.append(point)
                i += 1
            }
        }
        return DataSet(points: points)
    }
}

// MARK: - Heap

public struct Heap<T> {
    var elements = [T]()
    fileprivate var isOrderedBefore: (T, T) -> Bool
    public init(sort: @escaping (T, T) -> Bool) {
        self.isOrderedBefore = sort
    }
    public init(array: [T], sort: @escaping (T, T) -> Bool) {
        self.isOrderedBefore = sort
        buildHeap(fromArray: array)
    }
    fileprivate mutating func buildHeap(fromArray array: [T]) {
        elements = array
        for i in stride(from: (elements.count/2 - 1), through: 0, by: -1) {
            shiftDown(i, heapSize: elements.count)
        }
    }
    
    public var isEmpty: Bool {
        return elements.isEmpty
    }
    
    public var count: Int {
        return elements.count
    }
    
    @inline(__always) func parentIndex(ofIndex i: Int) -> Int {
        return (i - 1) / 2
    }
    
    @inline(__always) func leftChildIndex(ofIndex i: Int) -> Int {
        return 2*i + 1
    }
    
    @inline(__always) func rightChildIndex(ofIndex i: Int) -> Int {
        return 2*i + 2
    }
    
    public func peek() -> T? {
        return elements.first
    }
    
    public mutating func insert(_ value: T) {
        elements.append(value)
        shiftUp(elements.count - 1)
    }
    
    public mutating func insert<S: Sequence>(_ sequence: S) where S.Iterator.Element == T {
        for value in sequence {
            insert(value)
        }
    }
    public mutating func replace(index i: Int, value: T) {
        guard i < elements.count else { return }
        
        assert(isOrderedBefore(value, elements[i]))
        elements[i] = value
        shiftUp(i)
    }
    @discardableResult public mutating func remove() -> T? {
        if elements.isEmpty {
            return nil
        } else if elements.count == 1 {
            return elements.removeLast()
        } else {
            // Use the last node to replace the first one, then fix the heap by
            // shifting this new first node into its proper position.
            let value = elements[0]
            elements[0] = elements.removeLast()
            shiftDown()
            return value
        }
    }
    public mutating func removeAt(_ index: Int) -> T? {
        guard index < elements.count else { return nil }
        
        let size = elements.count - 1
        if index != size {
            elements.swapAt(index, size)
            shiftDown(index, heapSize: size)
            shiftUp(index)
        }
        return elements.removeLast()
    }
    mutating func shiftUp(_ index: Int) {
        var childIndex = index
        let child = elements[childIndex]
        var parentIndex = self.parentIndex(ofIndex: childIndex)
        
        while childIndex > 0 && isOrderedBefore(child, elements[parentIndex]) {
            elements[childIndex] = elements[parentIndex]
            childIndex = parentIndex
            parentIndex = self.parentIndex(ofIndex: childIndex)
        }
        
        elements[childIndex] = child
    }
    
    mutating func shiftDown() {
        shiftDown(0, heapSize: elements.count)
    }
    mutating func shiftDown(_ index: Int, heapSize: Int) {
        var parentIndex = index
        
        while true {
            let leftChildIndex = self.leftChildIndex(ofIndex: parentIndex)
            let rightChildIndex = leftChildIndex + 1
            
            // Figure out which comes first if we order them by the sort function:
            // the parent, the left child, or the right child. If the parent comes
            // first, we're done. If not, that element is out-of-place and we make
            // it "float down" the tree until the heap property is restored.
            var first = parentIndex
            if leftChildIndex < heapSize && isOrderedBefore(elements[leftChildIndex], elements[first]) {
                first = leftChildIndex
            }
            if rightChildIndex < heapSize && isOrderedBefore(elements[rightChildIndex], elements[first]) {
                first = rightChildIndex
            }
            if first == parentIndex { return }
            
            elements.swapAt(parentIndex, first)
            parentIndex = first
        }
    }
}

// MARK: Heap Searching
extension Heap where T: Equatable {
    public func index(of element: T) -> Int? {
        return index(of: element, 0)
    }
    
    fileprivate func index(of element: T, _ i: Int) -> Int? {
        if i >= count { return nil }
        if isOrderedBefore(element, elements[i]) { return nil }
        if element == elements[i] { return i }
        if let j = index(of: element, self.leftChildIndex(ofIndex: i)) { return j }
        if let j = index(of: element, self.rightChildIndex(ofIndex: i)) { return j }
        return nil
    }
}

// MARK: - QueueK

struct QueueK {
    let capacity: Int
    var heap: Heap<Point>
    var isOrderedBefore: (Point, Point) -> Bool
    
    init(capacity: Int, points: [Point], isOrderedBefore: @escaping (Point, Point) -> Bool) {
        self.capacity = capacity
        self.heap = Heap<Point>(array: points) { p1,p2 in !isOrderedBefore(p1, p2) }
        self.isOrderedBefore = isOrderedBefore
    }
    func canInsert(point: Point) -> Bool {
        if let last = heap.peek() {
            return heap.count < capacity || isOrderedBefore(point, last)
        }
        return capacity > 0
    }
    mutating func insert(point: Point) {
        if canInsert(point: point) {
            heap.insert(point)
            if heap.count > capacity {
                heap.remove()
            }
        }
    }
}

// MARK: - SkyCalculator
struct SkyCalculator {
    let dataSet: DataSet
    var window = DataSet(points: [])
    var skyline: DataSet?
    var topK: DataSet?
    var currentMethod = ""
    var dominanceComparisons = 0
    var sortedDataSet = DataSet(points: [])
    var skyTime = 0.0
    var k = 1
    var gridResistanceMap = [Point:Double]()
    var exclusiveVolumeMap = [Point:Double]()
    var dimensions: Int { return dataSet.dimensions }
    var sumOfSquaresOfWeights = 0.0
    
    mutating func computeSkyline() {
        let start = Date()
        dominanceComparisons = 0
        sortData()
        window = DataSet(points: [])
        
        var counter = 0
        let card = sortedDataSet.points.count
        externalLoop:
        for point in sortedDataSet.points {
            
            counter += 1
            if counter > card/100 {
                counter = 0
//                print(".",separator: "",terminator: "")
            }
            // explicit loop to add counting
            for p in window.points {
                dominanceComparisons += 1
                if p.dominates(point: point) {
                    continue externalLoop
                }
            }
            window.add(point: point)

        }
        skyline = window
        skyTime = Date().timeIntervalSince(start)
    }
}

//MARK: Sorting
extension SkyCalculator {
    mutating func sortData() {
        sortedDataSet.points = dataSet.points.sorted(by: { (p1: Point, p2: Point) -> Bool in
            for i in 0..<dimensions {
                if p1.values[i] < p2.values[i] {
                    return true
                } else if p1.values[i] > p2.values[i] {
                    return false
                }
            }
            return false
        })
    }
}

//MARK: Ranking
extension SkyCalculator {
    mutating func computeTopK(k: Int, weights: [Double]) -> [Point] {
        sortedDataSet.points = dataSet.points.sorted(by: { (p1: Point, p2: Point) -> Bool in
            let s1 = zip(weights,p1.values).map { $0.0 * $0.1 }.reduce(0.0,+)
            let s2 = zip(weights,p2.values).map { $0.0 * $0.1 }.reduce(0.0,+)
            return s1 < s2
        })
        return [Point](sortedDataSet.points.prefix(upTo: k))
    }
    mutating func computeDirKViaHeap(k: Int, weights: [Double], invertedWeights: [Double], beta: Double = 2.0/3.0) -> [Point] {
        let dc = DirComparator(weights: weights, beta: beta, invertedWeights: invertedWeights)

        var queue = QueueK(capacity: k, points: []) { p1, p2 in
            return dc.compareWithDir(p1: p1, p2: p2)
        }
        for point in dataSet.points {
            queue.insert(point: point)
        }
        return queue.heap.elements.sorted { p1, p2 in
            return dc.compareWithDir(p1: p1, p2: p2)
        }
    }
    mutating func computeDirKViaHeap(k: Int, weights: [Double], beta: Double = 2.0/3.0) -> [Point] {
        let dc = DirComparator(weights: weights, beta: beta)

        var queue = QueueK(capacity: k, points: []) { p1, p2 in
            return dc.compareWithDir(p1: p1, p2: p2)
        }
        for point in dataSet.points {
            queue.insert(point: point)
        }
        return queue.heap.elements.sorted { p1, p2 in
            return dc.compareWithDir(p1: p1, p2: p2)
        }
    }
    func compareLinear(p1: Point, p2: Point, weights: [Double]) -> Bool {
        let s1 = zip(weights,p1.values).map { $0.0 * $0.1 }.reduce(0.0,+)
        let s2 = zip(weights,p2.values).map { $0.0 * $0.1 }.reduce(0.0,+)
        return s1 < s2
    }
    func computeTopKViaHeap(k: Int, weights: [Double]) -> [Point] {
        var queue = QueueK(capacity: k, points: []) { p1, p2 in
            return compareLinear(p1: p1, p2: p2, weights: weights)
        }
        for point in dataSet.points {
            queue.insert(point: point)
        }
        return queue.heap.elements.sorted { p1, p2 in
            return compareLinear(p1: p1, p2: p2, weights: weights)
        }
    }

}

// MARK: Inversion

func inverseWeights(weights: [Double]) -> [Double] {
    var inverse: [Double] = []
    var zeroCount = 0
    for weight in weights {
        if weight == 0.0 {
            zeroCount += 1
        }
    }
    var sumOfInverses = 0.0
    if zeroCount == 0 {
        for weight in weights {
            sumOfInverses += 1.0 / weight
        }
    }
    for weight in weights {
        if zeroCount > 0 {
            if weight == 0.0 {
                inverse.append(1.0 / Double(zeroCount))
            } else {
                inverse.append(0.0)
            }
        } else {
            inverse.append(1.0 / (weight * sumOfInverses))
        }
    }
    return inverse
}

struct DirComparator {
    var weights: [Double]
    var invertedWeights: [Double]
    var beta: Double
    var sumOfSquaresOfWeights: Double

    init(weights: [Double], beta: Double, invertedWeights: [Double]) {
        self.weights = weights
        self.beta = beta
        self.invertedWeights = invertedWeights
        self.sumOfSquaresOfWeights = invertedWeights.map { $0 * $0 }.reduce(0.0,+)
    }

    init(weights: [Double], beta: Double) {
        self.weights = weights
        self.beta = beta
        self.invertedWeights = inverseWeights(weights: weights)
        self.sumOfSquaresOfWeights = invertedWeights.map { $0 * $0 }.reduce(0.0,+)
    }
    func compareWithDir(p1: Point, p2: Point) -> Bool {
        return score(point: p1) < score(point: p2)
    }
    func score(point: Point) -> Double {
        let s1 = zip(weights,point.values).map { $0.0 * $0.1 }.reduce(0.0,+)
        let l1 = distFromPrefLine(values: point.values)
        let f1 = beta * s1 + (1-beta) * l1
        return f1
    }
    
    func distFromPrefLine(values: [Double]) -> Double {
        var tot = 0.0
        let s = zip(invertedWeights,values).map { $0.0 * $0.1 }.reduce(0.0,+)
        let w2 = sumOfSquaresOfWeights
        for i in 0..<values.count {
            let contrib = values[i] - invertedWeights[i] * s / w2
            tot += contrib * contrib
        }
        return sqrt(tot)
    }
}

//MARK: Indicators
extension SkyCalculator {
    mutating func computeExclusiveVolume() {
        guard let sky = skyline else { return }
        if dimensions == 2 {
            let sortedPoints = sky.points.sorted { $0.values[0] < $1.values[0] }
            for i in 0..<sortedPoints.count {
                let point = sortedPoints[i]
                let xNext = (i == sortedPoints.count-1) ? 1.0 : sortedPoints[i+1].values[0]
                let yPrev = (i == 0) ? 1.0 : sortedPoints[i-1].values[1]
                let evol = (xNext - point.values[0]) * (yPrev - point.values[1])
                exclusiveVolumeMap[point] = evol
            }
        } else {
            let samples = 100000
            for _ in 1...samples {
                let randomPoint = Point.random(dimensions: dimensions)
                let dominance = sky.points.map { $0.dominates(point: randomPoint) }
                let dominanceCount = dominance.reduce(0) {
                    $0 + ($1 ? 1 : 0)
                }
                if dominanceCount == 1 {
                    if let index = dominance.firstIndex(of: true) {
                        let point = sky.points[index]
                        exclusiveVolumeMap[point] = (exclusiveVolumeMap[point] ?? 0.0) + 1.0 / Double(samples)
                    }
                }
            }
        }
    }
    
    mutating func computeGridResistance(maxGres: Int = 250) {
        guard let points = skyline?.points else { return }
        for grid in (2...maxGres).reversed() {
            let gridProjections = points.map {
                Point(id: $0.id, values: $0.values.map {
                    floor($0 * Double(grid)) / Double(grid)
                })
            }
            let gpDataset = DataSet(points: gridProjections)
            var algorithm = SkyCalculator(dataSet: gpDataset)
            algorithm.computeSkyline()
            guard let gpSky = algorithm.skyline else { return }
            let gpSkyIds = gpSky.points.map { $0.id }
//            print("sky size: \(gpSkyIds.count)")
//            print(".", separator: "", terminator: "")
            for point in points {
                if !gpSkyIds.contains(point.id) {
                    if gridResistanceMap[point] == nil {
                        gridResistanceMap[point] = 1.0/Double(grid)
                    }
                }
            }
        }
        for point in points {
            if gridResistanceMap[point] == nil {
                gridResistanceMap[point] = 1.0  // never exited the skyline
            }
        }
    }
}


// MARK: - StreamReader
class StreamReader  {
    
    let encoding : String.Encoding
    let chunkSize : Int
    var fileHandle : FileHandle!
    let delimData : Data
    var buffer : Data
    var atEof : Bool
    
    init?(path: String, delimiter: String = "\n", encoding: String.Encoding = .utf8, chunkSize: Int = 4096) {
        guard let fileHandle = FileHandle(forReadingAtPath: path),
            let delimData = delimiter.data(using: encoding) else {
                return nil
        }
        self.encoding = encoding
        self.chunkSize = chunkSize
        self.fileHandle = fileHandle
        self.delimData = delimData
        self.buffer = Data(capacity: chunkSize)
        self.atEof = false
    }
    
    deinit {
        self.close()
    }
    
    /// Return next line, or nil on EOF.
    func nextLine() -> String? {
        precondition(fileHandle != nil, "Attempt to read from closed file")
        
        // Read data chunks from file until a line delimiter is found:
        while !atEof {
            if let range = buffer.range(of: delimData) {
                // Convert complete line (excluding the delimiter) to a string:
                let line = String(data: buffer.subdata(in: 0..<range.lowerBound), encoding: encoding)
                // Remove line (and the delimiter) from the buffer:
                buffer.removeSubrange(0..<range.upperBound)
                return line
            }
            let tmpData = fileHandle.readData(ofLength: chunkSize)
            if tmpData.count > 0 {
                buffer.append(tmpData)
            } else {
                // EOF or read error.
                atEof = true
                if buffer.count > 0 {
                    // Buffer contains last line in file (not terminated by delimiter).
                    let line = String(data: buffer as Data, encoding: encoding)
                    buffer.count = 0
                    return line
                }
            }
        }
        return nil
    }
    
    /// Close the underlying file. No reading must be done after calling this method.
    func close() -> Void {
        fileHandle?.closeFile()
        fileHandle = nil
    }
}
