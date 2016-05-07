//
//  ConfigManager.swift
//  ConfigManager
//
//  Created by Marc Ammann on 5/2/16.
//  Copyright © 2016 Codesofa. All rights reserved.
//

import Foundation
import Yaml

enum ConfigManagerStringConstants: String {
    case EnvKey = "CONFIG_MANAGER_ENV"
    case PrivateFilePrefix = "."
    case ConfigurationExtensionKey = "!extends"
}

typealias Payload = [String: AnyObject]
class ConfigManager {
    var configFileEntryPoints: [NSURL]?
    
    var configuration: Payload?
    
    var overrideEnvironment: String?
    lazy var configEnvironment: String? = {
        let env = NSProcessInfo.processInfo().environment
        if let value = self.overrideEnvironment {
            return value
        } else if let value = env[ConfigManagerStringConstants.EnvKey.rawValue] {
            return value
        }
        
        return nil
    }()
    
    //
    // Note: Preferred way of passing a config path is like this:
    // NSBundle.pathForResource("fileName", ofType: "yaml", inDirectory: "some/subdirectory")
    init(basePath baseConfigPath: String?, environment: String? = nil) {
        guard let defaultConfigPath = baseConfigPath else {
            return
        }
        
        overrideEnvironment = environment
        
        setupConfiguration(defaultConfigPath)
        
    }
    
    func setupConfiguration(defaultConfigPath: String) {
        configFileEntryPoints = configFilePaths(defaultConfigPath)
        
        guard let _ = configFileEntryPoints else {
            configuration = nil
            return
        }
        
        for configFilePath in configFileEntryPoints! {
            var error: NSError?
            if configFilePath.checkResourceIsReachableAndReturnError(&error) {
                configuration = readConfiguration(configFilePath)
                break
            }
        }
        
    }
    
    static func configFilePaths(defaultPath: String, configEnvironment: String?) -> [NSURL]? {
        let defaultUrlPath = NSURL.fileURLWithPath(defaultPath)
        var paths = [defaultUrlPath]

        guard let filename = defaultUrlPath.lastPathComponent else {
            return paths
        }
        
        // If there is no environment from either override or config, just
        // return the default paths.
        guard let env = configEnvironment else {
            return paths
        }
        
        // Now we inject the environment into the path.
        let fileExtension = defaultUrlPath.pathExtension
        var envSpecificFilePath = defaultUrlPath.URLByDeletingPathExtension
        envSpecificFilePath = envSpecificFilePath?.URLByAppendingPathExtension(env)
        if let _ = fileExtension {
            envSpecificFilePath = envSpecificFilePath?.URLByAppendingPathExtension(fileExtension!)
        }
        
        if let _ = envSpecificFilePath {
            paths.insert(envSpecificFilePath!, atIndex: 0)
        }
        
        let folderPath = defaultUrlPath.URLByDeletingLastPathComponent
        if let privateDefaultUrlPath = folderPath?.URLByAppendingPathComponent(ConfigManagerStringConstants.PrivateFilePrefix.rawValue + filename) {
            paths.insert(privateDefaultUrlPath, atIndex: 0)
        }
        
        return paths
    }
    
    func configFilePaths(defaultPath: String) -> [NSURL]? {
        return ConfigManager.configFilePaths(defaultPath, configEnvironment: configEnvironment)
    }
    
    static func readConfiguration(path: NSURL) -> Payload? {
        let contents: String?
        // Read contents, otherwise return nil.
        do {
            contents = try String(contentsOfFile: path.path!, encoding: NSUTF8StringEncoding)
        } catch _ {
            // Log some errors here.
            return nil
        }
        
        guard let data = contents?.dataUsingEncoding(NSUTF8StringEncoding) else {
            return nil
        }
        
        // Read as JSON
        // Enhancement: support other formats
        let configurationPayload: Payload?
        do {
            configurationPayload = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions()) as? Payload
        } catch _ {
            return nil
        }
        
        // Check if there is a key to extend another config file. If so, extend recursively.
        if let extendedContentsFilename = configurationPayload?[ConfigManagerStringConstants.ConfigurationExtensionKey.rawValue] as? String,
            folderPath = path.URLByDeletingLastPathComponent,
            _ = configurationPayload
        {
            var extendedConfigurationPayload = readConfiguration(folderPath.URLByAppendingPathComponent(extendedContentsFilename))
            extendedConfigurationPayload?.updateWith(configurationPayload!)
            
            return extendedConfigurationPayload
        }
        
        return configurationPayload
    }
    
    func readConfiguration(path: NSURL) -> Payload? {
        return ConfigManager.readConfiguration(path)
    }
}
