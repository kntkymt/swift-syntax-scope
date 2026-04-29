import SwiftSyntax
import GSB

enum ScopeCreator {
    static func createScopeTree(sourceFileSyntax: SourceFileSyntax) -> SourceFileScope {
        SourceFileScope(syntax: sourceFileSyntax)
    }

    @discardableResult
    static func addToScopeTree(of syntax: any SyntaxProtocol, to parent: any SyntaxScopeProtocol)
        -> any SyntaxScopeProtocol
    {
        let nodeAdder = NodeAdder(parent: parent)
        nodeAdder.walk(syntax)

        return nodeAdder.result ?? parent
    }

    @discardableResult
    static func constructExpandAndInsert(
        of child: any SyntaxScopeProtocol,
        to parent: any SyntaxScopeProtocol
    ) -> any SyntaxScopeProtocol {
        parent.addChild(child)

        if let insertionPoint = child.insertionPointForDeferredExpansion {
            return insertionPoint
        }

        return child.expandAndBeCurrent()
    }

    static func addCustomAttributeScopes(
        of attributes: AttributeListSyntax,
        to parent: any SyntaxScopeProtocol
    ) {
        for case .attribute(let attr) in attributes where attr.isCustomAttribute {
            constructExpandAndInsert(
                of: CustomAttributeScope(syntax: attr, parent: parent),
                to: parent
            )
        }
    }

    @discardableResult
    static func addNestedGenericParameterScopes(
        kinds: [GenericParameterScope.Kind],
        holderLookupUpperBound: AbsolutePosition,
        parent: any SyntaxScopeProtocol
    ) -> any SyntaxScopeProtocol {
        var leaf = parent
        for kind in kinds {
            leaf = constructExpandAndInsert(
                of: GenericParameterScope(
                    kind: kind,
                    holderLookupUpperBound: holderLookupUpperBound,
                    parent: leaf
                ),
                to: leaf
            )
        }
        return leaf
    }
}

final class NodeAdder: SyntaxVisitor {
    let parent: any SyntaxScopeProtocol

    var result: (any SyntaxScopeProtocol)?

    init(parent: any SyntaxScopeProtocol) {
        self.parent = parent
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
        guard !node.statements.isEmpty else {
            return .skipChildren
        }

        let decls = scanLocalDecls(in: node.statements)

        self.result = ScopeCreator.constructExpandAndInsert(
            of: BraceStmtScope(
                syntax: node.statements,
                parent: parent,
                braceRange: node.trimmedRange,
                localFuncs: decls.localFuncs,
                localTypes: decls.localTypes
            ),
            to: parent
        )

        return .skipChildren
    }

    override func visit(_ node: CodeBlockItemListSyntax) -> SyntaxVisitorContinueKind {
        guard !node.isEmpty else {
            return .skipChildren
        }

        let decls = scanLocalDecls(in: node)

        self.result = ScopeCreator.constructExpandAndInsert(
            of: BraceStmtScope(
                syntax: node,
                parent: parent,
                braceRange: node.trimmedRange,
                localFuncs: decls.localFuncs,
                localTypes: decls.localTypes
            ),
            to: parent
        )

        return .skipChildren
    }

    override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind {
        guard case .getter(let items) = node.accessors, !items.isEmpty else {
            return .skipChildren
        }

        let decls = scanLocalDecls(in: items)

        self.result = ScopeCreator.constructExpandAndInsert(
            of: BraceStmtScope(
                syntax: items,
                parent: parent,
                braceRange: node.trimmedRange,
                localFuncs: decls.localFuncs,
                localTypes: decls.localTypes
            ),
            to: parent
        )

        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        if node.bindings.count == 1 {
            ScopeCreator.addCustomAttributeScopes(of: node.attributes, to: parent)
        }

        var insertionPoint = parent
        for index in node.bindings.indices {
            insertionPoint = ScopeCreator.constructExpandAndInsert(
                of: PatternEntryDeclScope(
                    syntax: node,
                    parent: insertionPoint,
                    bindingIndex: index,
                    isLocalBinding: node.isLocalContext
                ),
                to: insertionPoint
            )
        }

        self.result = insertionPoint

        return .skipChildren
    }

    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        for element in node.elements {
            ScopeCreator.constructExpandAndInsert(
                of: EnumElementScope(syntax: element, parent: parent),
                to: parent
            )
        }

        self.result = parent

