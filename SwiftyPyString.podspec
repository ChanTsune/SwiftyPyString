Pod::Spec.new do |spec|

  spec.name         = "SwiftyPyString"
  spec.version      = "1.0.0"
  spec.summary      = "A library that provides Swift with string operations equivalent to Python."
  spec.description  = <<-DESC
  A library that provides Swift with string operations equivalent to Python.
                   DESC
  spec.homepage     = "https://github.com/ChanTsune/SwiftyPyString"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author    = "ChanTsune"
  spec.ios.deployment_target = "5.0"
  spec.osx.deployment_target = "10.7"
  spec.watchos.deployment_target = "2.0"
  spec.tvos.deployment_target = "9.0"
  spec.source       = { :git => "https://github.com/ChanTsune/SwiftyPyString.git", :tag => "#{spec.version}" }
  spec.source_files = "Sources/**/*.{swift}"
  spec.requires_arc = true

end
