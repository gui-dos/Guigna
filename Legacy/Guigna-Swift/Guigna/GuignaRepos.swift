import Foundation

class GRepo: GScrape {
}


final class Native: GRepo {

    init(agent: GAgent) {
        super.init(name: "Native Installers", agent: agent)
        homepage = "http://github.com/gui-dos/Guigna/"
        itemsPerPage = 250
        cmd = "installer"
    }

    override func refresh() {
        var pkgs = [GItem]()
        let url = URL(string: "https://docs.google.com/spreadsheets/d/1HOslVAaEwrcd7hmu6rWzd7jayMUT-nzaL9YL8llE35Q")!
        if let xmlDoc = try? XMLDocument(contentsOf: url, options: .documentTidyHTML) {
            let nodes = xmlDoc.rootElement()!["//table[@class=\"waffle\"]//tr"]
            let whitespaceCharacterSet = CharacterSet.whitespaces
            for node in nodes {
                let columns = node["td[@dir=\"ltr\"]"]
                if columns.count == 0 {
                    continue
                }
                let name = columns[0].stringValue!.trim(whitespaceCharacterSet)
                if name == "Name" {
                    continue
                }
                let version = columns[1].stringValue!.trim(whitespaceCharacterSet)
                let homepage = columns[3].stringValue!.trim(whitespaceCharacterSet)
                let url = columns[4].stringValue!.trim(whitespaceCharacterSet)
                let pkg = GItem(name: name, version: version, source: self)
                pkg.homepage = homepage
                pkg.description = url
                pkg.URL = url
                pkgs.append(pkg)
            }
        }
        items = pkgs
    }
}