        return .skipChildren
    }

    // visit and ignore
    #gsbDecl {
        #gsbForEach([
            "ImportDeclSyntax",
            "OperatorDeclSyntax",
            "PrecedenceGroupDeclSyntax",
            "AssociatedTypeDeclSyntax",
            "MissingDeclSyntax",
            "BreakStmtSyntax",
            "ContinueStmtSyntax",
            "FallThroughStmtSyntax",
        ]) { syntax in
            """
            override func visit(_ node: \(syntax)) -> SyntaxVisitorContinueKind {
                return .skipChildren
            }
            """
        }
    }

    // visit and create with whole portion
    #gsbDecl {
        #gsbForEach([
            ("ActorDeclSyntax", "NominalTypeScope", "DeclSyntax(node)"),
            ("ClassDeclSyntax", "NominalTypeScope", "DeclSyntax(node)"),
            ("EnumDeclSyntax", "NominalTypeScope", "DeclSyntax(node)"),
            ("ProtocolDeclSyntax", "NominalTypeScope", "DeclSyntax(node)"),
            ("StructDeclSyntax", "NominalTypeScope", "DeclSyntax(node)"),
            ("TypeAliasDeclSyntax", "TypeAliasScope", "node"),
        ]) { syntax, scope, syntaxArg in
            """
            override func visit(_ node: \(syntax)) -> SyntaxVisitorContinueKind {
                self.result = ScopeCreator.constructExpandAndInsert(
                    of: \(scope)(
                        syntax: \(syntaxArg),
                        portion: .whole,
                        parent: parent
                    ),
                    to: parent
                )

                return .skipChildren
            }
            """
        }
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        // ExtensionScope's `.whole` source range starts past the extended type, so its
        // attributes are scoped as siblings (children of `parent`) to keep ranges consistent.
        ScopeCreator.addCustomAttributeScopes(of: node.attributes, to: parent)

        self.result = ScopeCreator.constructExpandAndInsert(
            of: ExtensionScope(syntax: node, portion: .whole, parent: parent),
            to: parent
        )

        return .skipChildren
    }

    // visit and create AbstractFunctionDeclScope
    #gsbDecl {
        #gsbForEach([
            ("FunctionDeclSyntax", "function"),
            ("InitializerDeclSyntax", "initializer"),
            ("DeinitializerDeclSyntax", "deinitializer"),
            ("AccessorDeclSyntax", "accessor"),
        ]) { syntax, kindCase in
            """
            override func visit(_ node: \(syntax)) -> SyntaxVisitorContinueKind {
                self.result = ScopeCreator.constructExpandAndInsert(
                    of: AbstractFunctionDeclScope(kind: .\(kindCase)(node), parent: parent),
                    to: parent
                )

                return .skipChildren
            }
            """
        }
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        if node.signature?.capture != nil {
            self.result = ScopeCreator.constructExpandAndInsert(
                of: CaptureListScope(syntax: node, parent: parent),
                to: parent
            )
        } else {
            self.result = ScopeCreator.constructExpandAndInsert(
                of: ClosureParametersScope(syntax: node, parent: parent),
                to: parent
            )
        }

        return .skipChildren
    }

    // visit and create
    #gsbDecl {
        #gsbForEach([
            ("ForStmtSyntax", "ForEachStmtScope"),
            ("IfExprSyntax", "IfExprScope"),
            ("RepeatStmtSyntax", "RepeatWhileScope"),
            ("SwitchExprSyntax", "SwitchExprScope"),
            ("WhileStmtSyntax", "WhileStmtScope"),
            ("GuardStmtSyntax", "GuardStmtScope"),
            ("DoStmtSyntax", "DoStmtScope"),
            ("SubscriptDeclSyntax", "SubscriptDeclScope"),
            ("TryExprSyntax", "TryScope"),
            ("MacroDeclSyntax", "MacroDeclScope"),
            ("MacroExpansionDeclSyntax", "MacroExpansionDeclScope"),
        ]) { syntax, scope in
            """
            override func visit(_ node: \(syntax)) -> SyntaxVisitorContinueKind {
                self.result = ScopeCreator.constructExpandAndInsert(
                    of: \(scope)(syntax: node, parent: parent),
                    to: parent
                )

                return .skipChildren
            }
            """
        }
    }
}

extension DeclSyntaxProtocol {
    var isLocalContext: Bool {
        guard let parentContextKind else {
            return false
        }

        return parentContextKind != .sourceFile
    }
}

private extension DeclSyntaxProtocol {
    var parentContextKind: SyntaxKind? {
        guard let parent,
            parent.kind == .codeBlockItem,
            let grandParent = parent.parent,
            grandParent.kind == .codeBlockItemList
        else {
            return nil
        }

        return grandParent.parent?.kind
    }
}
