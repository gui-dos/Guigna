import Foundation

class GScrape: GSource {
    var pageNumber: Int
    var itemsPerPage: Int!

    override init(name: String, agent: GAgent!) {
        pageNumber = 1
        super.init(name: name, agent: agent)
    }

    func refresh() {}
}


class PkgsrcSE: GScrape {

    init(agent: GAgent) {
        super.init(name: "Pkgsrc.se", agent: agent)
        homepage = "http://pkgsrc.se/"
        itemsPerPage = 25
        cmd = "pkgsrc"
    }

    override func refresh() {
        var entries = [GItem]()
        let url = URL(string: "http://pkgsrc.se/?page=\(pageNumber)")!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
            let mainDiv = xmlDoc.rootElement()!["//div[@id=\"main\"]"][0]
            var dates = mainDiv["h3"]
            var names = mainDiv["b"]
            names.remove(at: 0)
            names.remove(at: 0)
            var comments = mainDiv["div"]
            comments.remove(at: 0)
            comments.remove(at: 0)
            for (i, node) in names.enumerated() {
                let id = node["a"][0].stringValue!
                var idx = id.rindex("/")
                let name = id.substring(from: idx + 1)
                let category = id.substring(to: idx)
                var version = dates[i].stringValue!
                idx = version.index(" (")
                if idx != NSNotFound {
                    version = version.substring(from: idx + 2)
                    version = version.substring(to: version.index(")"))
                } else {
                    version = version.substring(from: version.rindex(" ") + 1)
                }
                var description = comments[i].stringValue!
                description = description.substring(to: description.index("\n"))
                description = description.substring(from: description.index(": ") + 2)
                let entry = GItem(name: name, version: version, source: self, status: .available)
                entry.id = id
                entry.description = description
                entry.categories = category
                entries.append(entry)
            }
        }
        items = entries
    }

    override func home(_ item: GItem) -> String {
        return agent.nodes(URL: self.log(item), XPath: "//div[@id=\"main\"]//a")[2].href
    }

    override func log(_ item: GItem) -> String {
        return "http://pkgsrc.se/\(item.id!)"
    }
}


class Freecode: GScrape {

    init(agent: GAgent) {
        super.init(name: "Freecode", agent: agent)
        homepage = "http://freshfoss.com/"
        itemsPerPage = 40
        cmd = "freecode"
    }

    override func refresh() {
        var projs = [GItem]()
        let url = URL(string: "http://freshfoss.com/?n=\(pageNumber)")!
        // Don't use agent.nodesForUrl since NSXMLDocumentTidyHTML strips <article>
        if var page = try? String(contentsOf: url, encoding: .utf8) {
            page = page.replace("article", "div")
            if let xmlDoc = try? XMLDocument(xmlString: page, options: Int(NSXMLDocumentTidyHTML)) {
                let nodes = xmlDoc.rootElement()![".//div[starts-with(@class, 'project')]"]
                for node in nodes {
                    let titleNodes = node["h3/a/node()"]
                    let name = titleNodes[0].stringValue!
                    var version = ""
                    if titleNodes.count > 2 {
                        version = titleNodes[2].stringValue!
                    }
                    let id = (node["h3/a"][0].href as NSString).lastPathComponent
                    let home = node[".//a[@itemprop='url']"][0].href
                    let description = node[".//p[@itemprop='featureList']"][0].stringValue!
                    let tagNodes = node[".//p[@itemprop='keywords']/a"]
                    var tags = tagNodes.map {$0.stringValue!}
                    let proj = GItem(name: name, version: version, source: self, status: .available)
                    proj.id = id
                    proj.license = tags[0]
                    tags.remove(at: 0)
                    proj.categories = tags.join()
                    proj.description = description
                    proj.homepage = home
                    projs.append(proj)
                }
            }
        }
        items = projs
    }

    override func home(_ item: GItem) -> String {
        return item.homepage
    }

    override func log(_ item: GItem) -> String {
        return "http://freshfoss.com/projects/\(item.id!)"
    }
}


class Debian: GScrape {

    init(agent: GAgent) {
        super.init(name: "Debian", agent: agent)
        homepage = "http://packages.debian.org/unstable/"
        itemsPerPage = 100
        cmd = "apt-get"
    }

