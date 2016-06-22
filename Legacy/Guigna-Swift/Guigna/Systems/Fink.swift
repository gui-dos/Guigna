import Foundation

final class Fink: GSystem {

    override class var prefix: String { return "/sw" }

    init(agent: GAgent) {
        super.init(name: "Fink", agent: agent)
        homepage = "http://www.finkproject.org"
        logpage = "http://www.finkproject.org/package-updates.php"
        // @"http://github.com/fink/fink/commits/master"
        cmd = "\(prefix)/bin/fink"
    }

    @discardableResult
    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        if mode == .online {
            let url = URL(string: "http://pdb.finkproject.org/pdb/browse.php")!
            if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
                let nodes = xmlDoc.rootElement()!["//tr[@class=\"package\"]"]
                for node in nodes {
                    let dataRows = node["td"]
                    let description = dataRows[2].stringValue!
                    if description.hasPrefix("[virtual") {
                        continue
                    }
                    let name = dataRows[0].stringValue!
                    let version = dataRows[1].stringValue!
                    let pkg = GPackage(name: name, version: version, system: self, status: .available)
                    pkg.description = description
                    items.append(pkg)
                    self[name] = pkg
                }
            }
        } else {
            var outputLines = output("\(cmd) list --tab").split("\n")
            outputLines.removeLast()
            let whitespaceCharacterSet = CharacterSet.whitespaces
            var status: GStatus
            for line in outputLines {
                let components = line.split("\t")
                let description = components[3]
                if description.hasPrefix("[virtual") {
                    continue
                }
                let name = components[1]
                let version = components[2]
                let state = components[0].trim(whitespaceCharacterSet)
                status = .available
                if state == "i" || state == "p" {
                    status = .upToDate
                } else if state == "(i)" {
                    status = .outdated
                }
                let pkg = GPackage(name: name, version: version, system: self, status: status)
                pkg.description = description
                items.append(pkg)
                self[name] = pkg
            }
        }
        self.installed() // update status
        return items as! [GPackage]
    }


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
            if status != .updated && status != .new { // TODO: !pkg.description.hasPrefix("[virtual")
                pkg.status = .available
            }
        }
        var outputLines = output("\(prefix)/bin/dpkg-query --show").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.split("\t")
            let name = components[0]
            let version = components[1]
            status = .upToDate
            var pkg: GPackage! = self[name]
            let latestVersion: String = (pkg == nil) ? "" : pkg.version
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: status)
                self[name] = pkg
            } else {
                if pkg.status == .available {
                    pkg.status = .upToDate
                }
            }
            pkg.installed = version
            pkgs.append(pkg)
        }
        return pkgs
    }

    
    @discardableResult
    override func outdated() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status == .outdated} as! [GPackage]
        }
        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .online {
            return pkgs
        }

        var outputLines = output("\(cmd) list --outdated --tab").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.split("\t")
            let name = components[1]
            // TODO: sync with Objective-C version
            // let version = components[2]
            let description = components[3]
            var pkg: GPackage! = self[name]
            let latestVersion: String = (pkg == nil) ? "" : pkg.version
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: .outdated)
                self[name] = pkg
            } else {
                pkg.status = .outdated
            }
            pkg.description = description
            pkgs.append(pkg)
        }
        return pkgs
    }

    // TODO: pkg_info -d

    // TODO: pkg_info -B PKGPATH=misc/figlet

    override func info(_ item: GItem) -> String {
        if self.isHidden {
            return super.info(item)
        }
        if mode == .online {
            let nodes = agent.nodes(URL: "http://pdb.finkproject.org/pdb/package.php/\(item.name)", XPath: "//div[@class=\"desc\"]")
            if nodes.count == 0 {
                return "[Info not available]"
            } else {
                return nodes[0].stringValue!
            }
        } else {
            return output("\(cmd) dumpinfo \(item.name)")
        }

    }


    override func home(_ item: GItem) -> String {
        let nodes = agent.nodes(URL: "http://pdb.finkproject.org/pdb/package.php/\(item.name)", XPath: "//a[contains(@title, \"home\")]")
        if nodes.count == 0 {
            return "[Homepage not available]"
        } else {
            return nodes[0].stringValue!
        }
    }

    override func log(_ item: GItem) -> String {
        return "http://pdb.finkproject.org/pdb/package.php/\(item.name)"
        // @"http://github.com/fink/fink/commits/master"
    }

    override func contents(_ item: GItem) -> String {
        return ""
    }

    override func cat(_ item: GItem) -> String {
        if item.status != .available || mode == .online {
            let nodes = agent.nodes(URL: "http://pdb.finkproject.org/pdb/package.php/\(item.name)", XPath: "//a[contains(@title, \"info\")]")
            if nodes.count == 0 {
                return "[.info not reachable]"
            } else {
                let cvs = nodes[0].stringValue!
                let info = (try? String(contentsOf: URL(string: "http://fink.cvs.sourceforge.net/fink/\(cvs)")!, encoding: .utf8)) ?? ""
                return info
            }
        } else {
            return output("\(cmd) dumpinfo \(item.name)")
        }
    }


    // TODO: Deps

    override func installCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) install \(pkg.name)"

    }

    override func uninstallCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) remove \(pkg.name)"
    }

    override func upgradeCmd(_ pkg: GPackage) -> String {
        return "sudo \(cmd) update \(pkg.name)"
    }


    override var updateCmd: String! {
        get {
            if mode == .online {
                return nil
            } else {
                return "sudo \(cmd) selfupdate"
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
        return "for dir in bin etc include lib opt share ; do sudo mv /usr/local/\"$dir\"{,_off} ; done ; sudo mv /opt/local /opt/local_off ; sudo mv /usr/pkg /usr/pkg_off ; cd ~/Library/Application\\ Support/Guigna/Fink ; curl -L -O http://downloads.sourceforge.net/fink/fink-0.39.3.tar.gz ; tar -xvzf fink-0.39.3.tar.gz ; cd fink-0.39.3 ; sudo ./bootstrap ; /sw/bin/pathsetup.sh ; . /sw/bin/init.sh ; /sw/bin/fink selfupdate-rsync ; /sw/bin/fink index -f ; for dir in bin etc include lib opt share ; do sudo mv /usr/local/\"$dir\"{_off,} ; done ; sudo mv /opt/local_off /opt/local ; sudo mv /usr/pkg_off /usr/pkg"
    }

    class var removeCmd: String! {
        return "sudo rm -rf /sw"
    }

    override func verbosifiedCmd(_ command: String) -> String {
        return cmd.replace(cmd, "\(cmd) -v")
    }
}
