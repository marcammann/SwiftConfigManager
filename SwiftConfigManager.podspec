Pod::Spec.new do |s|
  s.platform = :ios
  s.ios.deployment_target = '8.0'
  s.name = "ConfigManager"
  s.summary = "ConfigManager helps loading JSON files as configurations by allowing by-environment files, local-only files and extension of other JSON files."
  s.requires_arc = true
  s.version = "0.9.3"
  s.license = { :type => "MIT", :file => "LICENSE" }
  s.author = { "Marc Ammann" => "marc@codesofa.com" }
  s.homepage = "https://github.com/marcammann/SwiftConfigManager"
  s.source = { :git => "https://github.com/marcammann/SwiftConfigManager.git", :tag => "#{s.version}"}
  s.source_files = "ConfigManager/**/*.{swift}"
end
