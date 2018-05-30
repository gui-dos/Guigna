import Foundation

final class Pkgsrc: GSystem {

    override class var prefix: String { return  "/usr/pkg" }

    init(agent: GAgent) {
        super.init(name: "pkgsrc", agent: agent)
        homepage = "http://www.pkgsrc.org"
        logpage = "http://www.netbsd.org/changes/pkg-changes.html"
        cmd = "\(prefix)/sbin/pkg_info"
    }

    // include category for managing duplicates of xp, binutils, fuse, p5-Net-CUPS
    override func key(package pkg: GPackage) -> String {
        if pkg.id != nil {
            return "\(pkg.id)-\(name)"
        } else {
            return "\(pkg.categories!.split()[0])/\(pkg.name)-\(name)"
        }
    }

    @discardableResult
    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        let indexPath = ("~/Library/Application Support/Guigna/pkgsrc/INDEX" as NSString).expandingTildeInPath
        if indexPath.exists {
            let lines = (try! String(contentsOfFile: indexPath, encoding: .utf8)).split("\n")
            for line in lines {
                let components = line.split("|")
                var name = components[0]
                var idx = name.rindex("-")
                if idx == NSNotFound {
                    continue
                }
                let version = name.substring(from: idx + 1)
                // name = [name substringToIndex:idx];
                let id = components[1]
                idx = id.rindex("/")
                name = id.substring(from: idx + 1)
                let description = components[3]
                let category = components[6]
                let homepage = components[11]
                let pkg = GPackage(name: name, version: version, system: self)
                pkg.id = id
                pkg.categories = category
                pkg.description = description
                pkg.homepage = homepage
                items.append(pkg)
                self[id] = pkg
            }

        } else {
            let url = URL(string: "http://ftp.netbsd.org/pub/pkgsrc/current/pkgsrc/README-all.html")!
            if let xmlDoc = try? XMLDocument(contentsOf: url, options: .documentTidyHTML) {
                let nodes = xmlDoc.rootElement()!["//tr"]
                for node in nodes {
                    let rowData = node["td"]
                    if rowData.count == 0 {
                        continue
                    }
                    var name = rowData[0].stringValue!
                    var idx = name.rindex("-")
                    if idx == NSNotFound {
                        continue
                    }
                    let version = name.substring(idx + 1, name.length - idx - 3)
                    name = name.substring(to: idx)
                    var category = rowData[1].stringValue!
                    category = category.substring(1, category.length - 3)
                    var description = rowData[2].stringValue!
                    idx = description.rindex("  ")
                    if idx != NSNotFound {
                        description = description.substring(to: idx)
                    }
                    let pkg = GPackage(name: name, version: version, system: self)
                    pkg.categories = category
                    pkg.description = description
                    let id = "\(category)/\(name)"
                    pkg.id = id
                    items.append(pkg)
                    self[id] = pkg
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
        var outputLines = output(cmd).split("\n")
        outputLines.removeLast()
        var ids = output("\(cmd) -Q PKGPATH -a").split("\n")
        ids.removeLast()
        let whitespaceCharacterSet = CharacterSet.whitespaces
        var i = 0
        for line in outputLines {
            var idx = line.index(" ")
            var name = line.substring(to: idx)
            let description = line.substring(from: idx + 1).trim(whitespaceCharacterSet)
            idx = name.rindex("-")
            let version = name.substring(from: idx + 1)
            // name = [name substringToIndex:idx];
            let id = ids[i]
            idx = id.index("/")
            name = id.substring(from: idx + 1)
            status = .upToDate
            var pkg: GPackage! = self[id]
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
        if self.isHidden {
            return super.info(item)
        }
        if mode != .offline && item.status != .available {
            return output("\(cmd) \(item.name)")
        } else {
            if item.id != nil {
                return (try? String(contentsOf: URL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.id!)/DESCR")!, encoding: .utf8)) ?? ""
            } else { // TODO lowercase (i.e. Hermes -> hermes)
                return (try? String(contentsOf: URL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.categories!)/\(item.name)/DESCR")!, encoding: .utf8)) ?? ""
            }
        }
    }


    override func home(_ item: GItem) -> String {
        if item.homepage != nil { // already available from INDEX
            return item.homepage
        } else {
            let links = agent.nodes(URL: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.categories!)/\(item.name)/README.html", XPath: "//p/a")
            return links[2].href
        }
    }

    override func log(_ item: GItem) -> String {
        if item.id != nil {
            return "http://cvsweb.NetBSD.org/bsdweb.cgi/pkgsrc/\(item.id!)/"
        } else {
            return "http://cvsweb.NetBSD.org/bsdweb.cgi/pkgsrc/\(item.categories!)/\(item.name)/"
        }
    }

    override func contents(_ item: GItem) -> String {
        if item.status != .available {
            return output("\(cmd) -L \(item.name)").split("Files:\n")[1]
        } else {
            if item.id != nil {
                return (try? String(contentsOf: URL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.id!)/PLIST")!, encoding: .utf8)) ?? ""
            } else { // TODO lowercase (i.e. Hermes -> hermes)
                return (try? String(contentsOf: URL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.categories!)/\(item.name)/PLIST")!, encoding: .utf8)) ?? ""
            }
        }
    }

    override func cat(_ item: GItem) -> String {
        if item.status != .available {
            let filtered = items.filter { $0.name == item.name }
            item.id = filtered[0].id
        }
        if item.id != nil {
            return (try? String(contentsOf: URL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.id!)/Makefile")!, encoding: .utf8)) ?? ""
        } else { // TODO lowercase (i.e. Hermes -> hermes)
            return (try? String(contentsOf: URL(string: "http://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc/\(item.categories!)/\(item.name)/Makefile")!, encoding: .utf8)) ?? ""
        }
    }

    // TODO: Deps: pkg_info -n -r, scrape site, parse Index

    override func deps(_ item: GItem) -> String { // FIXME: "*** PACKAGE MAY NOT BE DELETED *** "

        if item.status != .available {
            let components = output("\(cmd) -n \(item.name)").split("Requires:\n")
            if components.count > 1 {
                return components[1].trim()
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

    override func dependents(_ item: GItem) -> String {
        if item.status != .available {
            let components = output("\(cmd) -r \(item.name)").split("required by list:\n")
            if components.count > 1 {
                return components[1].trim()
            } else {
                return "[No dependents]"
            }
        } else {
            return "[Not available]"
        }
    }

    override func installCmd(_ pkg: GPackage) -> String {
        if pkg.id != nil {
            return "cd /usr/pkgsrc/\(pkg.id); sudo /usr/pkg/bin/bmake install clean clean-depends"
        } else {
            return "cd /usr/pkgsrc/\(pkg.categories!)/\(pkg.name); sudo /usr/pkg/bin/bmake install clean clean-depends"
        }
    }

    override func uninstallCmd(_ pkg: GPackage) -> String {
        return "sudo \(prefix)/sbin/pkg_delete \(pkg.name)"
    }


    override func cleanCmd(_ pkg: GPackage) -> String {
        if pkg.id != nil {
            return "cd /usr/pkgsrc/\(pkg.id); sudo /usr/pkg/bin/bmake clean clean-depends"
        } else {
            return "cd /usr/pkgsrc/\(pkg.categories!)/\(pkg.name); sudo /usr/pkg/bin/bmake clean clean-depends"
        }
    }

    override var updateCmd: String! {
        get {
            if mode == .online || (defaults("pkgsrcCVS") as? Bool ?? false) == false {
                return nil
            } else {
                return "sudo cd; cd /usr/pkgsrc; sudo cvs update -dP"
            }
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
        return "for dir in bin etc include lib opt share; do sudo mv /usr/local/\"$dir\"{,_off}; done; sudo mv /opt/local /opt/local_off; sudo mv /sw /sw_off; cd ~/Library/Application\\ Support/Guigna/pkgsrc; curl -L -O ftp://ftp.NetBSD.org/pub/pkgsrc/current/pkgsrc.tar.gz; sudo tar -xvzf pkgsrc.tar.gz -C /usr; cd /usr/pkgsrc/bootstrap; sudo ./bootstrap --compiler clang; for dir in bin etc include lib opt share; do sudo mv /usr/local/\"$dir\"{_off,}; done; sudo mv /opt/local_off /opt/local; sudo mv /sw_off /sw"
    }

    class var removeCmd: String! {
        return "sudo rm -r /usr/pkg; sudo rm -r /usr/pkgsrc; sudo rm -r /var/db/pkg"
    }
}
