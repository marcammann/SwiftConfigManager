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

public protocol ConfigManagerKeyType {
    associatedtype ValueType
    
    var keyPath: String { get set }
    var defaultValue: ValueType { get set }
    init(_ key: String, _ defaultValue: ValueType)
}


public extension ConfigManagerKeyType where ValueType: ExpressibleByNilLiteral {
    public init(_ key: String) {
        self.init(key, nil)
    }
}


public struct ConfigManagerKey<T>: ConfigManagerKeyType {
    public var keyPath: String
    public var defaultValue: ValueType
    
    public typealias ValueType = T
    
    public init(_ key: String, _ aDefaultValue: ValueType) {
        keyPath = key
        defaultValue = aDefaultValue
    }
}


public typealias Payload = [String: AnyObject]

public class ConfigManager {
    var configFileEntryPoints: [URL]?
    
    var configuration: Payload?
    
    var overrideEnvironment: String?
    lazy var configEnvironment: String? = {
        let env = ProcessInfo().environment
        if let value = self.overrideEnvironment {
            return value
        } else if let value = env[ConfigManagerStringConstants.EnvKey] {
            return value
        } else if let bundleInfoDict = Bundle.main.infoDictionary, let value = bundleInfoDict["ConfigManagerEnv"] as? String {
            return value
        }
        
        return nil
    }()
    
    //
    // Note: Preferred way of passing a config path is like this:
    // NSBundle.pathForResource("fileName", ofType: "yaml", inDirectory: "some/subdirectory")
    public init(basePath baseConfigPath: String?, environment: String? = nil) {
        guard let defaultConfigPath = baseConfigPath else {
            return
        }
        
        overrideEnvironment = environment
        
        setupConfiguration(defaultConfigPath)
    }
    
    public subscript(keyPath: String) -> Any? {
        let splitKeyPath: [Substring] = keyPath.split(separator: ".")
        var subConfig: Any? = self.configuration
        splitKeyPath.forEach { (key) in
            if let value = subConfig as? [String: AnyObject] {
                subConfig = value[String(key)]
            } else {
                subConfig = nil
            }
        }

        return subConfig
    }
    
    internal func setupConfiguration(_ defaultConfigPath: String) {
        configFileEntryPoints = configFilePaths(defaultPath: defaultConfigPath)
        
        guard let _ = configFileEntryPoints else {
            configuration = nil
            return
        }
        
        configuration = [String: AnyObject]()
        for configFilePath in configFileEntryPoints!.reversed() {
            do {
                if try configFilePath.checkResourceIsReachable(), let configurationContents = readConfiguration(configFilePath) {
                    configuration?.updateWith(configurationContents)
                }
            } catch {
                continue
            }
        }
        
    }
    
    static func configFilePaths(defaultPath: String, configEnvironment: String?) -> [URL]? {
        let defaultUrlPath = URL.init(fileURLWithPath: defaultPath)
        var paths = [defaultUrlPath]

        let filename = defaultUrlPath.lastPathComponent
        if filename == "" {
            return paths
        }

        let folderPath = defaultUrlPath.deletingLastPathComponent()
        let privateDefaultUrlPath = folderPath.appendingPathComponent(ConfigManagerStringConstants.PrivateFilePrefix + filename)
        paths.insert(privateDefaultUrlPath, at: 0)

        // If there is no environment from either override or config, just
        // return the default paths.
        guard let env = configEnvironment else {
            return paths
        }
        
        // Now we inject the environment into the path.
        let fileExtension = defaultUrlPath.pathExtension
        var envSpecificFilePath = defaultUrlPath.deletingPathExtension()
        envSpecificFilePath = envSpecificFilePath.appendingPathExtension(env)
        envSpecificFilePath = envSpecificFilePath.appendingPathExtension(fileExtension)

        // Insert at index 1 because the private config file overrides
        paths.insert(envSpecificFilePath, at: 1)
        
        return paths
    }
    
    internal func configFilePaths(defaultPath: String) -> [URL]? {
        return ConfigManager.configFilePaths(defaultPath: defaultPath, configEnvironment: configEnvironment)
    }
    
    static func readConfiguration(path: URL) -> Payload? {
        let contents: String?
        // Read contents, otherwise return nil.
        do {
            contents = try String(contentsOfFile: path.path, encoding: String.Encoding.utf8)
        } catch _ {
            // Log some errors here.
            return nil
        }

        guard let data = contents?.data(using: String.Encoding.utf8) else {
            return nil
        }
        
        // Read as JSON
        // Enhancement: support other formats
        let configurationPayload: Payload?
        do {
            configurationPayload = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions()) as? Payload
        } catch _ {
            return nil
        }

        let folderPath = path.deletingLastPathComponent()
        // Check if there is a key to extend another config file. If so, extend recursively.
        if let extendedContentsFilename = configurationPayload?[ConfigManagerStringConstants.ConfigurationExtensionKey] as? String,
            let _ = configurationPayload
        {
            var extendedConfigurationPayload = readConfiguration(path: folderPath.appendingPathComponent(extendedContentsFilename))
            extendedConfigurationPayload?.updateWith(configurationPayload!)
            
            return extendedConfigurationPayload
        }
        
        return configurationPayload
    }
    
    internal func readConfiguration(_ path: URL) -> Payload? {
        return ConfigManager.readConfiguration(path: path)
    }
}


public extension ConfigManager {
    public subscript(key: ConfigManagerKey<Any?>) -> Any? {
        get { return self[key.keyPath] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<String?>) -> String? {
        get { return self[key.keyPath] as? String ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<URL?>) -> URL? {
        get {
            guard let rawValue = self[key.keyPath] as? String else {
                return key.defaultValue
            }
            
            return URL(string: rawValue)
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
    public subscript(key: ConfigManagerKey<Any>) -> Any {
        get { return self[key.keyPath] ?? key.defaultValue }
    }
    
    public subscript(key: ConfigManagerKey<String>) -> String {
        get { return self[key.keyPath] as? String ?? key.defaultValue }
    }
    
    
    public subscript(key: ConfigManagerKey<URL>) -> URL {
        get {
            guard let rawValue = self[key.keyPath] as? String else {
                return key.defaultValue
            }
            
            return URL(string: rawValue)!
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
