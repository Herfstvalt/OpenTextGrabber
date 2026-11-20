import Cocoa
import CoreImage
import Vision

setbuf(stdout, nil)

func canvas(width: Int = 1200, height: Int = 600, draw: (CGContext) -> Void) -> CGImage {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    draw(context)
    NSGraphicsContext.restoreGraphicsState()
    return context.makeImage()!
}

func drawText(_ lines: [String]) {
    for (index, line) in lines.enumerated() {
        (line as NSString).draw(at: NSPoint(x: 40, y: 500 - index * 85), withAttributes: [
            .font: NSFont.systemFont(ofSize: 34), .foregroundColor: NSColor.black
        ])
    }
}

func qr(_ payload: String) -> CGImage {
    let filter = CIFilter(name: "CIQRCodeGenerator")!
    filter.setValue(Data(payload.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    let image = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
    return CIContext(options: [.useSoftwareRenderer: true]).createCGImage(image, from: image.extent)!
}

var failures = 0
func check(_ name: String, image: CGImage, expected: String,
           options: OCREngine.Options = .init(scanQRCodes: true, joinLines: true),
           matches: ((String) -> Bool)? = nil) {
    let done = DispatchSemaphore(value: 0)
    var result: Result<String, Error>?
    var callbacks = 0
    OCREngine.recognizeText(in: image, options: options) {
        callbacks += 1
        result = $0
        done.signal()
    }
    guard done.wait(timeout: .now() + 90) == .success else {
        print("FAIL \(name): timed out")
        failures += 1
        return
    }
    switch result! {
    case .success(let actual) where (matches?(actual) ?? (actual == expected)) && callbacks == 1:
        print("PASS \(name)")
    default:
        print("FAIL \(name): \(String(describing: result)), expected \(expected)")
        failures += 1
    }
}

let paragraph = ["This paragraph spans several lines.", "The copied text should flow naturally.",
                 "Every word stays in the same order.", "Done."]
check("four lines with a short final line", image: canvas { _ in drawText(paragraph) },
      expected: paragraph.joined(separator: " "))
let turkish = ["Türkçe karakterler: ç, ğ, ı, ö, ş, ü.", "Bu metin tek satır olarak kopyalanır."]
check("Turkish paragraph", image: canvas { _ in drawText(turkish) },
      expected: turkish.joined(separator: " "))
let url = "https://example.com/path?first=hello%20world&second=2#section"
let code = qr(url)
check("QR URL with query and fragment", image: canvas { context in
    context.interpolationQuality = .none
    context.draw(code, in: CGRect(x: 100, y: 100, width: 350, height: 350))
}, expected: url)
check("QR takes priority over nearby text", image: canvas { context in
    drawText(["Ignore this label when copying the QR."])
    context.interpolationQuality = .none
    context.draw(code, in: CGRect(x: 100, y: 80, width: 350, height: 350))
}, expected: url)
check("empty image", image: canvas { _ in }, expected: "")
check("line merging disabled preserves line breaks", image: canvas { _ in drawText(paragraph) },
      expected: paragraph.joined(separator: " "), options: .init(scanQRCodes: true, joinLines: false),
      matches: { $0.contains("\n") && $0.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") == paragraph.joined(separator: " ") })
check("QR disabled still recognizes normal text", image: canvas { _ in drawText(paragraph) },
      expected: paragraph.joined(separator: " "), options: .init(scanQRCodes: false, joinLines: true))
check("QR disabled does not decode payload", image: canvas { context in
    drawText(["Ignore this label when copying the QR."])
    context.interpolationQuality = .none
    context.draw(code, in: CGRect(x: 100, y: 80, width: 350, height: 350))
}, expected: "nearby label, not the QR URL", options: .init(scanQRCodes: false, joinLines: true),
      matches: { $0.contains("Ignore this label when copying the QR.") && !$0.contains(url) })
exit(failures == 0 ? 0 : 1)
