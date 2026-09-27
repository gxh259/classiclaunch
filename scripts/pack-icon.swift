import Foundation

func bigEndian32(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return Data(bytes: &number, count: 4)
}

func imageDimension(_ data: Data, at offset: Int) -> Int {
    data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
}

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
var chunks = Data()

// The 16/32/64-pixel PNG chunks render as stripes in some macOS icon
// services. The system scales these verified larger representations down.
for (size, kind) in [(128, "ic07"), (256, "ic08"), (512, "ic09"), (1024, "ic10")] {
    let png = try Data(contentsOf: directory.appendingPathComponent("\(size).png"))
    guard png.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
          imageDimension(png, at: 16) == size,
          imageDimension(png, at: 20) == size else {
        fatalError("Invalid \(size)×\(size) PNG icon")
    }
    chunks.append(Data(kind.utf8))
    chunks.append(bigEndian32(png.count + 8))
    chunks.append(png)
}

var icon = Data("icns".utf8)
icon.append(bigEndian32(chunks.count + 8))
icon.append(chunks)
try icon.write(to: output, options: .atomic)
