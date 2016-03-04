#!/bin/sh
":" //#; exec swift -F "$(dirname $(readlink $0 || echo $0))/Carthage/Build/Mac" "$0" "$@"
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
    let substructures = s.dictionary["key.substructure"] as? [SourceKitRepresentable]
    traverse(substructures ?? []) { structure, substructures in
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
                if !foundSuperCall { print("\u{1b}[31m", terminator: "") }
                print("\(file.path!).\(name) calls super = \(foundSuperCall)", terminator: "")
                if !foundSuperCall { print("\u{1b}[0m", terminator: "") }
                print("")
        }
    }
}


let args = Process.arguments.dropFirst(1)
for case let file? in args.map({File(path: $0)}) {
    check(file)
}

