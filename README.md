# hxDTS
Never write a dts parser again.  
Parser only.

# Compilation
 
## C++
```haxe build-cpp.hxml```
## C#
```haxe build-cs.hxml```
## PHP
```haxe build-php.hxml```
## Python
```haxe build-py.hxml```
## JavaScript
```haxe build-js.hxml```

## TypeScript
Requires hxtsdgen, get it using ```haxelib install hxtsdgen```   
```haxe build-ts.hxml```

## Java
```haxe build-java.hxml```

## Lua
```haxe build-lua.hxml```

## HashLink
```haxe build-hl.hxml```
# Usage

## Load from Buffer

### C#
```
var dts = new DtsFile();
dts.load(byte[] bytes); // Load
```

### JavaScript/TypeScript
```
let dts = new DtsFile();
dts.load(buffer: ArrayBuffer); // Load
```

### Python
```
dts = DtsFile()
dts.load(bytes: bytearray) // Load
```

### Other Languages
Use the load() method of DtsFile and pass the appropriate buffer object as given by https://api.haxe.org/haxe/io/BytesData.html