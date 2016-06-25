import Foundation

final class MacOSX: GSystem {

    override class var prefix: String { return "" }

    init(agent: GAgent) {
        super.init(name: "Mac OS X", agent: agent)
        homepage = "http://support.apple.com/downloads/"
        logpage = "http://support.apple.com/downloads/"
        cmd = "/usr/sbin/pkgutil"
    }

    @discardableResult
    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        items = installed()
        return items as! [GPackage]
    }


    @discardableResult
    override func installed() -> [GPackage] {

        var pkgs = [GPackage]()
        pkgs.reserveCapacity(1000)

        var pkgIds = output("/usr/sbin/pkgutil --pkgs").split("\n")
        pkgIds.removeLast()

        let history = Array(((NSArray(contentsOfFile: "/Library/Receipts/InstallHistory.plist") as? [AnyObject]) ?? []).reversed())
        var keepPkg: Bool
        for dict in history as! [NSDictionary] {
            keepPkg = false
            var ids = dict["packageIdentifiers"]! as! [String]
            for pkgId in ids {
                if let idx = pkgIds.index(of: pkgId) {
                    keepPkg = true
                    pkgIds.remove(at: idx)
                }
            }
            if !keepPkg {
                continue
            }
            let name = dict["displayName"]! as! String
            var version = dict["displayVersion"]! as! String
            var category = dict["processName"]! as! String
            category = category.replace(" ", "").lowercased()
            if category == "installer" {
                let infoOutput = output("/usr/sbin/pkgutil --pkg-info-plist \(ids[0])")
                if infoOutput != "" {
                    let plist = infoOutput.propertyList() as! NSDictionary
                    version = plist["pkg-version"]! as! String
                }
            }
            let pkg = GPackage(name: name, version: "", system: self, status: .upToDate)
            pkg.id = ids.join()
            pkg.categories = category
            pkg.description = pkg.id
            pkg.installed = version
            // TODO: pkg.version
            pkgs.append(pkg)
        }
        //    for pkg in installed() {
        //        index[pkg key].status = pkg.status
        //    }
        return pkgs
    }

    @discardableResult
    override func outdated() -> [GPackage] {
        let pkgs = [GPackage]()
        // TODO: sudo /usr/sbin/softwareupdate --list
        return pkgs
    }


    override func inactive() -> [GPackage] {
        let pkgs = [GPackage]()
        return pkgs
    }


    override func info(_ item: GItem) -> String {
        var info = ""
        for pkgId in item.id!.split() {
            info += output("/usr/sbin/pkgutil --pkg-info \(pkgId)")
            info += "\n"
        }
        return info
    }

    override func home(_ item: GItem) -> String {
        var homepage = "http://support.apple.com/downloads/"
        if item.categories == "storeagent" || item.categories == "storedownloadd" {
            let url = "http://itunes.apple.com/lookup?bundleId=\(item.id!)"
            let data = (try? Data(contentsOf: URL(string: url)!)) ?? Data()
            let results = (((try! JSONSerialization.jsonObject(with: data, options: [])) as! NSDictionary)["results"]! as! NSArray)
            if results.count > 0 {
                let pkgId = (results[0] as! NSDictionary)["trackId"]!.stringValue!
                let url = URL(string: "http://itunes.apple.com/app/id\(pkgId)")!
                if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
                    let mainDiv = xmlDoc.rootElement()!["//div[@id=\"main\"]"][0]
                    let links = mainDiv["//div[@class=\"app-links\"]/a"]
                    // TODO: get screenshots via JSON
                    let screenshotsImgs = mainDiv["//div[contains(@class, \"screenshots\")]//img"]
                    item.screenshots = screenshotsImgs.map {$0.attribute("src")!}.join()
                    homepage = links[0].href
                    if homepage == "http://" {
                        homepage = links[1].href
                    }
                }
            }
        }
        return homepage
    }

    override func log(_ item: GItem) -> String {
        var page = self.logpage
        if item.categories == "storeagent" || item.categories == "storedownloadd" {
            let url = "http://itunes.apple.com/lookup?bundleId=\(item.id!)"
            let data = (try? Data(contentsOf: URL(string: url)!)) ?? Data()
            let results = (((try! JSONSerialization.jsonObject(with: data, options: [])) as! NSDictionary)["results"]! as! NSArray)
            if results.count > 0 {
                let pkgId = (results[0] as! NSDictionary)["trackId"]!.stringValue!
                page = "http://itunes.apple.com/app/id" + pkgId
            }
        }
        return page!
    }

    override func contents(_ item: GItem) -> String {
        var contents = ""
        for pkgId in item.id!.split() {
            let infoOutput = output("\(cmd) --pkg-info-plist \(pkgId)")
            if infoOutput == "" {
                continue
            }
            let plist = infoOutput.propertyList() as! NSDictionary
            var files = output("\(cmd) --files \(pkgId)").split("\n")
            files.removeLast()
            for file in files {
                contents += NSString.path(withComponents: [plist["volume"] as! String, plist["install-location"] as! String, file])
                contents += ("\n")
            }
        }
        return contents
    }

    override func cat(_ item: GItem) -> String {
        return "TODO"
    }


    override func uninstallCmd(_ pkg: GPackage) -> String {
        // SEE: https://github.com/caskroom/homebrew-cask/blob/master/lib/cask/pkg.rb
        var commands = [String]()
        let fileManager = FileManager.default()
        var dirsToDelete = [String]()
        var isDir: ObjCBool = true
        for pkgId in pkg.id.split() {
            let infoOutput = output("\(cmd) --pkg-info-plist \(pkgId)")
            if infoOutput == "" {
                continue
            }
            let plist = infoOutput.propertyList() as! NSDictionary
            var dirs = output("\(cmd) --only-dirs --files \(pkgId)").split("\n")
            dirs.removeLast()
            for dir in dirs {
                let dirPath = NSString.path(withComponents: [plist["volume"] as! String, plist["install-location"] as! String, dir])
                if !dirPath.exists {
                    continue
                }
                let fileAttributes = (try! fileManager.attributesOfItem(atPath: dirPath)) as NSDictionary
                if (!(Int(fileAttributes.fileOwnerAccountID()!) == 0) && !dirPath.hasPrefix("/usr/local"))
                    || dirPath.contains(pkg.name)
                    || dirPath.contains(".")
                    || dirPath.hasPrefix("/opt/") {
                        if (dirsToDelete.filter { dirPath.contains($0) }).count == 0 {
                            dirsToDelete.append(dirPath)
                            commands.append("sudo rm -r \"\(dirPath)\"")
                        }
                }
            }
            var files = output("\(cmd) --files \(pkgId)").split("\n") // links are not detected with --only-files
            files.removeLast()
            for file in files {
                let filePath = NSString.path(withComponents: [plist["volume"] as! String, plist["install-location"] as! String, file])
                if !filePath.exists {
                    continue
                }
                if !(fileManager.fileExists(atPath: filePath, isDirectory: &isDir) && isDir) {
                    if (dirsToDelete.filter { filePath.contains($0) }).count == 0 {
                        commands.append("sudo rm \"\(filePath)\"")
                    }
                }
            }
            commands.append("sudo \(cmd) --forget \(pkgId)")
        }
        return commands.join("; ")

        // TODO: disable Launchd daemons, clean Application Support, Caches, Preferences
        // SEE: https://github.com/caskroom/homebrew-cask/blob/master/lib/cask/artifact/pkg.rb
    }

}
