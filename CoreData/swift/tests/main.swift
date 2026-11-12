// Exercises CoreData the way Feather uses it, through the iOS SDK's interface: an
// NSPersistentContainer over SQLite, the Swift fetch and count(for:), NSManagedObject's
// objectWillChange, and NSBatchDeleteRequest.
import CoreData
import Combine
import Foundation

var failures = 0
func check(_ ok: Bool, _ what: String) {
	print((ok ? "ok   " : "FAIL ") + what)
	fflush(stdout)
	if !ok { failures += 1 }
}

@objc(Item)
final class Item: NSManagedObject {
	@NSManaged var name: String?
	@NSManaged var size: Int64
}

func makeModel() -> NSManagedObjectModel {
	let entity = NSEntityDescription()
	entity.name = "Item"
	entity.managedObjectClassName = NSStringFromClass(Item.self)
	let name = NSAttributeDescription()
	name.name = "name"
	name.attributeType = .stringAttributeType
	name.isOptional = true
	let size = NSAttributeDescription()
	size.name = "size"
	size.attributeType = .integer64AttributeType
	size.isOptional = true
	entity.properties = [name, size]
	let model = NSManagedObjectModel()
	model.entities = [entity]
	return model
}
let model = makeModel()

let dir = FileManager.default.temporaryDirectory.appendingPathComponent("cdtest-\(getpid())")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
let storeURL = dir.appendingPathComponent("Items.sqlite")

func makeContainer() -> NSPersistentContainer? {
	let container = NSPersistentContainer(name: "Items", managedObjectModel: model)
	container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)]
	var loadError: Error?
	container.loadPersistentStores { _, error in loadError = error }
	if let loadError { print("load error: \(loadError)"); return nil }
	container.viewContext.automaticallyMergesChangesFromParent = true
	container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
	return container
}

guard let container = makeContainer() else {
	check(false, "NSPersistentContainer loads a SQLite store")
	exit(1)
}
check(true, "NSPersistentContainer loads a SQLite store")
let context = container.viewContext

for (name, size) in [("a", 1), ("b", 2), ("c", 3), ("d", 4)] {
	let item = Item(context: context)
	item.name = name
	item.size = Int64(size)
}
check((try? context.save()) != nil, "save")

let request: NSFetchRequest<Item> = NSFetchRequest(entityName: "Item")
check((try? context.count(for: request)) == 4, "count(for:) is 4")
let items = (try? context.fetch(request)) ?? []
check(items.count == 4 && Set(items.compactMap(\.name)) == ["a", "b", "c", "d"], "fetch returns the four items")
let sorted = NSFetchRequest<Item>(entityName: "Item")
sorted.sortDescriptors = [NSSortDescriptor(key: "size", ascending: false)]
check(((try? context.fetch(sorted)) ?? []).map(\.size) == [4, 3, 2, 1], "fetch sorted by size")
let untyped = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
check(((try? context.fetch(untyped)) as [Any]?)?.count == 4, "fetch of NSFetchRequestResult as [Any]")

// objectWillChange
let item = items.first { $0.name == "a" }!
check(item.objectWillChange === item.objectWillChange, "objectWillChange is one publisher per object")
var fired = 0
let subscription = item.objectWillChange.sink { fired += 1 }
item.name = "a2"
check(fired >= 1, "objectWillChange fires on a property change (\(fired))")
let before = fired
item.size = 10
check(fired > before, "objectWillChange fires again")
subscription.cancel()
item.name = "a3"
let other = items.first { $0.name == "b" }!
var otherFired = 0
let otherSubscription = other.objectWillChange.sink { otherFired += 1 }
item.size = 11
check(otherFired == 0, "another object's publisher stays quiet")
otherSubscription.cancel()
check((try? context.save()) != nil, "save the changes")
let observables: [any ObservableObject] = items
check(observables.count == 4 && observables.allSatisfy { $0 is Item }, "NSManagedObject as any ObservableObject")

// NSBatchDeleteRequest
let match = NSFetchRequest<NSFetchRequestResult>(entityName: "Item")
match.predicate = NSPredicate(format: "name == %@", "c")
let copied = match.copy() as! NSFetchRequest<NSFetchRequestResult>
check(copied.entityName == "Item" && copied.predicate == match.predicate && copied.includesPendingChanges && copied.resultType == .managedObjectResultType, "NSFetchRequest copies")
check((try? context.count(for: copied)) == 1, "a copied predicate still fetches")
let batch = NSBatchDeleteRequest(fetchRequest: match)
batch.resultType = .resultTypeCount
do {
	let result = try context.execute(batch) as? NSBatchDeleteResult
	check((result?.result as? Int) == 1, "batch delete by predicate deletes one (\(String(describing: result?.result)))")
} catch {
	check(false, "batch delete by predicate: \(error)")
}
let fresh = container.newBackgroundContext()
var storeCount = -1
fresh.performAndWait { storeCount = (try? fresh.count(for: NSFetchRequest<Item>(entityName: "Item"))) ?? -1 }
check(storeCount == 3, "the store holds three after the batch delete (\(storeCount))")
// The view context merges its sibling's save on the main queue.
RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
check((try? context.count(for: request)) == 3, "the view context sees three")

let ids = ((try? context.fetch(request)) ?? []).filter { $0.name == "d" }.map(\.objectID)
let byID = NSBatchDeleteRequest(objectIDs: ids)
byID.resultType = .resultTypeObjectIDs
do {
	let result = try context.execute(byID) as? NSBatchDeleteResult
	check((result?.result as? [NSManagedObjectID])?.count == 1, "batch delete by object ID answers the IDs")
} catch {
	check(false, "batch delete by object ID: \(error)")
}
let all = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "Item"))
do {
	let result = try context.execute(all) as? NSBatchDeleteResult
	check(result?.result as? Bool == true, "status-only batch delete answers true (\(String(describing: result?.result)))")
} catch {
	check(false, "status-only batch delete: \(error)")
}

// Persistence
if let reopened = makeContainer() {
	let count = (try? reopened.viewContext.count(for: NSFetchRequest<Item>(entityName: "Item"))) ?? -1
	check(count == 0, "a reopened store is empty after the batch deletes (\(count))")
} else {
	check(false, "the store reopens")
}

try? FileManager.default.removeItem(at: dir)
print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
