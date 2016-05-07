//
//  CollectionType+Merge.swift
//  ConfigManager
//
//  Created by Marc Ammann on 5/6/16.
//  Copyright © 2016 Codesofa. All rights reserved.
//

import Foundation

//extension CollectionType {
//    mutating func updateWith<T: CollectionType>(rhs: T) {
//        // Ok, this is mildly stupid.
//        // But this allows that if we don't know about a sequence
//        // the new collection is just going to override the previous one.
//    }
//}
//
//extension Array {
//    mutating func updateWith<S : CollectionType where S.Generator.Element == Element>(rhs: S) {
//        self.appendContentsOf(rhs)
//    }
//}
//
//extension Set {
//    mutating func updateWith<S : CollectionType where S.Generator.Element == Element>(rhs: S) {
//        self.unionInPlace(rhs)
//    }
//}


extension Dictionary {
    mutating func updateWith(rhs: Dictionary<Key, Value>) {
        for (rhsKey, rhsValue) in rhs {
            // With dictionaries, we loop through and
            // check if we can do a deep merge.
            // Check if key exists in both and if it's a collection
            //   if so, update
            // Otherwise rhs overrides current.
            guard let _ = self[rhsKey] else {
                updateValue(rhsValue, forKey: rhsKey)
                continue
            }
            
            if let lhsDictionaryValue = self[rhsKey] as? Dictionary<Key, Value>, rhsDictionaryValue = rhsValue as? Dictionary<Key, Value> {
                var value = lhsDictionaryValue
                value.updateWith(rhsDictionaryValue)
                
                updateValue(value as! Value, forKey: rhsKey)
            } else {
                updateValue(rhsValue, forKey: rhsKey)
            }
            
        }
    }
}

