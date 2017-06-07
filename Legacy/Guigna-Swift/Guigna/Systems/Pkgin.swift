import Foundation

final class Pkgin: GSystem {

    // TODO: complete porting from Pkgsrc
    // TODO: Objective-C version

    override class var prefix: String { return "/opt/pkg" }

    init(agent: GAgent) {
        super.init(name: "pkgin", agent: agent)
        homepage = "https://pkgsrc.joyent.com"
        logpage = "https://github.com/joyent/pkgsrc/commits/trunk"
        cmd = "\(prefix)/bin/pkgin"
    }

    var pkgsrcCmd: String {
        return "\(prefix)/sbin/pkg_info"
    }

    func firstCategoryOf(_ item: GItem) -> String {
        if !item.id.hasPrefix("[multiple]/") {
            return item.id.split("/")[0]
        } else {
            return output("\(cmd) show-pkg-category \(item.name)").split(" - ")[0].trim().split()[0]
        }
    }

    // include category for managing duplicates of xp, binutils, fuse, p5-Net-CUPS
    override func key(package pkg: GPackage) -> String {
        if pkg.id != nil {
            return "\(pkg.id!)-\(name)"
        } else {
            return "\(firstCategoryOf(pkg))/\(pkg.name)-\(name)"
        }
    }

    @discardableResult
    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        // from Pkgsrc:
        //
        //        let indexPath = ("~/Library/Application Support/Guigna/pkgsrc/INDEX" as NSString).stringByExpandingTildeInPath
        //        if indexPath.exists {
        //            let lines = (try! String(contentsOfFile: indexPath, encoding: NSUTF8StringEncoding)).split("\n")
        //            for line in lines {
        //                let components = line.split("|")
        //                var name = components[0]
        //                var idx = name.rindex("-")
        //                if idx == NSNotFound {
        //                    continue
        //                }
        //                let version = name.substring(from: idx + 1)
        //                // name = [name substringToIndex:idx];
        //                let id = components[1]
        //                idx = id.rindex("/")
        //                name = id.substring(from: idx + 1)
        //                let description = components[3]
        //                let category = components[6]
        //                let homepage = components[11]
        //                let pkg = GPackage(name: name, version: version, system: self, status: .Available)
        //                pkg.id = id
        //                pkg.categories = category
        //                pkg.description = description
        //                pkg.homepage = homepage
        //                items.append(pkg)
        //                self[id] = pkg
        //            }
        //
        //        } else {
        //            let url = NSURL(string: "http://ftp.netbsd.org/pub/pkgsrc/current/pkgsrc/README-all.html")!
        //            if let xmlDoc = try? NSXMLDocument(contentsOf: url, options: .documentTidyHTML) {
        //                let nodes = xmlDoc.rootElement()!["//tr"]
        //                for node in nodes {
        //                    let rowData = node["td"]
        //                    if rowData.count == 0 {
        //                        continue
        //                    }
        //                    var name = rowData[0].stringValue!
        //                    var idx = name.rindex("-")
        //                    if idx == NSNotFound {
        //                        continue
        //                    }
        //                    let version = name.substring(idx + 1, name.length - idx - 3)
        //                    name = name.substring(to: idx)
        //                    var category = rowData[1].stringValue!
        //                    category = category.substring(1, category.length - 3)
        //                    var description = rowData[2].stringValue!
        //                    idx = description.rindex("  ")
        //                    if idx != NSNotFound {
        //                        description = description.substring(to: idx)
        //                    }
        //                    let pkg = GPackage(name: name, version: version, system: self, status: .Available)
        //                    pkg.categories = category
        //                    pkg.description = description
        //                    let id = "\(category)/\(name)"
        //                    pkg.id = id
        //                    items.append(pkg)
        //                    self[id] = pkg
        //                }
        //            }
        //        }

        let whitespaceCharacterSet = CharacterSet.whitespaces
        
        var lines = output("\(cmd) avail").split("\n")
        lines.removeLast()
        for line in lines {
            var idx = line.index(" ")
            var name = line.substring(to: idx)
            let description = line.substring(from: idx + 1).trim(whitespaceCharacterSet)
            idx = name.rindex("-")
            let version = name.substring(from: idx + 1)
            name = name.substring(to: idx)
            let pkg = GPackage(name: name, version: version, system: self, status: .available)
            let category = "[multiple]"
            pkg.categories = category
            pkg.description = description
            let id = "\(category)/\(name)"
            pkg.id = id
            items.append(pkg)
            self[id] = pkg
        }

        var categories = output("\(cmd) show-all-categories").split("\n")
        categories.removeLast()
        for category in categories {
            var outputLines = output("\(cmd) show-category \(category)").split("\n")
            outputLines.removeLast()
            for line in outputLines {
                var idx = line.index(" ")
                var name = line.substring(to: idx)
                idx = name.rindex("-")
                name = name.substring(to: idx)
                let id = "\(category)/\(name)"
                if let pkg = self["[multiple]/\(name)"] { // the same item in the same category could have been categorized already
                    self[id] = pkg
                    self["[multiple]/\(name)"] = nil
                }
                if self[id] != nil { // ignore a second item in a different category already categorized
                    self[id].id = id
                    self[id].categories = category
                }
            }
        }

