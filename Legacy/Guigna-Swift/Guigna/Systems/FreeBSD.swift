import Foundation

final class FreeBSD: GSystem {

    override class var prefix: String { return  "" }

    init(agent: GAgent) {
        super.init(name: "FreeBSD", agent: agent)
        homepage = "http://www.freebsd.org/ports/"
        logpage = "http://www.freshports.org"
        cmd = "\(prefix)freebsd"
    }

    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        let indexPath = ("~/Library/Application Support/Guigna/FreeBSD/INDEX" as NSString).expandingTildeInPath
        if indexPath.exists {
            let lines = (try! String(contentsOfFile: indexPath, encoding: String.Encoding.utf8)).split("\n")
            for line in lines {
                let components = line.split("|")
                var name = components[0]
                let idx = name.rindex("-")
                if idx == NSNotFound {
                    continue
                }
                let version = name.substringFromIndex(idx + 1)
                name = name.substringToIndex(idx)
                let description = components[3]
                let category = components[6]
                let homepage = components[9]
                let pkg = GPackage(name: name, version: version, system: self, status: .available)
                pkg.categories = category
                pkg.description = description
                pkg.homepage = homepage
                items.append(pkg)
                // self[id] = pkg
            }

        } else {
            let url = URL(string: "http://www.freebsd.org/ports/master-index.html")!
            if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
                let root = xmlDoc.rootElement()!["/*"][0]
                let names = root["//p/strong/a"]
                let descriptions = root["//p/em"]
                var i = 0
                for node in names {
                    var name = node.stringValue!
                    let idx = name.rindex("-")
                    let version = name.substringFromIndex(idx + 1)
                    name = name.substringToIndex(idx)
                    var category = node.href
                    category = category.substringToIndex(category.index(".html"))
                    let description = descriptions[i].stringValue!
                    let pkg = GPackage(name: name, version: version, system: self, status: .available)
                    pkg.categories = category
                    pkg.description = description
                    items.append(pkg)
                    // self[id] = pkg
                    i += 1
                }
            }
        }
        // self.installed() // update status
        return items as! [GPackage]
    }


    override func info(_ item: GItem) -> String { // TODO: Offline mode
        let category = item.categories!.split()[0]
        var itemName = item.name
        var pkgDescr = (try? String(contentsOfURL: URL(string: "http://svnweb.freebsd.org/ports/head/\(category)/\(item.name)/pkg-descr?view=co")!, encoding: String.Encoding.utf8)) ?? ""
        if pkgDescr.hasPrefix("<!DOCTYPE") { // 404 File Not Found
            itemName = itemName.lowercased()
            pkgDescr = (try? String(contentsOfURL: URL(string: "http://svnweb.freebsd.org/ports/head/\(category)/\(item.name)/pkg-descr?view=co")!, encoding: String.Encoding.utf8)) ?? ""
        }
        if pkgDescr.hasPrefix("<!DOCTYPE") { // 404 File Not Found
            pkgDescr = "[Info not reachable]"
        }
        return pkgDescr
    }


    override func home(_ item: GItem) -> String {
        if item.homepage != nil { // already available from INDEX
            return item.homepage
        } else {
            let pkgDescr = self.info(item)
            if pkgDescr != "[Info not reachable]" {
                for line in Array(pkgDescr.split("\n").reversed()) {
                    let idx = line.index("WWW:")
                    if idx != NSNotFound {
                        return line.substringFromIndex(idx + 4).trim()
                    }
                }
            }
        }
        return self.log(item) // TODO
    }

    override func log(_ item: GItem) -> String {
        let category = item.categories!.split()[0]
        return "http://www.freshports.org/\(category)/\(item.name)"
    }

    override func contents(_ item: GItem) -> String {
        let category = item.categories!.split()[0]
        var itemName = item.name
        var pkgPlist = (try? String(contentsOfURL: URL(string: "http://svnweb.freebsd.org/ports/head/\(category)/\(item.name)/pkg-plist?view=co")!, encoding: String.Encoding.utf8)) ?? ""
        if pkgPlist.hasPrefix("<!DOCTYPE") { // 404 File Not Found
            itemName = itemName.lowercased()
            pkgPlist = (try? String(contentsOfURL: URL(string: "http://svnweb.freebsd.org/ports/head/\(category)/\(item.name)/pkg-plist?view=co")!, encoding: String.Encoding.utf8)) ?? ""
        }
        if pkgPlist.hasPrefix("<!DOCTYPE") { // 404 File Not Found
            pkgPlist = ""
        }
        return pkgPlist
    }

    override func cat(_ item: GItem) -> String {
        let category = item.categories!.split()[0]
        var itemName = item.name
        var makefile = (try? String(contentsOfURL: URL(string: "http://svnweb.freebsd.org/ports/head/\(category)/\(item.name)/Makefile?view=co")!, encoding: String.Encoding.utf8)) ?? ""
        if makefile.hasPrefix("<!DOCTYPE") { // 404 File Not Found
            itemName = itemName.lowercased()
            makefile = (try? String(contentsOfURL: URL(string: "http://svnweb.freebsd.org/ports/head/\(category)/\(item.name)/Makefile?view=co")!, encoding: String.Encoding.utf8)) ?? ""
        }
        if makefile.hasPrefix("<!DOCTYPE") { // 404 File Not Found
            makefile = "[Makefile not reachable]"
        }
        return makefile
    }

    // TODO: deps => parse requirements:
    // http://www.FreeBSD.org/cgi/ports.cgi?query=%5E' + '%@-%@' item.name-item.version

}
