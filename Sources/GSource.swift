import Foundation

enum GState: Int {
    case off
    case on
    case hidden
}


enum GMode: Int {
    case offline
    case online
}


@objc class GSource: NSObject {

    @objc var name: String
    @objc var categories: [AnyObject]?
    var items: [GItem]
    var agent: GAgent!
    var mode: GMode
    var status: GState
    var homepage: String!
    var logpage: String!
    var cmd: String = "CMD"

    init(name: String, agent: GAgent! = nil) {
        self.name = name
        self.agent = agent
        items = [GItem]()
        items.reserveCapacity(50000)
        status = .on
        mode = .offline
    }

    func info(_ item: GItem) -> String {
        return "\(item.name) - \(item.version)\n\(self.home(item))"
    }

    func home(_ item: GItem) -> String {
        if item.homepage != nil {
            return item.homepage
        } else {
            return homepage
        }
    }

    func log(_ item: GItem) -> String {
        return home(item)
    }

    func contents(_ item: GItem) -> String {
        return ""
    }

    func cat(_ item: GItem) -> String {
        return "[Not Available]"
    }


    func deps(_ item: GItem) -> String {
        return ""
    }


    func dependents(_ item: GItem) -> String {
        return ""
    }

}

