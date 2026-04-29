import SwiftParser
import Testing

@testable import SwiftSyntaxScope

@Suite
struct SwiftSyntaxScopeTests {}

extension SwiftSyntaxScopeTests {
    typealias TreeDumpTestCase = (source: String, expected: String)

    func assertTreeDump(source: String, expected: String) {
        let syntax = Parser.parse(source: source)
        let scopeTree = SourceFileScope(syntax: syntax)

        scopeTree.buildFullyExpandedTree()

        #expect(scopeTree.dump() == expected)
    }
}
