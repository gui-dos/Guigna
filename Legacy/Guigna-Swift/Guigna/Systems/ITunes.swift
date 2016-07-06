import Foundation

final class ITunes: GSystem {

    override class var prefix: String { return "" }

    init(agent: GAgent) {
        super.init(name: "iTunes", agent: agent)
        homepage = "https://itunes.apple.com/genre/ios/id36?mt=8"
        logpage = "https://itunes.apple.com/genre/ios/id36?mt=8"
        cmd = "/Applications/iTunes.app/Contents/MacOS/iTunes"
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
        let fileManager = FileManager.default
        if let contents = (try? fileManager.contentsOfDirectory(atPath: ("~/Music/iTunes/iTunes Media/Mobile Applications" as NSString).expandingTildeInPath)) {
            for filename in contents {
                let ipa = ("~/Music/iTunes/iTunes Media/Mobile Applications/\(filename)" as NSString).expandingTildeInPath
                let idx = filename.rindex(" ")
                if idx == NSNotFound {
                    continue
                }
                let version = filename.substring(idx + 1, filename.length - idx - 5)
                var escapedIpa = ipa.replace(" ", "__")
                var plist = output("/usr/bin/unzip -p \(escapedIpa) iTunesMetadata.plist")
                if  plist == "" { // binary plist
                    escapedIpa = ipa.replace(" ", "\\__")
                    plist = output("/bin/sh -c /usr/bin/unzip__-p__\(escapedIpa)__iTunesMetadata.plist__|__plutil__-convert__xml1__-o__-__-")
                }
                let metadata = plist.propertyList() as! NSDictionary
                let name = metadata["itemName"]! as! String
                let pkg = GPackage(name: name, version: "", system: self, status: .upToDate)
                pkg.id = filename.substring(to: filename.length - 4)
                pkg.installed = version
                pkg.categories = metadata["genre"]! as? String
                pkgs.append(pkg)
            }
            //    for pkg in installed() {
            //        index[pkg.key()].status = pkg.status
            //    }
        }
        return pkgs
    }


    override func info(_ item: GItem) -> String {
        return cat(item)
    }

    override func home(_ item: GItem) -> String {
        var homepage = self.homepage
        let ipa = ("~/Music/iTunes/iTunes Media/Mobile Applications/\(item.id!).ipa" as NSString).expandingTildeInPath
        var escapedIpa = ipa.replace(" ", "__")
        var plist = output("/usr/bin/unzip -p \(escapedIpa) iTunesMetadata.plist")
        if  plist == "" { // binary plist
            escapedIpa = ipa.replace(" ", "\\__")
            plist = output("/bin/sh -c /usr/bin/unzip__-p__\(escapedIpa)__iTunesMetadata.plist__|__plutil__-convert__xml1__-o__-__-")
        }
        let metadata = plist.propertyList() as! NSDictionary
        let itemId: Int = metadata["itemId"]! as! Int
        let url = URL(string: "http://itunes.apple.com/app/id\(itemId)")!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(XMLNodeOptions.documentTidyHTML.rawValue)) {
            let mainDiv = xmlDoc.rootElement()!["//div[@id=\"main\"]"][0]
            let links = mainDiv["//div[@class=\"app-links\"]/a"]
            // TODO: get screenshots via JSON
            let screenshotsImgs = mainDiv["//div[contains(@class, \"screenshots\")]//img"]
            item.screenshots = screenshotsImgs.map {$0.attribute("src")!}.join()
            homepage = links[0].href
            if homepage == "http://" {
                homepage = links[1].href
            }
            return homepage!
        } else {
            return log(item)
        }
    }

    override func log(_ item: GItem) -> String {
        let ipa = ("~/Music/iTunes/iTunes Media/Mobile Applications/\(item.id!).ipa" as NSString).expandingTildeInPath
        var escapedIpa = ipa.replace(" ", "__")
        var plist = output("/usr/bin/unzip -p \(escapedIpa) iTunesMetadata.plist")
        if  plist == "" { // binary plist
            escapedIpa = ipa.replace(" ", "\\__")
            plist = output("/bin/sh -c /usr/bin/unzip__-p__\(escapedIpa)__iTunesMetadata.plist__|__plutil__-convert__xml1__-o__-__-")
        }
        let metadata = plist.propertyList() as! NSDictionary
        let itemId: Int = metadata["itemId"]! as! Int
        return "http://itunes.apple.com/app/id\(itemId)"
    }

    override func contents(_ item: GItem) -> String {
        let ipa = ("~/Music/iTunes/iTunes Media/Mobile Applications/\(item.id!).ipa" as NSString).expandingTildeInPath
        let escapedIpa = ipa.replace(" ", "__")
        return output("/usr/bin/zipinfo -1 \(escapedIpa)")
    }

    override func cat(_ item: GItem) -> String {
        let ipa = ("~/Music/iTunes/iTunes Media/Mobile Applications/\(item.id!).ipa" as NSString).expandingTildeInPath
        var escapedIpa = ipa.replace(" ", "__")
        var plist = output("/usr/bin/unzip -p \(escapedIpa) iTunesMetadata.plist")
        if  plist == "" { // binary plist
            escapedIpa = ipa.replace(" ", "\\__")
            plist = output("/bin/sh -c /usr/bin/unzip__-p__\(escapedIpa)__iTunesMetadata.plist__|__plutil__-convert__xml1__-o__-__-")
        }
        let metadata = plist.propertyList() as! NSDictionary
        return metadata.description as String
    }

    override func uninstallCmd(_ pkg: GPackage) -> String {
        return "rm -r '" + ("~/Music/iTunes/iTunes Media/Mobile Applications/\(pkg.id).ipa" as NSString).expandingTildeInPath + "'"
    }


}
