import ArgumentParser
import Foundation
import SwiftParser
import SwiftSyntax
import SwiftSyntaxScope

@main
struct SwiftScopeDump: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-scope-dump",
        abstract: "Dump the SyntaxScope tree of a Swift source file."
    )

    @Argument(help: "Path to a Swift source file.")
    var path: String

    func run() throws {
        let url = URL(fileURLWithPath: path)
        let source = try String(contentsOf: url, encoding: .utf8)

        let syntax = Parser.parse(source: source)
        let scopeTree = SourceFileScope(syntax: syntax)
        scopeTree.buildFullyExpandedTree()

        FileHandle.standardOutput.write(Data(scopeTree.dump().utf8))
    }
}
