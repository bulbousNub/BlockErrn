import Foundation
import UIKit

enum ReceiptStorage {
    private static let receiptsFolderName = "Receipts"

    static func receiptsDirectory() throws -> URL {
        let fm = FileManager.default
        let base: URL
        if let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            base = appSupport
        } else {
            base = fm.temporaryDirectory
        }
        let receiptsDir = base.appendingPathComponent(receiptsFolderName, isDirectory: true)
        if !fm.fileExists(atPath: receiptsDir.path) {
            try fm.createDirectory(at: receiptsDir, withIntermediateDirectories: true)
        }
        return receiptsDir
    }

    @discardableResult
    static func save(image: UIImage, fileName: String? = nil) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        return save(data: data, fileName: fileName)
    }

    @discardableResult
    static func save(data: Data, fileName: String? = nil) -> String? {
        do {
            let directory = try receiptsDirectory()
            let name = fileName ?? UUID().uuidString + ".jpg"
            let destination = directory.appendingPathComponent(name)
            try data.write(to: destination, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func loadImage(named name: String?) -> UIImage? {
        guard let name else { return nil }
        guard let data = loadData(named: name) else { return nil }
        return UIImage(data: data)
    }

    static func loadData(named name: String?) -> Data? {
        guard let name else { return nil }
        do {
            let directory = try receiptsDirectory()
            let url = directory.appendingPathComponent(name)
            return try Data(contentsOf: url)
        } catch {
            return nil
        }
    }

    static func delete(named name: String?) {
        guard let name else { return }
        do {
            let directory = try receiptsDirectory()
            let url = directory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            // Ignored
        }
    }
}
