import Foundation

enum NewFileCreator {
    static func create(type: String, in directory: URL) throws -> URL {
        let ext: String
        switch type {
        case "TXT": ext = "txt"
        case "Markdown": ext = "md"
        case "JSON": ext = "json"
        case "DOCX", "PPTX", "XLSX": ext = type.lowercased()
        default:
            throw NSError(domain: "NewFileCreator", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "不支持的新建文件类型：\(type)"])
        }
        let data = try ["docx", "pptx", "xlsx"].contains(ext) ? officeDocument(ext) : Data()
        var index = 1
        while true {
            let name = index == 1 ? "Untitled.\(ext)" : "Untitled \(index).\(ext)"
            let url = directory.appendingPathComponent(name)
            do {
                // Exclusive creation also protects files created concurrently by another request.
                try data.write(to: url, options: .withoutOverwriting)
                return url
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                index += 1
            }
        }
    }

    private static func officeDocument(_ ext: String) throws -> Data {
        let manager = FileManager.default
        let temporary = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        let contents = temporary.appendingPathComponent("contents", isDirectory: true)
        let relationshipNS = "http://schemas.openxmlformats.org/package/2006/relationships"
        let officeNS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let mainPath: String
        let mainType: String
        var parts: [String: String]
        switch ext {
        case "docx":
            mainPath = "word/document.xml"
            mainType = "wordprocessingml.document"
            parts = [mainPath: """
            <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p/><w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr></w:body></w:document>
            """]
        case "xlsx":
            mainPath = "xl/workbook.xml"
            mainType = "spreadsheetml.sheet"
            parts = [
                mainPath: """
                <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="\(officeNS)"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
                """,
                "xl/_rels/workbook.xml.rels": """
                <Relationships xmlns="\(relationshipNS)"><Relationship Id="rId1" Type="\(officeNS)/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
                """,
                "xl/worksheets/sheet1.xml": """
                <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>
                """
            ]
        default:
            mainPath = "ppt/presentation.xml"
            mainType = "presentationml.presentation"
            // A new presentation can have zero slides; no placeholder or broken slide relationships.
            parts = [mainPath: """
            <p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/></p:presentation>
            """]
        }
        parts["_rels/.rels"] = """
        <Relationships xmlns="\(relationshipNS)"><Relationship Id="rId1" Type="\(officeNS)/officeDocument" Target="\(mainPath)"/></Relationships>
        """
        let sheetType = ext == "xlsx" ? "<Override PartName=\"/xl/worksheets/sheet1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" : ""
        parts["[Content_Types].xml"] = """
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/\(mainPath)" ContentType="application/vnd.openxmlformats-officedocument.\(mainType).main+xml"/>\(sheetType)</Types>
        """
        for (path, xml) in parts {
            let url = contents.appendingPathComponent(path)
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" + xml).utf8).write(to: url)
        }
        let archive = temporary.appendingPathComponent("document.zip")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zip.currentDirectoryURL = contents
        zip.arguments = ["-q", "-r", archive.path, "."]
        let errors = Pipe()
        zip.standardError = errors
        try zip.run()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        zip.waitUntilExit()
        guard zip.terminationStatus == 0 else {
            throw NSError(domain: "NewFileCreator", code: Int(zip.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "创建 Office 文档失败：" + String(decoding: errorData, as: UTF8.self)])
        }
        return try Data(contentsOf: archive)
    }
}
