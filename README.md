# ConfigManager

_Check ConfigManagerTests_

## Usage
* Get the path for your *Default* configuration file. 
	`let configPath = NSBundle(forClass: ConfigManagerTests.self).pathForResource("ConfigFile", ofType: "json", inDirectory: "")`
* Create the config manager with that path.
    `let configManager = ConfigManager(configPath: configPath)`

* ConfigManager will now try to load 2 files in order:
	1. `<bundle path>/.ConfigFile.json`
	2. `<bundle path>/ConfigFile.json`

It's recommended that you add .ConfigFile.json to your .gitignore so it acts as a local override.

### With Environment per scheme/target
* Define environment variable `CONFIG_MANAGER_ENV` per scheme or target. Say you have one that's called `Dev`, one that's `Staging` and one that's `Prod`.
* If you initialize the ConfigManager the same way as before, it will now try to load 3 files in order:
	1. `<bundle path>/.ConfigFile.json`
	2. `<bundle path>/ConfigFile.{Dev, Staging, Prod}.json`
	3. `<bundle path>/ConfigFile.json`
* Note that you can override the environment at initialization:
	* `let configManager = ConfigManager(configPath: configPath, environment: "Custom")`

### Extend
* A special key will be read in each configuration file, `"!extends"` can be put into the json and it will try to load & extend that file:

```
{
  "!extends": "InheritanceTestParent.json",
  "childKey": "childValue",
  "mergedKey": "mergedChildValue",
  "config": {
    "configKey": {
      "childConfigA": "configAChildValue",
      "configB": [ "childConfigBValue0", "childConfigBValue1", "childConfigBValue2" ]
    }
  }
}
```
