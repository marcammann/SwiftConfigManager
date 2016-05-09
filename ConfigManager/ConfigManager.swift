//
//  ConfigManager.swift
//  ConfigManager
//
//  Created by Marc Ammann on 5/2/16.
//  Copyright © 2016 Codesofa. All rights reserved.
//

import Foundation

struct ConfigManagerStringConstants {
    static let EnvKey = "CONFIG_MANAGER_ENV"
    static let PrivateFilePrefix = "."
    static let ConfigurationExtensionKey = "!extends"
}

protocol ConfigManagerKeyType {
    associatedtype ValueType
    
    var keyPath: String { get set }
    var defaultValue: ValueType { get set }
    init(_ key: String, _ defaultValue: ValueType)
}


extension ConfigManagerKeyType where ValueType: NilLiteralConvertible {
    init(_ key: String) {
        self.init(key, nil)
    }
}


public struct ConfigManagerKey<T>: ConfigManagerKeyType {
    var keyPath: String
    var defaultValue: ValueType
    
    typealias ValueType = T
    
    init(_ key: String, _ aDefaultValue: ValueType) {
        keyPath = key
        defaultValue = aDefaultValue
    }
}


public typealias Payload = [String: AnyObject]

public class ConfigManager {
    var configFileEntryPoints: [NSURL]?
    
    var configuration: Payload?
    
    var overrideEnvironment: String?
    lazy var configEnvironment: String? = {
        let env = NSProcessInfo.processInfo().environment
        if let value = self.overrideEnvironment {
            return value
        } else if let value = env[ConfigManagerStringConstants.EnvKey] {
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
    
    subscript(keyPath: String) -> AnyObject? {
        let value: AnyObject? = keyPath.characters.split(".").map(String.init).reduce(configuration) { (c, key) -> AnyObject? in
            if let subConfig = c as? Dictionary<String, AnyObject> {
                return subConfig[key]
            }
            
            return nil
        }
        
        return value
    }
    
    internal func setupConfiguration(defaultConfigPath: String) {
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
        if let privateDefaultUrlPath = folderPath?.URLByAppendingPathComponent(ConfigManagerStringConstants.PrivateFilePrefix + filename) {
            paths.insert(privateDefaultUrlPath, atIndex: 0)
        }
        
        return paths
    }
    
    internal func configFilePaths(defaultPath: String) -> [NSURL]? {
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
        if let extendedContentsFilename = configurationPayload?[ConfigManagerStringConstants.ConfigurationExtensionKey] as? String,
            folderPath = path.URLByDeletingLastPathComponent,
            _ = configurationPayload
        {
            var extendedConfigurationPayload = readConfiguration(folderPath.URLByAppendingPathComponent(extendedContentsFilename))
            extendedConfigurationPayload?.updateWith(configurationPayload!)
            
            return extendedConfigurationPayload
        }
        
        return configurationPayload
    }
    
    internal func readConfiguration(path: NSURL) -> Payload? {
        return ConfigManager.readConfiguration(path)
    }
}


public extension ConfigManager {
    public subscript(key: ConfigManagerKey<AnyObject?>) -> AnyObject? {
        get { return self[key.keyPath] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<String?>) -> String? {
        get { return self[key.keyPath] as? String ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<NSURL?>) -> NSURL? {
        get {
            guard let rawValue = self[key.keyPath] as? String else {
                return key.defaultValue
            }
            
            return NSURL(string: rawValue)
        }
    }
    
    public subscript(key: ConfigManagerKey<Int?>) -> Int? {
        get { return self[key.keyPath] as? Int ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<Double?>) -> Double? {
        get { return self[key.keyPath] as? Double ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<Bool?>) -> Bool? {
        get { return self[key.keyPath] as? Bool ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<Payload?>) -> Payload? {
        get { return self[key.keyPath] as? Payload ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<[AnyObject]?>) -> [AnyObject]? {
        get { return self[key.keyPath] as? [AnyObject] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<[String]?>) -> [String]? {
        get { return self[key.keyPath] as? [String] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<[Int]?>) -> [Int]? {
        get { return self[key.keyPath] as? [Int] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<[Payload]?>) -> [Payload]? {
        get { return self[key.keyPath] as? [Payload] ?? key.defaultValue }
    }
}



public extension ConfigManager {
    public subscript(key: ConfigManagerKey<AnyObject>) -> AnyObject {
        get { return self[key.keyPath] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<String>) -> String {
        get { return self[key.keyPath] as? String ?? key.defaultValue }
    }
    
    
    public subscript(key: ConfigManagerKey<NSURL>) -> NSURL {
        get {
            guard let rawValue = self[key.keyPath] as? String else {
                return key.defaultValue
            }
            
            return NSURL(string: rawValue)!
        }
    }
    
    public subscript(key: ConfigManagerKey<Int>) -> Int {
        get { return self[key.keyPath] as? Int ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<Double>) -> Double {
        get { return self[key.keyPath] as? Double ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<Payload>) -> Payload {
        get { return self[key.keyPath] as? Payload ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<[AnyObject]>) -> [AnyObject] {
        get { return self[key.keyPath] as? [AnyObject] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<[String]>) -> [String] {
        get { return self[key.keyPath] as? [String] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<[Int]>) -> [Int] {
        get { return self[key.keyPath] as? [Int] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<[Payload]>) -> [Payload] {
        get { return self[key.keyPath] as? [Payload] ?? key.defaultValue }
    }
}
