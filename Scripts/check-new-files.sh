#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
cat > "$temporary/main.swift" <<'SWIFT'
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for type in ["TXT", "Markdown", "JSON", "DOCX", "PPTX", "XLSX"] {
    let first = try NewFileCreator.create(type: type, in: directory)
    let original = try Data(contentsOf: first)
    let second = try NewFileCreator.create(type: type, in: directory)
    precondition(first != second && second.deletingPathExtension().lastPathComponent == "Untitled 2")
    let unchanged = try Data(contentsOf: first)
    precondition(unchanged == original, "Existing file overwritten")
    precondition(FileManager.default.fileExists(atPath: second.path))
    if ["TXT", "Markdown", "JSON"].contains(type) { precondition(original.isEmpty) }
}
do {
    _ = try NewFileCreator.create(type: "UNKNOWN", in: directory)
    fatalError("Unknown type must fail")
} catch { }
do {
    _ = try NewFileCreator.create(type: "TXT", in: directory.appendingPathComponent("missing"))
    fatalError("Missing directory must report failure")
} catch { }
print("PASS: six types, duplicate names preserve files, invalid type and destination report errors")
SWIFT
swiftc "$root/Sources/RClickHost/NewFileCreator.swift" "$temporary/main.swift" -o "$temporary/check"
"$temporary/check" "$temporary/files"
python3 - "$temporary/files" <<'PY'
import pathlib
import sys
import zipfile
import xml.etree.ElementTree as ET

directory = pathlib.Path(sys.argv[1])
relationship_ns = '{http://schemas.openxmlformats.org/package/2006/relationships}'
content_ns = '{http://schemas.openxmlformats.org/package/2006/content-types}'
for extension, main in [('docx', 'word/document.xml'), ('pptx', 'ppt/presentation.xml'), ('xlsx', 'xl/workbook.xml')]:
    with zipfile.ZipFile(directory / f'Untitled.{extension}') as archive:
        assert archive.testzip() is None
        names = set(archive.namelist())
        for name in names:
            if name.endswith(('.xml', '.rels')):
                ET.fromstring(archive.read(name))
        relationships = ET.fromstring(archive.read('_rels/.rels'))
        assert relationships.find(relationship_ns + 'Relationship').get('Target') == main
        types = ET.fromstring(archive.read('[Content_Types].xml'))
        overrides = {item.get('PartName'): item.get('ContentType') for item in types.findall(content_ns + 'Override')}
        assert '/' + main in overrides and main in names
        if extension == 'xlsx':
            assert 'xl/worksheets/sheet1.xml' in names
            sheet = ET.fromstring(archive.read('xl/worksheets/sheet1.xml'))
            assert sheet.find('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}sheetData') is not None
        print(f'PASS: {extension.upper()} ZIP integrity, XML and document relationships')
PY
/usr/bin/textutil -convert txt -output "$temporary/docx.txt" "$temporary/files/Untitled.docx"
echo 'PASS: macOS textutil imports generated DOCX'
