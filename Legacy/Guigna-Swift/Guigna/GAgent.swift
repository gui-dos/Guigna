import Foundation

class GAgent: NSObject {

    var appDelegate: GAppDelegate?

    @discardableResult
    func output(_ command: String) -> String {

        let task = Task()
        let tokens = command.components(separatedBy: " ")
        let command = tokens[0]
        var args: [String] = []
        if tokens.count > 1 {
            let components = tokens[1...tokens.count-1]
            for component: String in components {
                if component == "\"\"" {
                    args.append("")
                } else {
                    args.append(component.replacingOccurrences(of: "__", with: " "))
                }
            }
        }
        task.launchPath = command
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        let errorPipe = Pipe()
        task.standardError = errorPipe
        task.standardInput = Pipe()
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output
    }


    func nodes(URL url: String, XPath xpath: String) -> [XMLNode] {
        // FIXME: doesn't allow xpath on childnodes
        var page = try? String(contentsOf: URL(string: url)!, encoding: .utf8)
        if page == nil {
            page = try? String(contentsOf: URL(string: url)!, encoding: .isoLatin1)
        }
        let data: Data = page!.data(using: .utf8)!
        var nodes = [XMLNode]()
        do {
            let doc = try XMLDocument(data: data, options: Int(NSXMLDocumentTidyHTML))
            nodes = try doc.rootElement()!.nodes(forXPath: xpath)
        } catch {
        }
        return nodes
    }
}
