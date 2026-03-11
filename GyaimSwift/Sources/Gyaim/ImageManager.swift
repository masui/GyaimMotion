import Cocoa
import CryptoKit

/// Image management for Gyazo integration.
/// Ported from Image.rb — uses NSImage instead of sips/ImageMagick.
enum ImageManager {
    /// Resize an image file in place using NSImage.
    static func resize(height: CGFloat, src: String, dst: String? = nil) {
        guard let image = NSImage(contentsOfFile: src) else { return }
        let scale = height / image.size.height
        let newSize = NSSize(width: image.size.width * scale, height: height)

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else { return }
        do {
            try pngData.write(to: URL(fileURLWithPath: dst ?? src))
        } catch {
            Log.config.warning("Failed to write resized image: \(error.localizedDescription)")
        }
    }

    /// Generate a solid color PNG image.
    static func generatePNG(file: String, color: String, width: Int, height: Int) {
        guard let nsColor = parseColor(color) else { return }
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        nsColor.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else { return }
        do {
            try pngData.write(to: URL(fileURLWithPath: file))
        } catch {
            Log.config.warning("Failed to write generated PNG: \(error.localizedDescription)")
        }
    }

    /// Paste a Gyazo image to a text view as an attachment.
    static func pasteGyazoToTextView(_ gyazoID: String, textView: NSTextView) {
        let imagePath = findImagePath(gyazoID: gyazoID, small: true)
        guard let imagePath else { return }

        let url = URL(fileURLWithPath: imagePath)
        guard let wrapper = try? FileWrapper(url: url) else { return }
        let attachment = NSTextAttachment(fileWrapper: wrapper)
        let attachStr = NSAttributedString(attachment: attachment)
        textView.textStorage?.beginEditing()
        textView.textStorage?.insert(attachStr, at: textView.textStorage?.length ?? 0)
        textView.textStorage?.endEditing()
    }

    /// Copy a Gyazo image to the pasteboard.
    static func pasteGyazoToPasteboard(_ gyazoID: String) {
        let imagePath = findImagePath(gyazoID: gyazoID, small: false)
        guard let imagePath, let image = NSImage(contentsOfFile: imagePath),
              let tiffData = image.tiffRepresentation else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.tiff, .string], owner: nil)
        pasteboard.setData(tiffData, forType: .tiff)
        pasteboard.setString("[[http://Gyazo.com/\(gyazoID).png]]", forType: .string)
    }

    /// Check if a word looks like a Gyazo hash (32 hex chars).
    static func isImageCandidate(_ word: String) -> Bool {
        word.count == 32 && word.range(of: "^[0-9a-f]{32}$", options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - Private

    private static func findImagePath(gyazoID: String, small: Bool) -> String? {
        let suffix = small ? "s" : ""
        let fm = FileManager.default
        let cachePath = "\(Config.cacheDir)/\(gyazoID)\(suffix).png"
        if fm.fileExists(atPath: cachePath) { return cachePath }
        let imagePath = "\(Config.imageDir)/\(gyazoID)\(suffix).png"
        if fm.fileExists(atPath: imagePath) { return imagePath }
        return nil
    }

    private static func parseColor(_ hex: String) -> NSColor? {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        guard hexStr.count == 6,
              let r = UInt8(hexStr.prefix(2), radix: 16),
              let g = UInt8(hexStr.dropFirst(2).prefix(2), radix: 16),
              let b = UInt8(hexStr.dropFirst(4).prefix(2), radix: 16) else { return nil }
        return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255,
                       blue: CGFloat(b) / 255, alpha: 1.0)
    }
}