    override func refresh() {
        var pkgs = [GItem]()
        let url = URL(string: "http://news.gmane.org/group/gmane.linux.debian.devel.changes.unstable/last=")!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
            let nodes = xmlDoc.rootElement()!["//table[@class=\"threads\"]//table/tr"]
            for node in nodes {
                let link = node[".//a"][0].stringValue!
                let components = link.split()
                let name = components[1]
                let version = components[2]
                let pkg = GItem(name: name, version: version, source: self, status: .available)
                pkgs.append(pkg)
            }
        }
        items = pkgs
    }

    override func home(_ item: GItem) -> String {
        var page = log(item)
        let links = agent.nodes(URL: page, XPath: "//a[text()=\"Homepage\"]")
        if links.count > 0 {
            page = links[0].href
        }
        return page
    }

    override func log(_ item: GItem) -> String {
        return "http://packages.debian.org/sid/\(item.name)"
    }
}


class CocoaPods: GScrape {

    init(agent: GAgent) {
        super.init(name: "CocoaPods", agent: agent)
        homepage = "http://www.cocoapods.org"
        itemsPerPage = 25
        cmd = "pod"
    }

    override func refresh() {
        var pods = [GItem]()
        let url = URL(string: "https://feeds.cocoapods.org/new-pods.rss")!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyXML)) {
            let nodes = xmlDoc.rootElement()!["//item"]
            for node in nodes {
                let name = node["title"][0].stringValue!
                let htmlDescription = node["description"][0].stringValue!
                let descriptionNode = (try! XMLDocument(xmlString: htmlDescription, options: Int(NSXMLDocumentTidyHTML))).rootElement()!
                let description = descriptionNode[".//p"][1].stringValue!
                var licenseNodes = descriptionNode[".//li[starts-with(.,'License:')]"]
                var license: String = ""
                if licenseNodes.count > 0 {
                    license = licenseNodes[0].stringValue!.substring(from: 9)
                }
                var version = descriptionNode[".//li[starts-with(.,'Latest version:')]"][0].stringValue!
                version = version.substring(from: 15)
                let home = descriptionNode[".//li[starts-with(.,'Homepage:')]/a"][0].stringValue!
                var date = node["pubDate"][0].stringValue!
                date = date.substring(4, 12)
                let pod = GItem(name: name, version: version, source: self, status: .available)
                pod.description = description
                pod.homepage = home
                pod.license = license
                pods.append(pod)
            }
        }
        items = pods
    }

    override func home(_ item: GItem) -> String {
        return item.homepage
    }

    override func log(_ item: GItem) -> String {
        return "http://github.com/CocoaPods/Specs/tree/master/Specs/\(item.name)"
    }
}


class PyPI: GScrape {

    init(agent: GAgent) {
        super.init(name: "PyPI", agent: agent)
        homepage = "http://pypi.python.org/pypi"
        itemsPerPage = 40
        cmd = "pip"
    }

    override func refresh() {
        var eggs = [GItem]()
        let url = URL(string: homepage)!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
            var nodes = xmlDoc.rootElement()!["//table[@class=\"list\"]//tr"]
            nodes.remove(at: 0)
            nodes.removeLast()
            for node in nodes {
                let rowData = node["td"]
                // let date = rowData[0].stringValue!
                let link = rowData[1]["a"][0].href
                let splits = link.split("/")
                let name = splits[splits.count - 2]
                let version = splits.last!
                let description = rowData[2].stringValue!
                let egg = GItem(name: name, version: version, source: self, status: .available)
                egg.description = description
                eggs.append(egg)
            }
        }
        items = eggs
    }

    override func home(_ item: GItem) -> String {
        return agent.nodes(URL: self.log(item), XPath:"//ul[@class=\"nodot\"]/li/a")[0].stringValue!
        // if nil return [self log:item];
    }

    override func log(_ item: GItem) -> String {
        return "\(self.homepage!)/\(item.name)/\(item.version)"
    }
}


class RubyGems: GScrape {

    init(agent: GAgent) {
        super.init(name: "RubyGems", agent: agent)
        homepage = "http://rubygems.org/"
        itemsPerPage = 25
        cmd = "gem"
    }

