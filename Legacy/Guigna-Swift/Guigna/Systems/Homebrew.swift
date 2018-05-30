import Foundation

final class Homebrew: GSystem {

    override class var prefix: String { return "/usr/local"}

    init(agent: GAgent) {
        super.init(name: "Homebrew", agent: agent)
        homepage = "http://brew.sh/"
        logpage = "http://github.com/Homebrew/homebrew-core/commits"
        cmd = "\(prefix)/bin/brew"
    }

    @discardableResult
    override func list() -> [GPackage] {

        index.removeAll(keepingCapacity: true)
        items.removeAll(keepingCapacity: true)

        /* TODO
         let jsonInfo = output("\(cmd) info --json=v1 --all")
         let formulae = try! JSONSerialization.jsonObject(with: jsonInfo.data(using: .utf8)!)
         for formula in formulae as! [[String: Any]] {
         let name  = formula["full_name"]! as! String
         let versions = formula["versions"] as! [String: Any]
         var version = versions["stable"]! as! String
         let revision = formula["revision"]! as! Int
         if revision != 0 {
         version = "\(version)_\(revision)"
         }
         let description = formula["desc"]! as? String ?? ""

         print("\(name) \(version) - \(description)")

         let installed = formula["installed"] as! [[String: Any]]
         var installedVersion: String! = nil
         if installed.count > 0 {
         installedVersion = installed[0]["version"] as! String
         }
         if installedVersion != nil {
         print("installed: \(installedVersion!)")
         }

         let outdated = formula["outdated"] as! Bool
         if outdated {
         print("outdated")
         }

         }
         */

        // /usr/bin/ruby -C /usr/local/Homebrew/Library/Homebrew -I. -e "require 'global'; require 'formula'; Formula.each {|f| puts \"#{f.name} #{f.pkg_version}\"}" not supported anymore
        // see: https://github.com/Homebrew/homebrew/pull/48261

        let workaround = "ENV['HOMEBREW_BREW_FILE']='\(prefix)/bin/brew';ENV['HOMEBREW_PREFIX']='\(prefix)';ENV['HOMEBREW_REPOSITORY']='\(prefix)/Homebrew';ENV['HOMEBREW_LIBRARY']='\(prefix)/Homebrew/Library';ENV['HOMEBREW_CELLAR']='\(prefix)/Cellar';ENV['HOMEBREW_OSX_VERSION']=`/usr/bin/sw_vers__-productVersion`.to_s;ENV['HOMEBREW_CACHE']=File.expand_path('~/Library/Caches/Homebrew');"

        var outputLines = output("/usr/bin/ruby -C \(prefix)/Homebrew/Library/Homebrew -I. -e " + workaround + "require__'global';require__'formula';__Formula.each__{|f|__puts__\"#{f.full_name}|#{f.pkg_version}|#{f.bottle}|#{f.desc}\"}").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.split("|")
            if components.count < 4 {
                continue
            }
            let fullName = components[0]
            var nameComponents = fullName.split("/")
            let name = nameComponents.removeLast()
            let repo: String! = nameComponents.count > 0 ? nameComponents.join("/") : nil
            let version = components[1]
            let bottle  = components[2]
            var desc    = components[3]
            let pkg = GPackage(name: name, version: version, system: self, status: .available)
            if bottle != "" {
                desc = "🍶\(desc)"
            }
            if desc != "" {
                pkg.description = desc
            }
            if repo != nil {
                pkg.categories = (repo as NSString).lastPathComponent
                pkg.repo = repo
            }
            items.append(pkg)
            self[name] = pkg
        }

