#!/bin/sh
":" //#; DIR=$(dirname $(readlink $0 || echo $0))
":" //#; [ $1 = "setup" ] && { ruby $DIR/bansan-setup.rb; exit $?; }
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
        guard let kind = structure["key.kind"] as? String,
            let name = structure["key.name"] as? String,
            let attrs = structure["key.attributes"] as? [SourceKitRepresentable] else {
                return
        }
        let attributes = attrs.flatMap({(($0 as? [String: SourceKitRepresentable]) ?? [:]).values})

        if attributes.contains({($0 as? String) == "source.decl.attribute.lazy"}) &&
            kind == "source.lang.swift.decl.var.instance" {
                // TODO: match only if its definition expr contains self
                lazyVarsRefsSelf.append(name)
        }
    }
    traverse(substructures) { structure, substructures in
        guard let kind = structure["key.kind"] as? String,
            let name = structure["key.name"] as? String else {
                return
        }
        guard name == "deinit" &&
            kind == "source.lang.swift.decl.function.method.instance" else {
                return
        }
        traverse(substructures ?? []) { descendant, substructures in
            // TODO: matching to identifiers
            guard let descendantName = descendant["key.name"] as? String else { return }
            if lazyVarsRefsSelf.contains({descendantName.containsString($0)}) {
                let descendantOffset = Int(descendant["key.offset"] as? Int64 ?? 0)
                let line = file.contents.lineAndCharacterForByteOffset(descendantOffset)?.line ?? 1
                print("\(file.path!):\(line): warning: lazy var \(descendantName) referencing self cannot be initialized in deinit")
            }
        }
    }
}


let args = Process.arguments.dropFirst(1)
for case let file? in args.map({File(path: $0)}) {
    check(file)
}

