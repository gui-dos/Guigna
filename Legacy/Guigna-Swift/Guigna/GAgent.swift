import Foundation
import Security

class GAgent: NSObject {

    var appDelegate: GAppDelegate?

    /// - parameter command:
    ///   (replace spaces with `__` when passing multi-word strings as arguments)
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

    /// Ported from: [STPrivilegedTask](https://github.com/sveinbjornt/STPrivilegedTask)
    @discardableResult
    func sudo(_ cmd: String) -> String {
        var err: OSStatus = noErr
        var components = cmd.components(separatedBy: " ")
        var toolPath = components.remove(at: 0).cString(using: .utf8)!
        let cArgs = components.map { $0.cString(using: .utf8)! }
        var args = [UnsafePointer<CChar>?]()
        for cArg in cArgs {
            args.append(UnsafePointer<CChar>(cArg))
        }
        args.append(nil)
        let argsPointer = UnsafePointer<UnsafePointer<CChar>>(args)
        var authorizationRef: AuthorizationRef? = nil
        var items = AuthorizationItem(name: kAuthorizationRightExecute, valueLength: toolPath.count, value: &toolPath, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &items)
        let flags: AuthorizationFlags = [.interactionAllowed, .preAuthorize, .extendRights]
        var outputFile = FILE()
        var outputFilePointer = withUnsafeMutablePointer(&outputFile) { UnsafeMutablePointer<FILE>($0) }
        var outputFilePointerPointer = withUnsafeMutablePointer(&outputFilePointer) {UnsafeMutablePointer<UnsafeMutablePointer<FILE>>($0)}
        err = AuthorizationCreate(nil, nil, [], &authorizationRef)
        //    if err != errAuthorizationSuccess {
        //    }
        err = AuthorizationCopyRights(authorizationRef!, &rights, nil, flags, nil)
        //    if err != errAuthorizationSuccess {
        //    }
        let RTLD_DEFAULT = UnsafeMutablePointer<Void>(bitPattern: -2)
        var authExecuteWithPrivsFn: @convention(c) (AuthorizationRef, UnsafePointer<CChar>, AuthorizationFlags, UnsafePointer<UnsafePointer<CChar>>?,  UnsafeMutablePointer<UnsafeMutablePointer<FILE>>?) -> OSStatus
        authExecuteWithPrivsFn = unsafeBitCast(dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges"), to: authExecuteWithPrivsFn.dynamicType)
        err = authExecuteWithPrivsFn(authorizationRef!, &toolPath, [], argsPointer, outputFilePointerPointer)
        //    if err != errAuthorizationSuccess {
        //    }
        AuthorizationFree(authorizationRef!, [])
        let outputFileHandle = FileHandle(fileDescriptor: fileno(outputFilePointer), closeOnDealloc: true)
        // FIXME: always return 0
        let processIdentifier: pid_t = fcntl(fileno(outputFilePointer), F_GETOWN, 0)
        var terminationStatus: Int32 = 0
        waitpid(processIdentifier, &terminationStatus, 0)
        let outputData = outputFileHandle.readDataToEndOfFile()
        let outputString = String(data: outputData, encoding: .utf8)!
        return outputString
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
            let doc = try XMLDocument(data: data, options: Int(XMLNodeOptions.documentTidyHTML.rawValue))
            nodes = try doc.rootElement()!.nodes(forXPath: xpath)
        } catch {
        }
        return nodes
    }
}
