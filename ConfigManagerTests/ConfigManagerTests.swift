//
//  ConfigManagerTests.swift
//  ConfigManagerTests
//
//  Created by Marc Ammann on 5/2/16.
//  Copyright © 2016 Codesofa. All rights reserved.
//

import XCTest
@testable import ConfigManager

struct K {
    static let TestKeyValue = ConfigManagerKey<String?>("some.config")
    static let EnvKeyValue = ConfigManagerKey<String?>("some.env")
    static let DefaultKeyValue = ConfigManagerKey<String?>("some.default")
    static let AnotherTestKeyValue = ConfigManagerKey<String?>("another.config")
}


struct SomeConfig {
    let url: String?
    let other: String?
    
    init(configManager: ConfigManager) {
        url = configManager[K.TestKeyValue]
        other = configManager[K.AnotherTestKeyValue]
    }
    
    struct K {
        static let TestKeyValue = ConfigManagerKey<String?>("some.config")
        static let AnotherTestKeyValue = ConfigManagerKey<String>("another.config", "defaultValue")
    }
}


class ConfigManagerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testDictionaryUpdate() {
        var sourceDictA = [
            "a": "testValueA",
            "merge": "mergeValueA",
            "nested": [
                "nestA": "nestedValueA",
                "nestMerge": "nestedMergeValueA"
            ],
            "typeChange": [ "typeChangeArray" ],
        ]
        
        var dictA = sourceDictA
        
        var sourceDictB = [
            "b": "testValueB",
            "merge": "mergeValueB",
            "nested": [
                "nestB": "nestedValueB",
                "nestMerge": "nestedMergeValueB"
            ],
            "typeChange": [ "typeChangeKeyB": "typeChangeValueB" ],
        ]
        
        let dictB = sourceDictB
        
        dictA.updateWith(dictB)
        
        XCTAssertEqual(dictA["a"], sourceDictA["a"])
        XCTAssertEqual(dictA["b"], sourceDictB["b"])
        XCTAssertEqual(dictA["merge"], sourceDictB["merge"])
        XCTAssertEqual((dictA["nested"] as! Dictionary<String, String>)["nestA"], (sourceDictA["nested"] as! Dictionary<String, String>)["nestA"])
        XCTAssertEqual((dictA["nested"] as! Dictionary<String, String>)["nestMerge"], (sourceDictB["nested"] as! Dictionary<String, String>)["nestMerge"])
        XCTAssertEqual(dictA["typeChange"], sourceDictB["typeChange"])
        
    }
    
    func testConfigLoading() {
        let defaultPath = NSBundle(forClass: ConfigManagerTests.self).pathForResource("ConfigManagerTest", ofType: "json", inDirectory: "")
        let privatePath = NSBundle(forClass: ConfigManagerTests.self).pathForResource(".ConfigManagerTest", ofType: "json", inDirectory: "")
        let envSpecificPath = NSBundle(forClass: ConfigManagerTests.self).pathForResource("ConfigManagerTest.TestEnv", ofType: "json", inDirectory: "")
        let configManager = ConfigManager(basePath: defaultPath, environment: "TestEnv")
        
        XCTAssertEqual(configManager.configFileEntryPoints?.count, 3, "Adding an environment should result in 3 possible config files based on the path")
        if let _ = privatePath {
            XCTAssertEqual(configManager.configFileEntryPoints?.first, NSURL.fileURLWithPath(privatePath!))
        }
        
        if let _ = envSpecificPath {
            XCTAssertEqual(configManager.configFileEntryPoints?[1], NSURL.fileURLWithPath(envSpecificPath!))
        }
        
        if let _ = defaultPath {
            XCTAssertEqual(configManager.configFileEntryPoints?[2], NSURL.fileURLWithPath(defaultPath!))
        }
        
    }
    
    func testConfigInheritance() {
        let defaultPath = NSBundle(forClass: ConfigManagerTests.self).pathForResource("InheritanceTestChild", ofType: "json", inDirectory: "")
        let configManager = ConfigManager(basePath: defaultPath, environment: "TestEnv")
        
        XCTAssertNotNil(configManager.configuration)
        XCTAssertNotNil(configManager.configuration!["childKey"])
        XCTAssertEqual(configManager.configuration!["childKey"] as? String, "childValue")
        XCTAssertNotNil(configManager.configuration!["parentKey"])
        XCTAssertEqual(configManager.configuration!["parentKey"] as? String, "parentValue")
        XCTAssertNotNil(configManager.configuration!["mergedKey"])
        XCTAssertEqual(configManager.configuration!["mergedKey"] as? String, "mergedChildValue")
        
        let config = configManager.configuration!
        let childConfigData = ((config["config"] as! Payload)["configKey"] as! Payload)
        
        XCTAssertEqual(childConfigData["childConfigA"] as? String, "configAChildValue")
        XCTAssertEqual(childConfigData["configB"] as! [String], [ "childConfigBValue0", "childConfigBValue1", "childConfigBValue2" ])
        XCTAssertEqual(childConfigData["configA"] as? String, "configAValue")
    }
    
    func testImplicitInheritance() {
        let defaultPath = NSBundle(forClass: ConfigManagerTests.self).pathForResource("ConfigManagerTest", ofType: "json", inDirectory: "")
        let configManager = ConfigManager(basePath: defaultPath, environment: "TestEnv")
        
        configManager["some.config"]
        XCTAssertEqual(configManager[K.TestKeyValue], "valuePrivate")
        XCTAssertEqual(configManager[K.EnvKeyValue], "implicitEnv")
        XCTAssertEqual(configManager[K.DefaultKeyValue], "implicitDefault")
    }
    
    func testKeyAccess() {
        let defaultPath = NSBundle(forClass: ConfigManagerTests.self).pathForResource("ConfigManagerTest", ofType: "json", inDirectory: "")
        let configManager = ConfigManager(basePath: defaultPath, environment: "TestEnv")
        
        configManager["some.config"]
        XCTAssertEqual(configManager[K.TestKeyValue], "valuePrivate")
        
        let cfg = SomeConfig(configManager: configManager)
        XCTAssertEqual(cfg.url, "valuePrivate")
        XCTAssertEqual(cfg.other, "defaultValue")
    }
    
    func testValueTransformation() {
        let defaultPath = NSBundle(forClass: ConfigManagerTests.self).pathForResource("ValueTest", ofType: "json", inDirectory: "")
        let configManager = ConfigManager(basePath: defaultPath, environment: "TestEnv")
        
        let url = configManager[ConfigManagerKey<NSURL?>("url")]
        XCTAssertEqual(url, NSURL(string: "http://google.com"))
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            let defaultPath = NSBundle(forClass: ConfigManagerTests.self).pathForResource("InheritanceTestChild", ofType: "json", inDirectory: "")
            let configManager = ConfigManager(basePath: defaultPath, environment: "TestEnv")
        }
    }
}
