//
//  PartitioningIndex.swift
//  Reco
//
//  Created by Diip3sh on 26.09.26.
//

extension RandomAccessCollection {

    /// The index of the first element in the second partition, or `endIndex` if there is none: a
    /// binary search in a collection where every element that satisfies `isInSecondPartition`
    /// follows every element that doesn't, such as events sorted by time.
    nonisolated func partitioningIndex(where isInSecondPartition: (Element) throws -> Bool) rethrows -> Index {
        var low = startIndex
        var count = count
        while count > 0 {
            let half = count / 2
            let middle = index(low, offsetBy: half)
            if try isInSecondPartition(self[middle]) {
                count = half
            } else {
                low = index(after: middle)
                count -= half + 1
            }
        }
        return low
    }
}
