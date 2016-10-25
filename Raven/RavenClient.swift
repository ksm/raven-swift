//
//  RavenClient.swift
//  Raven-Swift
//
//  Created by Tommy Mikalsen on 03.09.14.
//

import Foundation

#if os(iOS) || os(tvOS)
    import UIKit
#endif

let userDefaultsKey = "nl.mixedCase.RavenClient.Exceptions"
let sentryProtocol = "4"
let sentryClient = "raven-swift/0.5.0"

public enum RavenLogLevel: String {
    case Debug = "debug"
    case Info = "info"
    case Warning = "warning"
    case Error = "error"
    case Fatal = "fatal"
}

private var _RavenClientSharedInstance : RavenClient?

open class RavenClient : NSObject {
    //MARK: - Properties
    open var extra: [String: Any]
    open var tags: [String: Any]
    open var user: [String: Any]?
    open let logger: String?

    internal let config: RavenConfig?

    fileprivate var dateFormatter : DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return dateFormatter
    }


    //MARK: - Init


    /**
    Get the shared RavenClient instance
    */
    open class var sharedClient: RavenClient? {
        return _RavenClientSharedInstance
    }


    /**
    Initialize the RavenClient

    :param: config  RavenConfig object
    :param: extra  extra data that will be sent with logs
    :param: tags  extra tags that will be added to logs
    :param: logger  Name of the logger
    */
    public init(config: RavenConfig?, extra: [String : Any], tags: [String: Any], logger: String?) {
        self.config = config
        self.extra = extra
        self.tags = tags
        self.logger = logger

        super.init()
        setDefaultTags()
        
        if (_RavenClientSharedInstance == nil) {
            _RavenClientSharedInstance = self
        }
    }


    /**
    Initialize the RavenClient

    :param: config  RavenConfig object
    :param: extra  extra data that will be sent with logs
    :param: tags  extra tags that will be added to logs
    */
    public convenience init(config: RavenConfig, extra: [String: Any], tags: [String: Any]) {
        self.init(config: config, extra: extra, tags: tags, logger: nil)
    }


    /**
    Initialize the RavenClient

    :param: config  RavenConfig object
    :param: extra  extra data that will be sent with logs
    */
    public convenience init(config: RavenConfig, extra: [String: Any]) {
        self.init(config: config, extra: extra, tags: [:], logger: nil)
    }


    /**
    Initialize the RavenClient

    :param: config  RavenConfig object
    */
    public convenience init(config: RavenConfig) {
        self.init(config: config, extra: [:], tags: [:], logger: nil)
    }


    /**
    Initialize a RavenClient from the DSN string

    :param: extra  extra data that will be sent with logs
    :param: tags  extra tags that will be added to logs
    :param: logger  Name of the logger

    :returns: The RavenClient instance
    */
    open class func clientWithDSN(_ DSN: String, extra: [String: Any], tags: [String: Any], logger: String?) -> RavenClient? {
        if let config = RavenConfig(DSN: DSN) {
            let client = RavenClient(config: config, extra: extra, tags: tags, logger: logger)
            
            return client
        }
        else {
            guard !DSN.isEmpty else {
                print("Empty DSN. Client will only print JSON locally")
                let client = RavenClient(config: nil, extra: extra, tags: tags, logger: logger)
                
                return client
            }
            
            print("Invalid DSN: \(DSN)!")
            return nil
        }
    }


    /**
    Initialize a RavenClient from the DSN string

    :param: extra  extra data that will be sent with logs
    :param: tags  extra tags that will be added to logs

    :returns: The RavenClient instance
    */
    open class func clientWithDSN(_ DSN: String, extra: [String: Any], tags: [String: Any]) -> RavenClient? {
        return RavenClient.clientWithDSN(DSN, extra: extra, tags: tags, logger: nil)
    }


    /**
    Initialize a RavenClient from the DSN string

    :param: extra  extra data that will be sent with logs

    :returns: The RavenClient instance
    */
    open class func clientWithDSN(_ DSN: String, extra: [String: Any]) -> RavenClient? {
        return RavenClient.clientWithDSN(DSN, extra: extra, tags: [:])
    }


    /**
    Initialize a RavenClient from the DSN string

    :returns: The RavenClient instance
    */
    open class func clientWithDSN(_ DSN: String) -> RavenClient? {
        return RavenClient.clientWithDSN(DSN, extra: [:])
    }


    //MARK: - Messages


    /**
    Capture a message

    :param: message  The message to be logged
    */
    open func captureMessage(_ message : String, method: String? = #function , file: String? = #file, line: Int = #line) {
        self.captureMessage(message, level: .Info, additionalExtra:[:], additionalTags:[:], method:method, file:file, line:line)
    }


    /**
    Capture a message

    :param: message  The message to be logged
    :param: level  log level
    */
    open func captureMessage(_ message: String, level: RavenLogLevel, method: String? = #function , file: String? = #file, line: Int = #line){
        self.captureMessage(message, level: level, additionalExtra:[:], additionalTags:[:], method:method, file:file, line:line)
    }


    /**
    Capture a message

    :param: message  The message to be logged
    :param: level  log level
    :param: additionalExtra  Additional data that will be sent with the log
    :param: additionalTags  Additional tags that will be sent with the log
    */
    open func captureMessage(_ message: String, level: RavenLogLevel, additionalExtra:[String: Any], additionalTags: [String: Any], method:String? = #function, file:String? = #file, line:Int = #line) {
        var stacktrace : [Any] = []
        var culprit : String = ""
        
        if (method != nil && file != nil && line > 0) {
            let filename = (file! as NSString).lastPathComponent;
            let frame = ["filename" : filename, "function" : method!, "lineno" : line] as [String : Any]
            stacktrace = [frame as Any]
            culprit = "\(method!) in \(filename)"
        }

        let data = self.prepareDictionaryForMessage(message, level:level, additionalExtra:additionalExtra, additionalTags:additionalTags, culprit:culprit, stacktrace:stacktrace, exception:[:])

        self.sendDictionary(data)
    }


    //MARK: - Error

    /**
    Capture an error

    :param: error  The error to capture
    */
    open func captureError(_ error : NSError, method: String? = #function, file: String? = #file, line: Int = #line) {
        self.captureMessage("\(error)", level: .Error, method: method, file: file, line: line )
    }


    //MARK: - ErrorType

    /**
    Capture an error that conforms the ErrorType protocol

    :param: error  The error to capture
    */
    open func captureError<E>(_ error: E, method: String? = #function, file: String? = #file, line: Int = #line) where E:Error, E:ExpressibleByStringLiteral {
        self.captureMessage("\(error)", level: .Error, method: method, file: file, line: line )
    }


    //MARK: - Exception


    /**
    Capture an exception. Automatically sends to the server

    :param: exception  The exception to be captured.
    */
    open func captureException(_ exception: NSException) {
        self.captureException(exception, sendNow:true)
    }


    /**
    Capture an uncaught exception. Does not automatically send to the server

    :param: exception  The exception to be captured.
    */
    open func captureUncaughtException(_ exception: NSException) {
        self.captureException(exception, sendNow: false)
    }


    /**
    Capture an exception

    :param: exception  The exception to be captured.
    :param: additionalExtra  Additional data that will be sent with the log
    :param: additionalTags  Additional tags that will be sent with the log
    :param: sendNow  Control whether the exception is sent to the server now, or when the app is next opened
    */
    open func captureException(_ exception:NSException, additionalExtra:[String: Any], additionalTags: [String: Any], sendNow:Bool) {
        let message = "\(exception.name): \(exception.reason ?? "")"
        let exceptionDict = ["type": exception.name, "value": exception.reason ?? ""] as [String : Any]

        let callStack = exception.callStackSymbols

        var stacktrace = [[String:String]]()

        if (!callStack.isEmpty) {
            for call in callStack {
                stacktrace.append(["function": call])
            }
        }

        let data = self.prepareDictionaryForMessage(message, level: .Fatal, additionalExtra: additionalExtra, additionalTags: additionalTags, culprit: nil, stacktrace: stacktrace as [Any], exception: exceptionDict as! [String : String])

        if let JSON = self.encodeJSON(data) {
            if (!sendNow) {
                // We can't send this exception to Sentry now, e.g. because the app is killed before the
                // connection can be made. So, save it into NSUserDefaults.
                let JSONString = NSString(data: JSON, encoding: String.Encoding.utf8.rawValue)
                var reports = UserDefaults.standard.object(forKey: userDefaultsKey) as? [Any]
                if (reports != nil) {
                    reports!.append(JSONString!)
                } else {
                    reports = [JSONString!]
                }

                UserDefaults.standard.set(reports, forKey:userDefaultsKey)
                UserDefaults.standard.synchronize()
            } else {
                self.sendJSON(JSON)
            }
        }
    }


    /**
    Capture an exception

    :param: exception  The exception to be captured.
    :param: sendNow  Control whether the exception is sent to the server now, or when the app is next opened
    */
    open func captureException(_ exception: NSException, method:String? = #function, file:String? = #file, line:Int = #line, sendNow:Bool = false) {
        let message = "\(exception.name): \(exception.reason ?? "")"
        let exceptionDict = ["type": exception.name, "value": exception.reason ?? ""] as [String : Any]

        var stacktrace = [[String:Any]]()

        if (method != nil && file != nil && line > 0) {
            var frame = [String: Any]()
            frame = ["filename" : (file! as NSString).lastPathComponent as Any, "function" : method! as Any, "lineno" : line as Any]
            stacktrace = [frame]
        }

        let callStack = exception.callStackSymbols

        for call in callStack {
            stacktrace.append(["function": call as Any])
        }

        let data = self.prepareDictionaryForMessage(message, level: .Fatal, additionalExtra: [:], additionalTags: [:], culprit: nil, stacktrace: stacktrace as [Any], exception: exceptionDict as! [String : String])

        if let JSON = self.encodeJSON(data as Any) {
            if (!sendNow) {
                // We can't send this exception to Sentry now, e.g. because the app is killed before the
                // connection can be made. So, save the JSON payload into NSUserDefaults.
                let JSONString = NSString(data: JSON, encoding: String.Encoding.utf8.rawValue)
                var reports : [Any]? = UserDefaults.standard.array(forKey: userDefaultsKey) as [Any]?
                if (reports != nil) {
                    reports!.append(JSONString!)
                } else {
                    reports = [JSONString!]
                }
                UserDefaults.standard.set(reports, forKey:userDefaultsKey)
                UserDefaults.standard.synchronize()
            } else {
                self.sendJSON(JSON)
            }
        }
    }

    //MARK: - Internal methods
    internal func setDefaultTags() {
        if tags["Build version"] == nil {
            if let buildVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] {
                tags["Build version"] = buildVersion
            }
        }

        #if os(iOS) || os(tvOS)
            if (tags["OS version"] == nil) {
                tags["OS version"] = UIDevice.current.systemVersion
            }

            if (tags["Device model"] == nil) {
                tags["Device model"] = UIDevice.current.model
            }
        #endif

    }

    internal func sendDictionary(_ dict: [String: Any]) {
        let JSON = self.encodeJSON(dict)
        self.sendJSON(JSON)
    }

    internal func generateUUID() -> String {
        let uuid = UUID().uuidString
        let res = uuid.replacingOccurrences(of: "-", with: "", options: NSString.CompareOptions.literal, range: nil)
        return res
    }

    fileprivate func prepareDictionaryForMessage(_ message: String,
        level: RavenLogLevel,
        additionalExtra: [String : Any],
        additionalTags: [String : Any],
        culprit:String?,
        stacktrace:[Any],
        exception:[String : String]) -> [String: Any]
    {

        let stacktraceDict : [String : [Any]] = ["frames": stacktrace]

        var extra = self.extra
        for entry in additionalExtra {
            extra[entry.0] = entry.1
        }

        var tags = self.tags
        for entry in additionalTags {
            tags[entry.0] = entry.1
        }

        let returnDict : [String: Any] = [
            "event_id" : self.generateUUID(),
            "project"   : self.config?.projectId ?? "",
            "timestamp" : self.dateFormatter.string(from: Date()),
            "level"     : level.rawValue,
            "platform"  : "swift",
            "extra"     : extra,
            "tags"      : tags,
            "logger"    : self.logger ?? "",
            "message"   : message,
            "culprit"   : culprit ?? "",
            "stacktrace": stacktraceDict,
            "exception" : exception,
            "user"      : user ?? ""
        ]

        return returnDict
    }

    fileprivate func encodeJSON(_ obj: Any) -> Data? {
        do {
            return try JSONSerialization.data(withJSONObject: obj, options: [])
        } catch _ {
            return nil
        }
    }

    fileprivate func sendJSON(_ JSON: Data?) {
        guard let config = self.config else {
            guard let JSON = JSON, let jsonString = String(data: JSON, encoding: String.Encoding.utf8) else {
                print("Could not print JSON using UTF8 encoding")
                return
            }
            
            print(jsonString)
            return
        }
        
        guard let publicKey = config.publicKey, let secretKey = config.secretKey else {
            print("Cannot send JSON as no private and/or secret key found")
            return
        }

        let header = "Sentry sentry_version=\(sentryProtocol), sentry_client=\(sentryClient), sentry_timestamp=\(Date.timeIntervalSinceReferenceDate), sentry_key=\(publicKey), sentry_secret=\(secretKey)"

        #if DEBUG
        println(header)
        #endif

        var request = URLRequest(url: config.serverUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(JSON?.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = JSON
        request.setValue("\(header)", forHTTPHeaderField:"X-Sentry-Auth")
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Connection failed! Error - \(error)")
            } else if let response = response {
                #if DEBUG
                    println("Response from Sentry: \(response)")
                #endif
            }
            print("JSON sent to Sentry")
        }
        task.resume()
    }
}
