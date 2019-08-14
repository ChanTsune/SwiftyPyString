# SwiftyPyString  
![Cocoapods](https://img.shields.io/cocoapods/l/SwiftyPyString)
![GitHub release](https://img.shields.io/github/release/ChanTsune/SwiftyPyString)
![Cocoapods platforms](https://img.shields.io/cocoapods/p/SwiftyPyString)
![Swift Version](https://img.shields.io/badge/Swift-5-blue.svg)
  
SwiftyPyString is a string extension for Swift.  
This library provide Python compliant String operation methods.  

## Installation  

### Cocoapods  
```ruby
pod 'SwiftyPyString'
```

### Carthage  
```bash
github 'ChanTsune/SwiftyPyString'
```

### Swift Package Manager
```swift
import PackageDescription

let package = Package(
    name: "YourProject",
    dependencies: [
        .Package(url: "https://github.com/ChanTsune/SwiftyPyString.git", from: "1.0.1")
    ]
)
```
## Usage  
```swift
import SwiftyPyString
```

## Methods  

- capitalize  
- casefold  
- center  
- count  
- endswith  
- expandtabs  
- find  
- index  
- isalnum  
- isalpha  
- isascii  
- isdecimal  
- isdigit  
- islower  
- isnumeric  
- isprintable  
- isspace  
- istitle  
- isupper  
- join  
- ljust  
- lower  
- lstrip  
- maketrans  
- partition  
- replace  
- rfind  
- rindex  
- rjust  
- rpartition  
- rsplit  
- rstrip  
- split  
- splitlines  
- startswith  
- strip  
- swapcase  
- title  
- translate  
- upper  
- zfill  

### Sample code  

#### String sliceing subscript  


```swift
let str = "0123456789"
str[0]
// 0
str[-1]
// 9

// slice
str[0,5]
// 01234
str[0,8,2]
// 0246
str[nil,nil,-1]
// 9876543210
```

Use Slice object case 
```swift
let str = "0123456789"
var slice = Slice(start:0, stop:5)
var sliceStep = Slice(start:0, stop:8, step:2)

str[slice]
// 01234
str[sliceStep]
// 0246
```

#### String Multiplication  
```swift
var s = "Hello World! " * 2

// Hello World! Hello World! 
```

## License

SwiftPyString is available under the MIT license. See the LICENSE file for more info.  