    override func refresh() {
        var gems = [GItem]()
        let url = URL(string: "http://m.rubygems.org/")!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
            let nodes = xmlDoc.rootElement()!["//li"]
            for node in nodes {
                let components = node.stringValue!.split()
                let name = components[0]
                let version = components[1]
                let spans = node[".//span"]
                // let date = spans[0].stringValue!
                let info = spans[1].stringValue!
                let gem = GItem(name: name, version: version, source: self, status: .available)
                gem.description = info
                gems.append(gem)
            }
        }
        items = gems
    }

    override func home(_ item: GItem) -> String {
        var page = log(item)
        let links = agent.nodes(URL:page, XPath:"//div[@class=\"links\"]/a")
        if links.count > 0 {
            for link in links {
                if link.stringValue! == "Homepage" {
                    page = link.href
                }
            }
        }
        return page
    }

    override func log(_ item: GItem) -> String {
        return "\(self.homepage!)gems/\(item.name)"
    }

}


class MacUpdate: GScrape {

    init(agent: GAgent) {
        super.init(name: "MacUpdate", agent: agent)
        homepage = "http://www.macupdate.com/"
        itemsPerPage = 80
        cmd = "macupdate"
    }

    override func refresh() {
        var apps = [GItem]()
        let url = URL(string: "https://www.macupdate.com/page/\(pageNumber - 1)")!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
            let nodes = xmlDoc.rootElement()!["//tr[starts-with(@class,\"app_tr_row\")]"]
            for node in nodes {
                var name = node[".//a"][0].stringValue!
                let idx = name.rindex(" ")
                var version = ""
                if idx != NSNotFound {
                    version = name.substring(from: idx + 1)
                    name = name.substring(to: idx)
                }
                var description = node[".//span"][0].stringValue!
                let price = node[".//span[contains(@class,\"appprice\")]"][0].stringValue!
                let id = node[".//a"][0].href.split("/")[3]
                let app = GItem(name: name, version: version, source: self, status: .available)
                app.id = id
                if price != "Free" {
                    description += " - $\(price)"
                } else {
                    app.license = "Free"
                }
                app.description = description
                apps.append(app)
            }
        }
        items = apps
    }

    override func home(_ item: GItem) -> String {
        let nodes = agent.nodes(URL: log(item), XPath: "//a[@target=\"devsite\"]")
        let href = nodes[0].href.removingPercentEncoding
        return "http://www.macupdate.com\(href!)"
    }

    override func log(_ item: GItem) -> String {
        return "http://www.macupdate.com/app/mac/\(item.id!)"
    }
}


class AppShopper: GScrape {

    init(agent: GAgent) {
        super.init(name: "AppShopper", agent: agent)
        homepage = "http://appshopper.com/mac/all/"
        itemsPerPage = 20
        cmd = "appstore"
    }


    override func refresh() {
        var apps = [GItem]()
        let url = URL(string: "http://appshopper.com/mac/all/\(pageNumber)")!
        let whitespaceCharacterSet = CharacterSet.whitespaces
        let whitespaceAndNewlineCharacterSet = CharacterSet.whitespacesAndNewlines
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
            let nodes = xmlDoc.rootElement()!["//div[@data-appid]"]
            for node in nodes {
                let name = node[".//h2"][0].stringValue!.trim(whitespaceAndNewlineCharacterSet)
                var version = node[".//span[starts-with(@class,\"version\")]"][0].stringValue!
                version = version.substring(from: 2) // trim "V "
                var id = node.attribute("data-appid")!
                let nick = (node["a"][0].href as NSString).lastPathComponent
                id = "\(id) \(nick)"
                let category = node[".//h5/span"][0].stringValue!
                let type = node[".//span[starts-with(@class,\"change\")]"][0].stringValue!
                var description = node[".//p[@class=\"description\"]"][0].stringValue!
                let price = node[".//div[@class=\"price\"]"][0].children![0].stringValue!
                // TODO:NSXML UTF8 encoding
                let localPrice = price.trim(whitespaceCharacterSet).replace("â‚¬", "€")
                let app = GItem(name: name, version: version, source: self, status: .available)
                app.id = id
                app.categories = category
                if localPrice != "Free" {
                    description = "\(type) \(localPrice) - \(description)"
                } else {
                    description = "\(type) - \(description)"
                    app.license = "Free"
                }
                app.description = description
                apps.append(app)
            }
        }
        items = apps
    }

    override func home(_ item: GItem) -> String {
        let url = URL(string: "http://itunes.apple.com/app/id" + item.id!.split()[0])!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
            let mainDiv = xmlDoc.rootElement()!["//div[@id=\"main\"]"][0]
            let links = mainDiv["//div[@class=\"app-links\"]/a"]
            let screenshotsImgs = mainDiv["//div[contains(@class, \"screenshots\")]//img"]
            item.screenshots = screenshotsImgs.map {$0.attribute("src")!}.joined(separator: " ")
            var homepage = links[0].href
            if homepage == "http://" {
                homepage = links[1].href
            }
            return homepage
        } else {
            return log(item)
        }
    }

    override func log(_ item: GItem) -> String {
        let name = item.id!.split()[1]
        var category = item.categories!.replace(" ", "-").lowercased()
        category = category.replace("-&-", "-").lowercased() // fix Healthcare & Fitness
        return "http://www.appshopper.com/mac/\(category)/\(name)"
    }
}


