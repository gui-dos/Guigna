import Foundation

class GScrape: GSource {
    var pageNumber: Int
    var itemsPerPage: Int!
    
    override init(name: String, agent: GAgent!) {
        pageNumber = 1
        super.init(name: name, agent: agent)
    }
    
    func refresh() {};
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
        let url = NSURL(string: "http://pkgsrc.se/?page=\(pageNumber)")!
        if let xmlDoc = NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML), error: nil) {
            let mainDiv = xmlDoc.rootElement()!["//div[@id=\"main\"]"][0]
            var dates = mainDiv["h3"]
            var names = mainDiv["b"]
            names.removeAtIndex(0)
            names.removeAtIndex(0)
            var comments = mainDiv["div"]
            comments.removeAtIndex(0)
            comments.removeAtIndex(0)
            for (i, node) in enumerate(names) {
                let id = node["a"][0].stringValue!
                var idx = id.rindex("/")
                let name = id.substringFromIndex(idx + 1)
                let category = id.substringToIndex(idx)
                var version = dates[i].stringValue!
                idx = version.index(" (")
                if idx != NSNotFound {
                    version = version.substringFromIndex(idx + 2)
                    version = version.substringToIndex(version.index(")"))
                } else {
                    version = version.substringFromIndex(version.rindex(" ") + 1)
                }
                var description = comments[i].stringValue!
                description = description.substringToIndex(description.index("\n"))
                description = description.substringFromIndex(description.index(": ") + 2)
                var entry = GItem(name: name, version: version, source: self, status: .Available)
                entry.id = id
                entry.description = description
                entry.categories = category
                entries.append(entry)
            }
        }
        items = entries
    }
    
    override func home(item: GItem) -> String {
        return agent.nodes(URL: self.log(item), XPath: "//div[@id=\"main\"]//a")[2].href
    }
    
    override func log(item: GItem) -> String {
        return "http://pkgsrc.se/\(item.id)"
    }
}


class Freecode: GScrape {
    
    init(agent: GAgent) {
        super.init(name: "Freecode", agent: agent)
        homepage = "http://www.freecode.club/"
        itemsPerPage = 40
        cmd = "freecode"
    }
    
    override func refresh() {
        var projs = [GItem]()
        let url = NSURL(string: "http://freecode.club/index?n=\(pageNumber)")!
        // Don't use agent.nodesForUrl since NSXMLDocumentTidyHTML strips <article>
        if var page = String(contentsOfURL: url, encoding: NSUTF8StringEncoding, error: nil) {
            page = page.stringByReplacingOccurrencesOfString("article", withString: "div")
            if let xmlDoc = NSXMLDocument(XMLString: page, options: Int(NSXMLDocumentTidyHTML), error: nil) {
                var nodes = xmlDoc.rootElement()![".//div[starts-with(@class, 'project')]"]
                for node in nodes {
                    let titleNodes = node["h3/a/node()"]
                    let name = titleNodes[0].stringValue!
                    let version = titleNodes[2].stringValue!
                    let id = node["h3/a"][0].href.lastPathComponent
                    let home = node[".//a[@itemprop='url']"][0].href
                    let description = node[".//p[@itemprop='featureList']"][0].stringValue!
                    let tagNodes = node[".//p[@itemprop='keywords']/a"]
                    var tags = tagNodes.map {$0.stringValue!}
                    let proj = GItem(name: name, version: version, source: self, status: .Available)
                    proj.id = id
                    proj.license = tags[0]
                    tags.removeAtIndex(0)
                    proj.categories = tags.join()
                    proj.description = description
                    proj.homepage = home
                    projs.append(proj)
                }
            }
        }
        items = projs
    }
    
    override func home(item: GItem) -> String {
        return item.homepage
    }
    
