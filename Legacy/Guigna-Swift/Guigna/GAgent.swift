import Foundation

class GAgent: NSObject {

    var appDelegate: GAppDelegate?
    var processID: CInt?

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
        processID = task.processIdentifier
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        processID = nil
        // int status = [task terminationStatus]; // TODO
        let output = String(data: data, encoding: .utf8) ?? ""
        // Uncomment to debug:
        // NSData *errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
        // NSString __autoreleasing *errorOutput = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        return output as String
    }


    func nodes(URL url: String, XPath xpath: String) -> [XMLNode] {
        // FIXME: doesn't allow xpath on childnodes
        var error: NSError? = nil
        var page: String?
        do {
            page = try String(contentsOf: URL(string: url)!, encoding: String.Encoding.utf8)
        } catch let error1 as NSError {
            error = error1
            page = nil
        }
        if page == nil {
            do {
                page = try String(contentsOf: URL(string: url)!, encoding: .isoLatin1)
            } catch let error1 as NSError {
                error = error1
                page = nil
            }
        }
        let data: Data = page!.data(using: .utf8)!
        var nodes = [XMLNode]()
        do {
            let doc = try XMLDocument(data: data, options: Int(NSXMLDocumentTidyHTML))
            nodes = try doc.rootElement()!.nodes(forXPath: xpath)
        } catch let error1 as NSError {
            error = error1
        }
        return nodes
    }
}
