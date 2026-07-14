# hxDTS
Never write a dts parser again.  

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
dts.read(byte[] bytes); // Load
dts.write(int version); // Save
```

### JavaScript/TypeScript
```
dts.read(buffer: ArrayBuffer); // Load
dts.write(version: number): ArrayBuffer; // Save
```

### Python
```
dts = DtsFile()
dts.read(bytes: bytearray) // Load
dts.write(version: int) -> bytearray // Save
```

### Other Languages
Use the read() method of DtsFile and pass the appropriate buffer object as given by https://api.haxe.org/haxe/io/BytesData.html
Use the write() method of DtsFile and pass the appropriate version number to get a buffer object as given by https://api.haxe.org/haxe/io/BytesData.html