    override func log(item: GItem) -> String {
        return "http://freecode.club/projects/\(item.id)"
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
        let url = NSURL(string: "http://news.gmane.org/group/gmane.linux.debian.devel.changes.unstable/last=")!
        if let xmlDoc = NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML), error: nil) {
            var nodes = xmlDoc.rootElement()!["//table[@class=\"threads\"]//table/tr"]
            for node in nodes {
                let link = node[".//a"][0].stringValue!
                let components = link.split()
                let name = components[1]
                let version = components[2]
                var pkg = GItem(name: name, version: version, source: self, status: .Available)
                pkgs.append(pkg)
            }
        }
        items = pkgs
    }
    
    override func home(item: GItem) -> String {
        var page = log(item)
        let links = agent.nodes(URL: page, XPath: "//a[text()=\"Homepage\"]")
        if links.count > 0 {
            page = links[0].href
        }
        return page
    }
    
    override func log(item: GItem) -> String {
        return "http://packages.debian.org/sid/\(item.name)"
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
        let url = NSURL(string: homepage)!
        if let xmlDoc = NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML), error: nil) {
            var nodes = xmlDoc.rootElement()!["//table[@class=\"list\"]//tr"]
            nodes.removeAtIndex(0)
            nodes.removeLast()
            for node in nodes {
                let rowData = node["td"]
                let date = rowData[0].stringValue!
                let link = rowData[1]["a"][0].href
                let splits = link.split("/")
                let name = splits[splits.count - 2]
                let version = splits.last!
                let description = rowData[2].stringValue!
                var egg = GItem(name: name, version: version, source: self, status: .Available)
                egg.description = description
                eggs.append(egg)
            }
        }
        items = eggs
    }
    
    override func home(item: GItem) -> String {
        return agent.nodes(URL: self.log(item), XPath:"//ul[@class=\"nodot\"]/li/a")[0].stringValue!
        // if nil return [self log:item];
    }
    
    override func log(item: GItem) -> String {
        return "\(self.homepage)/\(item.name)/\(item.version)"
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
        let url = NSURL(string: "http://m.rubygems.org/")!
        if let xmlDoc = NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML), error: nil) {
            let nodes = xmlDoc.rootElement()!["//li"]
            for node in nodes {
                let components = node.stringValue!.split()
                let name = components[0]
                let version = components[1]
                let spans = node[".//span"]
                let date = spans[0].stringValue!
                let info = spans[1].stringValue!
                var gem = GItem(name: name, version: version, source: self, status: .Available)
                gem.description = info
                gems.append(gem)
            }
        }
        items = gems
    }
    
    override func home(item: GItem) -> String {
        var page = log(item)
        var links = agent.nodes(URL:page, XPath:"//div[@class=\"links\"]/a")
        if links.count > 0 {
            for link in links {
                if link.stringValue! == "Homepage" {
                    page = link.href
                }
            }
        }
        return page
    }
    
    override func log(item: GItem) -> String {
        return "\(self.homepage)gems/\(item.name)"
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
        let url = NSURL(string: "https://www.macupdate.com/page/\(pageNumber - 1)")!
        if let xmlDoc = NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML), error: nil) {
            var nodes = xmlDoc.rootElement()!["//tr[starts-with(@class,\"app_tr_row\")]"]
            for node in nodes {
                var name = node[".//a"][0].stringValue!
                let idx = name.rindex(" ")
                var version = ""
                if idx != NSNotFound {
                    version = name.substringFromIndex(idx + 1)
                    name = name.substringToIndex(idx)
                }
                var description = node[".//span"][0].stringValue!
                var price = node[".//span[contains(@class,\"appprice\")]"][0].stringValue!
                let id = node[".//a"][0].href.split("/")[3]
                let app = GItem(name: name, version: version, source: self, status: .Available)
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
    
    override func home(item: GItem) -> String {
        let nodes = agent.nodes(URL: log(item), XPath: "//a[@target=\"devsite\"]")
        let href = nodes[0].href.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
        return "http://www.macupdate.com\(href!)"
    }
    
    override func log(item: GItem) -> String {
        return "http://www.macupdate.com/app/mac/\(item.id)"
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
        let url = NSURL(string: "http://appshopper.com/mac/all/\(pageNumber)")!
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        let whitespaceAndNewlineCharacterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        if let xmlDoc = NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML), error: nil) {
            var nodes = xmlDoc.rootElement()!["//div[@data-appid]"]
            for node in nodes {
                let name = node[".//h2"][0].stringValue!.stringByTrimmingCharactersInSet(whitespaceAndNewlineCharacterSet)
                var version = node[".//span[starts-with(@class,\"version\")]"][0].stringValue!
                version = version.substringFromIndex(2) // trim "V "
                var id = node.attribute("data-appid")
                let nick = node["a"][0].href.lastPathComponent
                id = "\(id) \(nick)"
                var category = node[".//h5/span"][0].stringValue!
                let type = node[".//span[starts-with(@class,\"change\")]"][0].stringValue!
                let desc = node[".//p[@class=\"description\"]"][0].stringValue!
                var price = node[".//div[@class=\"price\"]"][0].children![0].stringValue!
                // TODO:NSXML UTF8 encoding
                var fixedPrice = price.stringByTrimmingCharactersInSet(whitespaceCharacterSet).stringByReplacingOccurrencesOfString("â‚¬", withString: "€")
                var app = GItem(name: name, version: version, source: self, status: .Available)
                app.id = id
                app.categories = category
                app.description = "\(type) \(fixedPrice) - \(desc)"
                apps.append(app)
            }
        }
        items = apps
    }
    
    override func home(item: GItem) -> String {
        let url = NSURL(string: "http://itunes.apple.com/app/id" + item.id.split()[0])!
        if let xmlDoc = NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML), error: nil) {
            let mainDiv = xmlDoc.rootElement()!["//div[@id=\"main\"]"][0]
            let links = mainDiv["//div[@class=\"app-links\"]/a"]
            let screenshotsImgs = mainDiv["//div[contains(@class, \"screenshots\")]//img"]
            item.screenshots = " ".join(screenshotsImgs.map {$0.attribute("src")})
            var homepage = links[0].href
            if homepage == "http://" {
                homepage = links[1].href
            }
            return homepage
        } else {
            return log(item)
        }
    }
    
    override func log(item: GItem) -> String {
        let name = item.id.split()[1]
        var category = item.categories!.stringByReplacingOccurrencesOfString(" ", withString: "-").lowercaseString
        category = category.stringByReplacingOccurrencesOfString("-&-", withString: "-").lowercaseString // fix Healthcare & Fitness
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
        let url = NSURL(string: "http://appshopper.com/all/\(pageNumber)")!
        let whitespaceCharacterSet = NSCharacterSet.whitespaceCharacterSet()
        let whitespaceAndNewlineCharacterSet = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        if let xmlDoc = NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML), error: nil) {
            var nodes = xmlDoc.rootElement()!["//div[@data-appid]"]
            for node in nodes {
                let name = node[".//h2"][0].stringValue!.stringByTrimmingCharactersInSet(whitespaceAndNewlineCharacterSet)
                var version = node[".//span[starts-with(@class,\"version\")]"][0].stringValue!
                version = version.substringFromIndex(2) // trim "V "
                var id = node.attribute("data-appid")
                let nick = node["a"][0].href.lastPathComponent
                id = "\(id) \(nick)"
                var category = node[".//h5/span"][0].stringValue!
                let type = node[".//span[starts-with(@class,\"change\")]"][0].stringValue!
                let desc = node[".//p[@class=\"description\"]"][0].stringValue!
                var price = node[".//div[@class=\"price\"]"][0].children![0].stringValue!
                // TODO:NSXML UTF8 encoding
                var fixedPrice = price.stringByTrimmingCharactersInSet(whitespaceCharacterSet).stringByReplacingOccurrencesOfString("â‚¬", withString: "€")
                var app = GItem(name: name, version: version, source: self, status: .Available)
                app.id = id
                app.categories = category
                app.description = "\(type) \(fixedPrice) - \(desc)"
                apps.append(app)
            }
        }
        items = apps
    }
    
    override func home(item: GItem) -> String {
        let url = NSURL(string: "http://itunes.apple.com/app/id" + item.id.split()[0])!
        if let xmlDoc = NSXMLDocument(contentsOfURL: url, options: Int(NSXMLDocumentTidyHTML), error: nil) {
            let mainDiv = xmlDoc.rootElement()!["//div[@id=\"main\"]"][0]
            let links = mainDiv["//div[@class=\"app-links\"]/a"]
            let screenshotsImgs = mainDiv["//div[contains(@class, \"screenshots\")]//img"]
            item.screenshots = " ".join(screenshotsImgs.map {$0.attribute("src")})
            var homepage = links[0].href
            if homepage == "http://" {
                homepage = links[1].href
            }
            return homepage
        } else {
            return log(item)
        }
    }
    
    override func log(item: GItem) -> String {
        let name = item.id.split()[1]
        var category = item.categories!.stringByReplacingOccurrencesOfString(" ", withString: "-").lowercaseString
        category = category.stringByReplacingOccurrencesOfString("-&-", withString: "-").lowercaseString // fix Healthcare & Fitness
        return "http://www.appshopper.com/\(category)/\(name)"
    }
}
