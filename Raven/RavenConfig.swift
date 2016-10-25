//
//  RavenConfig.swift
//  Raven-Swift
//
//  Created by Tommy Mikalsen on 03.09.14.
//

import Foundation

open class RavenConfig {
    let serverUrl: URL!
    let publicKey: String!
    let secretKey: String!
    let projectId: String!
    
    public init? (DSN : String) {
        if let DSNURL = URL(string: DSN), let host = DSNURL.host {
            var pathComponents = DSNURL.pathComponents
            
            pathComponents.remove(at: 0) // always remove the first slash
            
            if let projectId = pathComponents.last {
                self.projectId = projectId
                
                pathComponents.removeLast() // remove the project id...
                
                var path = pathComponents.joined(separator: "/")  // ...and construct the path again
                
                // Add a slash to the end of the path if there is a path
                if (path != "") {
                    path += "/"
                }
                
                let scheme: String = DSNURL.scheme ?? "http"
                
                var port = (DSNURL as NSURL).port
                if (port == nil) {
                    if (DSNURL.scheme == "https") {
                        port = 443;
                    } else {
                        port = 80;
                    }
                }
                
                //Setup the URL
                serverUrl = URL(string: "\(scheme)://\(host):\(port!)\(path)/api/\(projectId)/store/")
                
                //Set the public and secret keys if the exist
                publicKey = DSNURL.user ?? ""
                secretKey = DSNURL.password ?? ""
                
                return
            }
        }
        
        //The URL couldn't be parsed, so initialize to blank values and return nil
        serverUrl = URL(string: "http://example.com")
        publicKey = ""
        secretKey = ""
        projectId = ""
        
        return nil
    }
}
