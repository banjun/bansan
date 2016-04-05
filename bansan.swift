#!/bin/sh
":" //#; DIR=$(dirname $(readlink $0 || echo $0))
":" //#; [ "$1" = "setup" ] && exec ruby $DIR/bansan-setup.rb
":" //#; exec swift -sdk $(xcrun --sdk macosx --show-sdk-path) -F "$DIR/Carthage/Build/Mac" -target x86_64-apple-macosx10.10 "$0" "$@"
import Foundation
import SourceKittenFramework



func traverse(substructures: [SourceKitRepresentable],
    @noescape block: (structure: [String: SourceKitRepresentable], substructures: [SourceKitRepresentable]?) -> Void) {
        for case let ss as [String: SourceKitRepresentable] in substructures {
            guard let substructures = ss["key.substructure"] as? [SourceKitRepresentable] else {
                //                let kind = ss[SwiftDocKey.Kind.rawValue] ?? "(kind)"
                //                let name = ss[SwiftDocKey.Name.rawValue] ?? "(name)"
                //                NSLog("%@", "\(name)(\(kind)) is a bottom")
                block(structure: ss, substructures: nil)
                continue
            }
            block(structure: ss, substructures: substructures)
            traverse(substructures, block: block)
        }
}

func check(file: File) {
    let s = Structure(file: file)
    let substructures = s.dictionary["key.substructure"] as? [SourceKitRepresentable] ?? []

    // check super call requirements
    traverse(substructures) { structure, substructures in
        guard let kind = structure["key.kind"] as? String,
            let name = structure["key.name"] as? String,
            let attrs = structure["key.attributes"] as? [SourceKitRepresentable] else {
                return
        }
        let attributes = attrs.flatMap({(($0 as? [String: SourceKitRepresentable]) ?? [:]).values})

        let superCallChecked = [
            "viewDidLoad()",
            "viewWillAppear(_:)",
            "viewDidAppear(_:)",
            "viewWillDisappear(_:)",
            "viewDidDisappear(_:)",
        ]

        if attributes.contains({($0 as? String) == "source.decl.attribute.override"}) &&
            kind == "source.lang.swift.decl.function.method.instance" &&
            superCallChecked.contains({$0 == name}) {

                var foundSuperCall = false
                traverse(substructures ?? []) { descendant, substructures in
                    let descendantKind = descendant["key.kind"] as? String
                    let descendantName = descendant["key.name"] as? String
                    if descendantKind == "source.lang.swift.expr.call" &&
                        descendantName == "super.\(name.substringToIndex(name.rangeOfString("(")!.startIndex))" {
                            foundSuperCall = true
                    }
                }
                if !foundSuperCall {
                    let byteOffset = Int(structure["key.offset"] as? Int64 ?? 0)
                    let line = file.contents.lineAndCharacterForByteOffset(byteOffset)?.line ?? 1
                    print("\(file.path!):\(line): warning: \(name) requires super call")
                }
        }
    }

    // check deinit initialized lazy var referencing self
    var lazyVarsRefsSelf = [String]()
    traverse(substructures) { structure, substructures in
        let lazyVarDecls = (substructures ?? []).filter {$0.isLazyVarDecl}
        for lazyVarDecl in lazyVarDecls {
            guard let declName = lazyVarDecl.name,
                let declRange = lazyVarDecl.range else { continue }
            let overlaps = (substructures ?? []).filter {
                return $0.range?.overlap(declRange) == true
            }
            for rhs in overlaps {
                // identifier check for more soundness
                if rhs.name?.containsString("self") == true {
                    lazyVarsRefsSelf.append(declName)
                }
            }
        }
    }
    traverse(substructures) { structure, substructures in
        guard structure.isDeinit else { return }
        guard let deinitRange = structure.range else { return }

        let syntaxMap = SyntaxMap(file: file)

        for token in syntaxMap.tokens {
            guard token.type == "source.lang.swift.syntaxtype.identifier" else { continue }
            guard token.range.overlap(deinitRange) else { continue }
            guard let name = file.contents.substringWithByteRange(start: token.offset, length: token.length) else { continue }
            if lazyVarsRefsSelf.contains(name) {
                let line = file.contents.lineAndCharacterForByteOffset(token.offset)?.line ?? 1
                print("\(file.path!):\(line): warning: lazy var \(name) referencing self cannot be initialized in deinit")
            }
        }
    }
}


extension SourceKitRepresentable {
    var dictionary: [String: SourceKitRepresentable]? {
        return self as? [String: SourceKitRepresentable]
    }

    var kind: SourceKitRepresentable? {
        return dictionary?["key.kind"]
    }

    func isKindOf(kind: String) -> Bool {
        return self.kind?.isEqualTo(kind) == Bool?(true)
    }

    var name: String? {
        return dictionary?["key.name"] as? String
    }

    var offset: Int64? {
        return dictionary?["key.offset"] as? Int64
    }

    var length: Int64? {
        return dictionary?["key.length"] as? Int64
    }

    var attributes: [SourceKitRepresentable]? {
        return dictionary?["key.attributes"] as? [SourceKitRepresentable]
    }

    func containsAttr(attr: String) -> Bool {
        return attributes?.contains {
            $0.dictionary?["key.attribute"]?.isEqualTo(attr) == true
        } == true
    }

    var range: Range<Int64>? {
        guard let offset = offset,
            let length = length else { return nil }
        return offset..<(offset + length)
    }

    var isLazyVarDecl: Bool {
        return isKindOf("source.lang.swift.decl.var.instance") &&
            containsAttr("source.decl.attribute.lazy")
    }

    var isDeinit: Bool {
        return name == "deinit" &&
            isKindOf("source.lang.swift.decl.function.method.instance")
    }
}


extension SyntaxToken {
    var range: Range<Int64> {
        return Int64(offset)..<(Int64(offset) + Int64(length))
    }
}


extension Range where Element: IntegerType {
    func overlap(another: Range) -> Bool {
        return !Set(self).intersect(Set(another)).isEmpty
    }
}


let args = Process.arguments.dropFirst(1)
for case let file? in args.map({File(path: $0)}) {
    check(file)
}

