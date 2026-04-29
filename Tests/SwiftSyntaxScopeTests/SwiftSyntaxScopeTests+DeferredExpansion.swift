import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftSyntaxScope

extension SwiftSyntaxScopeTests {
    @Test
    func nominalTypeWholeIsDeferredOnInitialExpansion() throws {
        let syntax = Parser.parse(source: "struct Foo {}")
        let scopeTree = SourceFileScope(syntax: syntax)

        scopeTree.expandAndBeCurrent()

        let nominal = try #require(scopeTree.children.first as? NominalTypeScope)
        #expect(nominal.portion == .whole)
        #expect(nominal.isExpanded == false)
        #expect(nominal.children.isEmpty)
    }

    @Test
    func nominalTypeBodyIsDeferredAfterWholeExpansion() throws {
        let syntax = Parser.parse(source: "struct Foo { func f() {} }")
        let scopeTree = SourceFileScope(syntax: syntax)

        scopeTree.expandAndBeCurrent()
        let whole = try #require(scopeTree.children.first as? NominalTypeScope)

        whole.expandAndBeCurrent()

        let body = try #require(whole.children.first as? NominalTypeScope)
        #expect(body.portion == .body)
        #expect(body.isExpanded == false)
        #expect(body.children.isEmpty)
    }

    @Test
    func nominalTypeWhereIsExpandedEagerlyButBodyIsDeferred() throws {
        let syntax = Parser.parse(source: "struct Foo<T> where T: Equatable {}")
        let scopeTree = SourceFileScope(syntax: syntax)

        scopeTree.expandAndBeCurrent()
        let whole = try #require(scopeTree.children.first as? NominalTypeScope)
        whole.expandAndBeCurrent()

        let genericScope = try #require(whole.children.first as? GenericParameterScope)
        let portions = genericScope.children.compactMap { $0 as? NominalTypeScope }
        let whereScope = try #require(portions.first { $0.portion == .where })
        let bodyScope = try #require(portions.first { $0.portion == .body })

        #expect(whereScope.isExpanded == true)

        #expect(bodyScope.isExpanded == false)
        #expect(bodyScope.children.isEmpty)
    }

    @Test
    func extensionWholeIsDeferredOnInitialExpansion() throws {
        let syntax = Parser.parse(source: "extension Foo { func f() {} }")
        let scopeTree = SourceFileScope(syntax: syntax)

        scopeTree.expandAndBeCurrent()

        let ext = try #require(scopeTree.children.first as? ExtensionScope)
        #expect(ext.portion == .whole)
        #expect(ext.isExpanded == false)
        #expect(ext.children.isEmpty)
    }

    @Test
    func functionBodyIsDeferredAfterFunctionDeclExpansion() throws {
        let syntax = Parser.parse(source: "func f() {}")
        let scopeTree = SourceFileScope(syntax: syntax)

        scopeTree.expandAndBeCurrent()

        let funcDecl = try #require(scopeTree.children.first as? AbstractFunctionDeclScope)
        #expect(funcDecl.isExpanded == true)

        let body = try #require(funcDecl.children.first as? FunctionBodyScope)
        #expect(body.isExpanded == false)
        #expect(body.children.isEmpty)
    }

    @Test
    func lookupOnlyExpandsScopesOnTraversedPath() throws {
        let parsed = parseMarkedSource(
            """
            struct Outer {
                func f() {
                    /*1️⃣*/
                }
                func g() {
                }
            }
            """
        )

        let startingScope = parsed.syntax.findStartingScopeForLookup(
            position: parsed.position(of: "1️⃣")
        )

        let body = try #require(
            sequence(first: startingScope, next: { $0.parent })
                .compactMap { $0 as? NominalTypeScope }
                .first { $0.portion == .body }
        )

        let funcScopes = body.children.compactMap { $0 as? AbstractFunctionDeclScope }
        #expect(funcScopes.count == 2)
        let fDecl = try #require(
            funcScopes.first {
                guard case .function(let decl) = $0.kind else { return false }
                return decl.name.text == "f"
            }
        )
        let gDecl = try #require(
            funcScopes.first {
                guard case .function(let decl) = $0.kind else { return false }
                return decl.name.text == "g"
            }
        )

        let fBody = try #require(fDecl.children.first as? FunctionBodyScope)
        let gBody = try #require(gDecl.children.first as? FunctionBodyScope)

        #expect(fBody.isExpanded == true)
        #expect(gBody.isExpanded == false)
        #expect(gBody.children.isEmpty)
    }
}