        self.installed() // update status
        return items as! [GPackage]
    }

    // TODO: outdated()

    @discardableResult
    override func installed() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status != .available} as! [GPackage]
        }
        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .online {
            return pkgs
        }

        var status: GStatus
        for pkg in items as! [GPackage] {
            status = pkg.status
            pkg.installed = nil
            if status != .updated && status != .new {
                pkg.status = .available
            }
        }
        // [self outdated]; // index outdated ports // TODO
        var outputLines = output("/bin/sh -c \(cmd)__list__|__sort__-f").split("\n")
        outputLines.removeLast()
        var ids = output("\(pkgsrcCmd) -Q PKGPATH -a").split("\n")
        ids.removeLast()
        let whitespaceCharacterSet = CharacterSet.whitespaces
        var i = 0
        for line in outputLines {
            var idx = line.index(" ")
            var name = line.substring(to: idx)
            let description = line.substring(from: idx + 1).trim(whitespaceCharacterSet)
            idx = name.rindex("-")
            let version = name.substring(from: idx + 1)
            // name = name.substring(to: idx)
            var id = ids[i]
            idx = id.index("/")
            name = id.substring(from: idx + 1)
            status = .upToDate
            var pkg: GPackage! = self[id]
            if pkg == nil {
                id = "[multiple]/\(name)"
                pkg = self[id]
            }
            let latestVersion: String = (pkg == nil) ? "" : pkg.version
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: status)
                self[id] = pkg
            } else {
                if pkg.status == .available {
                    pkg.status = .upToDate
                }
            }
            pkg.installed = version
            pkg.description = description
            pkg.id = id
            pkgs.append(pkg)
            i += 1
        }
        return pkgs
    }

    // TODO: pkg_info -d

    // TODO: pkg_info -B PKGPATH=misc/figlet

    override func info(_ item: GItem) -> String {
        //        if self.isHidden {
        //            return super.info(item)
        //        }
        //        if mode != .Offline && item.status != .Available {
        //            return output("\(cmd) \(item.name)")
        //        } else {
        //            if item.id != nil {
        //                return (try? String(contentsOf: NSURL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.id!)/DESCR")!, encoding: NSUTF8StringEncoding)) ?? ""
        //            } else { // TODO lowercase (i.e. Hermes -> hermes)
        //                return (try? String(contentsOf: NSURL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.categories!)/\(item.name)/DESCR")!, encoding: NSUTF8StringEncoding)) ?? ""
        //            }
        //        }
        return output("\(cmd) pkg-descr \(item.name)")
    }


    override func home(_ item: GItem) -> String {
        if item.homepage != nil {
            return item.homepage
        } else {
            let links = agent.nodes(URL: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(firstCategoryOf(item))/\(item.name)/README.html", XPath: "//p/a")
            return links[2].href
        }
    }

    override func log(_ item: GItem) -> String {
        return "https://github.com/joyent/pkgsrc/commits/trunk/\(firstCategoryOf(item))/\(item.name)"
    }

    // TODO: use specific pkgin commands
    override func contents(_ item: GItem) -> String {
        return output("\(cmd) pkg-contents \(item.name)")

    }

    override func cat(_ item: GItem) -> String {
        return (try? String(contentsOf: URL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(firstCategoryOf(item))/\(item.name)/Makefile")!, encoding: .utf8)) ?? ""
        // TODO: output("\(cmd) pkg-build-defs \(item.name)")

    }

    override func deps(_ item: GItem) -> String {
        var outputLines = output("\(cmd) show-full-deps \(item.name)").split("\n")
        outputLines.removeFirst()
        return outputLines.map{ $0.trim().replace(">=", " >= ") }.join("\n")
    }

    override func dependents(_ item: GItem) -> String {
        var outputLines = output("\(cmd) show-rev-deps \(item.name)").split("\n")
        outputLines.removeFirst()
        return outputLines.map{ $0.trim() }.join("\n")
    }

    override func installCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) -y install \(pkg.name)"
    }

    override func uninstallCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) -y remove \(pkg.name)"
    }

    // TODO:
    override func upgradeCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) -y upgrade"
        // return "sudo \(cmd) -y remove \(pkg.name); sudo \(cmd) -y install \(pkg.name)"

    }

    override func cleanCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) clean \(pkg.name)"

    }

    override var updateCmd: String! {
        get {
            //            if mode == .Online || (defaults("pkgsrcCVS") as? Bool ?? false) == false {
            //                return nil
            //            } else {
            //                return "sudo cd; cd /usr/pkgsrc; sudo cvs update -dP"
            //            }
            return "sudo \(cmd) -y update"
        }
    }

    override var hideCmd: String! {
        get {
            return "sudo mv \(prefix) \(prefix)_off"}
    }

    override var unhideCmd: String! {
        get {
            return "sudo mv \(prefix)_off \(prefix)"}
    }


    class var setupCmd: String! {
        return "for dir in bin etc include lib opt share; do sudo mv /usr/local/\"$dir\"{,_off}; done; sudo mv /opt/local /opt/local_off; sudo mv /sw /sw_off; cd ~/Library/Application\\ Support/Guigna/pkgsrc; git clone git://github.com/cmacrae/saveosx.git; cd saveosx; ./bootstrap; for dir in bin etc include lib opt share; do sudo mv /usr/local/\"$dir\"{_off,}; done; sudo mv /opt/local_off /opt/local; sudo mv /sw_off /sw"
    }
    
    class var removeCmd: String! {
        return "sudo rm -r /opt/pkg; sudo rm -r /var/db/pkgin"
    }
}
