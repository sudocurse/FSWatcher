//
//  Monitors Filesystem activity
//
//  Run as: ./FSWatcher [--filter exclusion-list] [path-to-watch]
//    ./FSWatcher --filter filter-mac-stuff/filter.txt /;
//
//
import Foundation
import CoreServices
import ArgumentParser

struct Filter: ParsableCommand {
    @Option(help: "Log file you want to filter out")
    var filter: String = ""
    
    @Argument(help: "Paths to monitor")
    var paths: [String] = []
    
}

// handle ctrl+c
signal(SIGINT) { _ in
    FSEventStreamStop(stream!)
    FSEventStreamInvalidate(stream!)
    FSEventStreamRelease(stream!)
    exit(0)
}

func decodeEventFlags(_ flags: FSEventStreamEventFlags) -> String {
    var decodedFlags = ""
    
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0 {
        decodedFlags += "Must Scan Subdirectories, "
    }
    
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagUserDropped) != 0 {
        decodedFlags += "User Dropped Events, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagKernelDropped) != 0 {
        decodedFlags += "Kernel Dropped Events, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagEventIdsWrapped) != 0 {
        decodedFlags += "Event IDs Wrapped, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagHistoryDone) != 0 {
        decodedFlags += "History Done, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0 {
        decodedFlags += "Root Directory Changed, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagMount) != 0 {
        decodedFlags += "Mount, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagUnmount) != 0 {
        decodedFlags += "Unmount, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCreated) != 0 {
        decodedFlags += "Item Created, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRemoved) != 0 {
        decodedFlags += "Item Removed, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod) != 0 {
        decodedFlags += "Item Inode Metadata Modified, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemRenamed) != 0 {
        decodedFlags += "Item Renamed, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemModified) != 0 {
        decodedFlags += "Item Modified, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemFinderInfoMod) != 0 {
        decodedFlags += "Item Finder Info Modified, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemChangeOwner) != 0 {
        decodedFlags += "Item Change Owner, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemXattrMod) != 0 {
        decodedFlags += "Item Extended Attributes Modified, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0 {
        decodedFlags += "Item is File, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsDir) != 0 {
        decodedFlags += "Item is Directory, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsSymlink) != 0 {
        decodedFlags += "Item is Symbolic Link, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagOwnEvent) != 0 {
        decodedFlags += "Own Event, "
    }
    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemCloned) != 0 {
        decodedFlags += "Item Cloned, "
    }
    
    // Remove trailing comma and whitespace
    if decodedFlags.last == " " {
        decodedFlags.removeLast(2)
    }
    
    return decodedFlags
}

func fileSystemEventCallback(
    _ stream: ConstFSEventStreamRef,
    _ contextInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    // check if 0 bytes
    guard numEvents > 0 else { return }
    //let paths = unsafeBitCast(eventPaths, to: Array<String>.self)

    let paths = eventPaths.assumingMemoryBound(to: UnsafeMutablePointer<Int8>?.self)
    

/// This code iterates through a list of events and prints information about each event.
///
/// - Parameters:
///   - numEvents: The total number of events.
///   - paths: An array of paths for each event.
///   - r: An object containing a regex and a flag indicating if it is a regex.
///   - eventFlags: An array of flags for each event.
///   - eventIds: An array of IDs for each event.
func printEventInformation(numEvents: Int, paths: [String?], r: Regex, eventFlags: [Int], eventIds: [Int]) {
    for i in 0..<numEvents {
        let path = String(validatingUTF8: paths[i]!)!
        
        if r.isRegex && path.contains(r.regex) {
            continue
        }
        let flags = eventFlags[i]
        // decode flags for printing
        let decodedFlags = decodeEventFlags(flags)

        let id = eventIds[i]
        print("paths: \(path) flags: \(decodedFlags) id: \(id)")
    }
}
}

let pathsSpecified = Filter.parseOrExit()
if pathsSpecified.paths.isEmpty {
    print("No paths specified")
    exit(1)
} else {
    print("Monitoring: \(pathsSpecified.paths)")
}

let pathsToWatch = pathsSpecified.paths.map { $0 as NSString }
// setup filters

struct FilterRegex {
    var regex: Regex<Substring> = try! Regex("^$")
    var isRegex: Bool = false
    
    mutating func setRegex(to filterString: String) -> Bool {
        if filterString.count > 0 {
            isRegex = true
            regex = try! Regex(filterString)
        }
        return isRegex
    }
}

var r = FilterRegex.init()
if !pathsSpecified.filter.isEmpty {
    let filterFile = pathsSpecified.filter
    let filter = try! String(contentsOfFile: filterFile).split(separator: "\n")
    r.setRegex(to: filter.joined(separator: "|"))
}

var context = FSEventStreamContext(
    version: 0,
    info: nil,
    retain: nil,
    release: nil,
    copyDescription: nil
)


let stream = FSEventStreamCreate(
    kCFAllocatorDefault,
    fileSystemEventCallback,
    &context,
    pathsToWatch as CFArray,
    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
    0.1,
    FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
)

FSEventStreamSetDispatchQueue(stream!, DispatchQueue.main)

FSEventStreamStart(stream!)
CFRunLoopRun()

