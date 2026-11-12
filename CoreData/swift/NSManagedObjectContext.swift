//===----------------------------------------------------------------------===//
// This source file is part of the Swift.org open source project
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
// See https://swift.org/LICENSE.txt and https://swift.org/CONTRIBUTORS.txt
// Adapted from swiftlang/swift ba33f9e0b772015326bdecc0d597b2ac9fc61717
// stdlib/public/SDK/CoreData/NSManagedObjectContext.swift.
//===----------------------------------------------------------------------===//
@_exported import CoreData
import Combine
import Foundation
import DarlingCoreDataSupplementBridge

extension NSManagedObjectContext {
    public func fetch<T>(_ request: NSFetchRequest<T>) throws -> [T]
        where T: NSFetchRequestResult {
        var error: NSError?
        let values = DarlingCoreDataExecuteFetch(self, request, &error)
        guard let values else {
            if let error { throw error }
            preconditionFailure("CoreData fetch returned neither results nor an error")
        }
        return values as! [T]
    }

    @_disfavoredOverload
    public func fetch(_ request: NSFetchRequest<NSFetchRequestResult>) throws -> [Any] {
        return try fetch(request) as [NSFetchRequestResult]
    }

    public func count<T>(for request: NSFetchRequest<T>) throws -> Int
        where T: NSFetchRequestResult {
        var error: NSError?
        let result = DarlingCoreDataCount(self, request, &error)
        guard result != NSNotFound else {
            if let error { throw error }
            preconditionFailure("CoreData count returned neither a count nor an error")
        }
        return result
    }
}

// Sent from the bridge's willChangeValueForKey: and its to-many forms, which every managed
// property change goes through.
private func sendObjectWillChange(_ publisher: AnyObject) {
    (publisher as! ObservableObjectPublisher).send()
}

extension NSManagedObject: ObservableObject {
    public var objectWillChange: ObservableObjectPublisher {
        if let publisher = DarlingCoreDataObjectWillChangePublisher(self) {
            return publisher as! ObservableObjectPublisher
        }
        return DarlingCoreDataSetObjectWillChangePublisher(self, ObservableObjectPublisher(),
            { sendObjectWillChange($0 as AnyObject) }) as! ObservableObjectPublisher
    }
}