class AppShopperIOS: GScrape {

    init(agent: GAgent) {
        super.init(name: "AppShopper iOS", agent: agent)
        homepage = "http://appshopper.com/all/"
        itemsPerPage = 20
        cmd = "appstore"
    }

    override func refresh() {
        var apps = [GItem]()
        let url = URL(string: "http://appshopper.com/all/\(pageNumber)")!
        let whitespaceCharacterSet = CharacterSet.whitespaces
        let whitespaceAndNewlineCharacterSet = CharacterSet.whitespacesAndNewlines
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
            let nodes = xmlDoc.rootElement()!["//div[@data-appid]"]
            for node in nodes {
                let name = node[".//h2"][0].stringValue!.trim(whitespaceAndNewlineCharacterSet)
                var version = node[".//span[starts-with(@class,\"version\")]"][0].stringValue!
                version = version.substring(from: 2) // trim "V "
                var id = node.attribute("data-appid")!
                let nick = (node["a"][0].href as NSString).lastPathComponent
                id = "\(id) \(nick)"
                let category = node[".//h5/span"][0].stringValue!
                let type = node[".//span[starts-with(@class,\"change\")]"][0].stringValue!
                var description = node[".//p[@class=\"description\"]"][0].stringValue!
                let price = node[".//div[@class=\"price\"]"][0].children![0].stringValue!
                // TODO:NSXML UTF8 encoding
                let localPrice = price.trim(whitespaceCharacterSet).replace("â‚¬", "€")
                let app = GItem(name: name, version: version, source: self, status: .available)
                app.id = id
                app.categories = category
                if localPrice != "Free" {
                    description = "\(type) \(localPrice) - \(description)"
                } else {
                    description = "\(type) - \(description)"
                    app.license = "Free"
                }
                app.description = description
                apps.append(app)
            }
        }
        items = apps
    }

    override func home(_ item: GItem) -> String {
        let url = URL(string: "http://itunes.apple.com/app/id" + item.id!.split()[0])!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: Int(NSXMLDocumentTidyHTML)) {
            let mainDiv = xmlDoc.rootElement()!["//div[@id=\"main\"]"][0]
            let links = mainDiv["//div[@class=\"app-links\"]/a"]
            let screenshotsImgs = mainDiv["//div[contains(@class, \"screenshots\")]//img"]
            item.screenshots = screenshotsImgs.map {$0.attribute("src")!}.joined(separator: " ")
            var homepage = links[0].href
            if homepage == "http://" {
                homepage = links[1].href
            }
            return homepage
        } else {
            return log(item)
        }
    }

    override func log(_ item: GItem) -> String {
        let name = item.id!.split()[1]
        var category = item.categories!.replace(" ", "-").lowercased()
        category = category.replace("-&-", "-").lowercased() // fix Healthcare & Fitness
        return "http://www.appshopper.com/\(category)/\(name)"
    }
}