        if (defaults("HomebrewMainTaps") as? Bool ?? false) == true {
            let brewCaskCommandAvailable = "\(prefix)/Homebrew/Library/Homebrew/cmd/cask.rb".exists
            outputLines = output("\(cmd) search \"\"").components(separatedBy: CharacterSet.whitespacesAndNewlines)
            for line in outputLines {
                if !line.contains("/") {
                    continue
                }
                let tokens = line.split("/")
                let name = tokens.last!
                if tokens[1] == "cask" && brewCaskCommandAvailable {
                    continue
                }
                if self[name] != nil {
                    continue
                }
                let repo = "\(tokens[0])/\(tokens[1])"
                let pkg = GPackage(name: name, version: "", system: self, status: .available)
                pkg.categories = tokens[1]
                pkg.repo = repo
                pkg.description = repo
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

        var outputLines = output("\(cmd) list --versions").split("\n")
        outputLines.removeLast()
        let itemsCount = items.count
        let notInactiveItems = items.filter { $0.status != .inactive}
        if itemsCount != notInactiveItems.count {
            items = notInactiveItems
            self.agent.appDelegate!.removeItems({ $0.status == .inactive && $0.system === self}) // TODO: ugly
        }
        var status: GStatus
        for pkg in items as! [GPackage] {
            status = pkg.status
            pkg.installed = nil
            if status != .updated && status != .new {
                pkg.status = .available
            }
        }
        self.outdated() // update status
        for line in outputLines {
            var components = line.split()
            let name = components[0]
            if name == "Error:" {
                return pkgs
            }
            components.remove(at: 0)
            components.sort()
            let versionCount = components.count
            let version = components.last!
            var pkg: GPackage! = self[name]
            let latestVersion: String = (pkg == nil) ? "" : pkg.version
            if versionCount > 1 {
                for i in 0..<versionCount - 1  {
                    let inactivePkg = GPackage(name: name, version: latestVersion, system: self, status: .inactive)
                    inactivePkg.installed = components[i]
                    items.append(inactivePkg)
                    self.agent.appDelegate!.addItem(inactivePkg) // TODO: ugly
                    pkgs.append(inactivePkg)
                }
            }
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: .upToDate)
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

        var outputLines = output("\(cmd) outdated").split("\n")
        outputLines.removeLast()
        for line in outputLines {
            let components = line.split()
            var name = components[0]
            if name == "Error:" {
                return pkgs
            }
            if name.contains("/") {
                name = (name as NSString).lastPathComponent
            }
            var pkg = self[name]
            let latestVersion: String = (pkg == nil) ? "" : pkg!.version
            // let version = components[1] // TODO: strangely, output contains only name
            let version = (pkg == nil) ? "..." : pkg!.installed
            if pkg == nil {
                pkg = GPackage(name: name, version: latestVersion, system: self, status: .outdated)
                self[name] = pkg
            } else {
                pkg!.status = .outdated
            }
            pkg!.installed = version
            pkgs.append(pkg!)
        }
        return pkgs
    }


    override func inactive() -> [GPackage] {

        if self.isHidden {
            return items.filter { $0.status == .inactive} as! [GPackage]
        }
        var pkgs = [GPackage]()
        pkgs.reserveCapacity(50000)

        if mode == .online {
            return pkgs
        }

        for pkg in installed() {
            if pkg.status == .inactive {
                pkgs.append(pkg)
            }
        }
        return pkgs
    }

    override func info(_ item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) info \(item.name)")
        } else {
            return super.info(item)
        }
    }

    override func home(_ item: GItem) -> String {
        var page = ""
        if self.isHidden {
            for line in cat(item).split("\n") {
                let idx = line.index("homepage")
                if idx != NSNotFound {
                    page = line.substring(from: idx + 8).trim()
                    if page.contains("http") {
                        return page.trim("'\"")
                    }
                }
            }
        } else {
            let outputLines = output("\(cmd) info \(item.name)").split("\n")
            page = outputLines[2]
            if !page.hasPrefix("http") { // desc line is missign
                page = outputLines[1]
            }
            return page
        }
        return log(item)
    }

    override func log(_ item: GItem) -> String {
        var path: String
        if (item as! GPackage).repo == nil {
            path = "Homebrew/homebrew-core/commits/master/Formula"
        } else {
            let tokens = (item as! GPackage).repo!.split("/")
            let user = tokens[0]
            path = "\(user)/homebrew-\(tokens[1])/commits/master"
            if "\(prefix)/Homebrew/Library/Taps/\(user)/homebrew-\(tokens[1])/Formula".exists {
                path += "/Formula"
            }
        }
        return "http://github.com/\(path)/\(item.name).rb"
    }

    override func contents(_ item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) list -v \(item.name)")
        } else {
            return ""
        }
    }

    override func cat(_ item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) cat \(item.name)")
        } else {
            return (try? String(contentsOfFile: "\(prefix)_off/Library/Homebrew/Formula/\(item.name).rb", encoding: .utf8)) ?? ""
        }
    }

    override func deps(_ item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) deps -n \(item.name)")
        } else {
            return "[Cannot compute the dependencies now]"
        }
    }

    override func dependents(_ item: GItem) -> String {
        if !self.isHidden {
            return output("\(cmd) uses --installed \(item.name)")
        } else {
            return ""
        }
    }

    override func options(_ pkg: GPackage) -> String! {
        var options: String! = nil
        let outputLines = output("\(cmd) options \(pkg.name)").split("\n")
        if outputLines.count > 1 {
            let optionLines = outputLines.filter { $0.hasPrefix("--") }
            options = optionLines.join().replace("--", "")
        }
        return options
    }


    override func installCmd(_ pkg: GPackage) -> String {
        var options: String! = pkg.markedOptions
        if options == nil {
            options = ""
        } else {
            options = "--" + options!.replace(" ", " --")
        }
        return "\(cmd) install \(options!) \(pkg.name)".replace("  ", " ")
    }


    override func uninstallCmd(_ pkg: GPackage) -> String {
        if pkg.status == .inactive {
            return self.cleanCmd(pkg)
        } else { // TODO: manage --force flag
            return "\(cmd) remove --force \(pkg.name)"
        }
    }

    override func deactivateCmd(_ pkg: GPackage) -> String {
        return "\(cmd) unlink \(pkg.name)"
    }

    override func upgradeCmd(_ pkg: GPackage) -> String {
        return "\(cmd) upgrade \(pkg.name)"
    }


    override func cleanCmd(_ pkg: GPackage) -> String {
        return "\(cmd) cleanup --force \(pkg.name)"
    }


    override var updateCmd: String! {
        get {
            return "\(cmd) update"
        }
    }

    override var hideCmd: String! {
        get {
            return "for dir in bin etc include lib opt share; do sudo mv \(prefix)/\"$dir\"{,_off}; done"
        }
    }

    override var unhideCmd: String! {
        get {
            return "for dir in bin etc include lib opt share; do sudo mv \(prefix)/\"$dir\"{_off,}; done"
        }
    }

    class var setupCmd: String! {
        return "ruby -e \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)\"; /usr/local/bin/brew update"
    }

    class var removeCmd: String! {
        return "ruby -e \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/uninstall)\""
    }
    
    override func verbosifiedCmd(_ command: String) -> String {
        var tokens = command.split()
        tokens.insert("-v", at: 2)
        return tokens.join()
    }
    
}
