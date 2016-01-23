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

    // include category for managing duplicates of xp, binutils, fuse, p5-Net-CUPS
    override func key(package pkg: GPackage) -> String {
        if pkg.id != nil {
            return "\(pkg.id)-\(name)"
        } else {
            return "\(pkg.categories!.split()[0])/\(pkg.name)-\(name)"
        }
    }

    override func list() -> [GPackage] {

        index.removeAll(keepCapacity: true)
        items.removeAll(keepCapacity: true)

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
        //                let version = name.substringFromIndex(idx + 1)
        //                // name = [name substringToIndex:idx];
        //                let id = components[1]
        //                idx = id.rindex("/")
        //                name = id.substringFromIndex(idx + 1)
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
        //            if let xmlDoc = try? NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML)) {
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
        //                    name = name.substringToIndex(idx)
        //                    var category = rowData[1].stringValue!
        //                    category = category.substring(1, category.length - 3)
        //                    var description = rowData[2].stringValue!
        //                    idx = description.rindex("  ")
        //                    if idx != NSNotFound {
        //                        description = description.substringToIndex(idx)
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

        var categories = output("\(cmd) show-all-categories").split("\n")
        categories.removeLast()
        for category in categories {
            var outputLines = output("\(cmd) show-category \(category)").split("\n")
            outputLines.removeLast()

            // duplicate from installed():
            // TODO: categories / ids

            let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
            for line in outputLines {
                var idx = line.index(" ")
                var name = line.substringToIndex(idx)
                let description = line.substringFromIndex(idx + 1).stringByTrimmingCharactersInSet(whitespaceCharacterSet)
                idx = name.rindex("-")
                let version = name.substringFromIndex(idx + 1)
                name = name.substringToIndex(idx)
                // let id = ids[i]
                // idx = id.index("/")
                // name = id.substringFromIndex(idx + 1)
                let pkg = GPackage(name: name, version: version, system: self, status: .Available)
                pkg.categories = category
                pkg.description = description
                let id = "\(category)/\(name)"
                pkg.id = id
                items.append(pkg)
                self[id] = pkg
                // i++
            }
        }

        self.installed() // update status
        return items as! [GPackage]
    }

    // TODO: outdated()
    override func installed() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status != .Available} as! [GPackage]
        }
        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .Online {
            return pkgs
        }

        var status: GStatus
        for pkg in items as! [GPackage] {
            status = pkg.status
            pkg.installed = nil
            if status != .Updated && status != .New {
                pkg.status = .Available
            }
        }
        // [self outdated]; // index outdated ports // TODO
        var outputLines = output("\(cmd) list").split("\n")
        outputLines.removeLast()
        var ids = output("\(pkgsrcCmd) -Q PKGPATH -a").split("\n")
        ids.removeLast()
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        var i = 0
        for line in outputLines {
            var idx = line.index(" ")
            var name = line.substringToIndex(idx)
            let description = line.substringFromIndex(idx + 1).stringByTrimmingCharactersInSet(whitespaceCharacterSet)
            idx = name.rindex("-")
            let version = name.substringFromIndex(idx + 1)
            // name = name.substringToIndex(idx)
            let id = ids[i]
            idx = id.index("/")
            name = id.substringFromIndex(idx + 1)
            status = .UpToDate
            var pkg: GPackage! = self[id]
            let latestVersion: String = (pkg == nil) ? "" : pkg.version
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: status)
                self[id] = pkg
            } else {
                if pkg.status == .Available {
                    pkg.status = .UpToDate
                }
            }
            pkg.installed = version
            pkg.description = description
            pkg.id = id
            pkgs.append(pkg)
            i++
        }
        return pkgs
    }

    // TODO: pkg_info -d

    // TODO: pkg_info -B PKGPATH=misc/figlet

    override func info(item: GItem) -> String {
        //        if self.isHidden {
        //            return super.info(item)
        //        }
        //        if mode != .Offline && item.status != .Available {
        //            return output("\(cmd) \(item.name)")
        //        } else {
        //            if item.id != nil {
        //                return (try? String(contentsOfURL: NSURL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.id)/DESCR")!, encoding: NSUTF8StringEncoding)) ?? ""
        //            } else { // TODO lowercase (i.e. Hermes -> hermes)
        //                return (try? String(contentsOfURL: NSURL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.categories)/\(item.name)/DESCR")!, encoding: NSUTF8StringEncoding)) ?? ""
        //            }
        //        }
        return output("\(cmd) pkg-descr \(item.name)")
    }


    override func home(item: GItem) -> String {
        if item.homepage != nil { // already available from INDEX
            return item.homepage
        } else {
            let links = agent.nodes(URL: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.categories)/\(item.name)/README.html", XPath: "//p/a")
            return links[2].href
        }
    }

    override func log(item: GItem) -> String {
        if item.id != nil {
            return "http://cvsweb.NetBSD.org/bsdweb.cgi/pkgsrc/\(item.id)/"
        } else {
            return "http://cvsweb.NetBSD.org/bsdweb.cgi/pkgsrc/\(item.categories)/\(item.name)/"
        }
    }

    override func contents(item: GItem) -> String {
        if item.status != .Available {
            return output("\(cmd) -L \(item.name)").split("Files:\n")[1]
        } else {
            if item.id != nil {
                return (try? String(contentsOfURL: NSURL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.id)/PLIST")!, encoding: NSUTF8StringEncoding)) ?? ""
            } else { // TODO lowercase (i.e. Hermes -> hermes)
                return (try? String(contentsOfURL: NSURL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.categories)/\(item.name)/PLIST")!, encoding: NSUTF8StringEncoding)) ?? ""
            }
        }
    }

    override func cat(item: GItem) -> String {
        if item.status != .Available {
            let filtered = items.filter { $0.name == item.name }
            item.id = filtered[0].id
        }
        if item.id != nil {
            return (try? String(contentsOfURL: NSURL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.id)/Makefile")!, encoding: NSUTF8StringEncoding)) ?? ""
        } else { // TODO lowercase (i.e. Hermes -> hermes)
            return (try? String(contentsOfURL: NSURL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.categories)/\(item.name)/Makefile")!, encoding: NSUTF8StringEncoding)) ?? ""
        }
    }

    // TODO: Deps: pkg_info -n -r, scrape site, parse Index

    override func deps(item: GItem) -> String { // FIXME: "*** PACKAGE MAY NOT BE DELETED *** "

        if item.status != .Available {
            let components = output("\(cmd) -n \(item.name)").split("Requires:\n")
            if components.count > 1 {
                return components[1].stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            } else {
                return "[No depends]"
            }
        } else {
            if "~/Library/Application Support/Guigna/pkgsrc/INDEX".exists {
                // TODO: parse INDEX
                // NSArray *lines = [NSString stringWithContentsOfFile:[@"~/Library/Application Support/Guigna/pkgsrc/INDEX" stringByExpandingTildeInPath] encoding:NSUTF8StringEncoding error:nil];
            }
            return "[Not available]"
        }
    }

    override func dependents(item: GItem) -> String {
        if item.status != .Available {
            let components = output("\(cmd) -r \(item.name)").split("required by list:\n")
            if components.count > 1 {
                return components[1].stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
            } else {
                return "[No dependents]"
            }
        } else {
            return "[Not available]"
        }
    }

    override func installCmd(pkg: GPackage) -> String {
        //        if pkg.id != nil {
        //            return "cd /usr/pkgsrc/\(pkg.id) ; sudo /usr/pkg/bin/bmake install clean clean-depends"
        //        } else {
        //            return "cd /usr/pkgsrc/\(pkg.categories)/\(pkg.name) ; sudo /usr/pkg/bin/bmake install clean clean-depends"
        //        }
        return "sudo \(cmd) -y install \(pkg.name)"
    }

    override func uninstallCmd(pkg: GPackage) -> String {
        //        return "sudo \(prefix)/sbin/pkg_delete \(pkg.name)"
        return "sudo \(cmd) -y remove \(pkg.name)"
    }


    override func cleanCmd(pkg: GPackage) -> String {
        if pkg.id != nil {
            return "cd /usr/pkgsrc/\(pkg.id) ; sudo /usr/pkg/bin/bmake clean clean-depends"
        } else {
            return "cd /usr/pkgsrc/\(pkg.categories)/\(pkg.name) ; sudo /usr/pkg/bin/bmake clean clean-depends"
        }
    }

    override var updateCmd: String! {
        get {
            //            if mode == .Online || (defaults("pkgsrcCVS") as? Bool ?? false) == false {
            //                return nil
            //            } else {
            //                return "sudo cd; cd /usr/pkgsrc ; sudo cvs update -dP"
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
        return "for dir in bin etc include lib opt share ; do sudo mv /usr/local/\"$dir\"{,_off} ; done ; sudo mv /opt/local /opt/local_off ; sudo mv /sw /sw_off ; cd ~/Library/Application\\ Support/Guigna/pkgsrc ; git clone git://github.com/cmacrae/saveosx.git ; cd saveosx ; ./bootstrap ; for dir in bin etc include lib opt share ; do sudo mv /usr/local/\"$dir\"{_off,} ; done ; sudo mv /opt/local_off /opt/local ; sudo mv /sw_off /sw"
    }
    
    class var removeCmd: String! {
        return "sudo rm -r /opt/pkg ; sudo rm -r /var/db/pkgin"
    }
}
