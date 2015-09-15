import Foundation

class GAgent: NSObject {
    
    var appDelegate: GAppDelegate?
    var processID: CInt?
    
    func output(command: String) -> String {
        
        let task = NSTask()
        let tokens = command.componentsSeparatedByString(" ")
        let command = tokens[0]
        var args: [String] = []
        if tokens.count > 1 {
            let components = tokens[1...tokens.count-1]
            for component: String in components {
                if component == "\"\"" {
                    args.append("")
                } else {
                    args.append(component.stringByReplacingOccurrencesOfString("__", withString: " "))
                }
            }
        }
        task.launchPath = command
        task.arguments = args
        let pipe = NSPipe()
        task.standardOutput = pipe
        let errorPipe = NSPipe()
        task.standardError = errorPipe
        task.standardInput = NSPipe()
        task.launch()
        processID = task.processIdentifier
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        processID = nil
        // int status = [task terminationStatus]; // TODO
        let output = NSString(data: data, encoding: NSUTF8StringEncoding) ?? ""
        // Uncomment to debug:
        // NSData *errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
        // NSString __autoreleasing *errorOutput = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        return output as String
    }
    
    
    func nodes(URL url: String, XPath xpath: String) -> [NSXMLNode] {
        // FIXME: doesn't allow xpath on childnodes
        var error: NSError? = nil
        var page: NSMutableString?
        do {
            page = try NSMutableString(contentsOfURL: NSURL(string: url)!, encoding: NSUTF8StringEncoding)
        } catch var error1 as NSError {
            error = error1
            page = nil
        }
        if page == nil {
            do {
                page = try NSMutableString(contentsOfURL: NSURL(string: url)!, encoding: NSISOLatin1StringEncoding)
            } catch var error1 as NSError {
                error = error1
                page = nil
            }
        }
        var data: NSData = page!.dataUsingEncoding(NSUTF8StringEncoding)!
        var nodes = [NSXMLNode]()
        do {
            let doc = try NSXMLDocument(data: data, options: Int(NSXMLDocumentTidyHTML))
            nodes = doc.rootElement()!.nodesForXPath(xpath)
        } catch var error1 as NSError {
            error = error1
        }
        return nodes
    }
}
