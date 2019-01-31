import Foundation

class G {

    class func OSVersion() -> String {
        let versionString = ProcessInfo.processInfo.operatingSystemVersionString
        return versionString.split()[1]
    }
}
