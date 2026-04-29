import SwiftSyntax

protocol LabeledConditionalStmtScope: SyntaxScopeProtocol {
    var conditionElementListSyntax: ConditionElementListSyntax { get }
}

extension LabeledConditionalStmtScope {
    func createNestedConditionalClauseScopes(until lookupUpperBound: AbsolutePosition)
        -> any SyntaxScopeProtocol
    {
        var insertionPoint: any SyntaxScopeProtocol = self

        for conditionElement in conditionElementListSyntax {
            switch conditionElement.condition {
            case .expression(let expression):
                ScopeCreator.addToScopeTree(of: expression, to: insertionPoint)
            case .availability:
                break
            case .matchingPattern, .optionalBinding:
                insertionPoint = ScopeCreator.constructExpandAndInsert(
                    of: ConditionalClausePatternUseScope(
                        syntax: conditionElement,
                        parent: insertionPoint,
                        lookupUpperBound: lookupUpperBound
                    ),
                    to: insertionPoint
                )
            }
        }

        return insertionPoint
    }
}

protocol GenericTypeOrExtensionScopeProtocol: SyntaxScopeProtocol, CreateInsertion {
    var portion: Portion { get }
    var memberBlock: MemberBlockSyntax { get }
    var genericWhereClause: GenericWhereClauseSyntax? { get }
    var genericParameterScopeKinds: [GenericParameterScope.Kind] { get }
    var wholePortionAttributes: AttributeListSyntax? { get }

    init(syntax: Syntax, portion: Portion, parent: any SyntaxScopeProtocol)
}

extension GenericTypeOrExtensionScopeProtocol {
    public var insertionPointForDeferredExpansion: (any SyntaxScopeProtocol)? {
        switch portion {
        case .whole, .body: return parent
        case .where: return nil
        }
    }

    public func expandAScopeThatCreatesANewInsertionPoint() -> any SyntaxScopeProtocol {
        switch portion {
        case .whole:
            if let attributes = wholePortionAttributes {
                ScopeCreator.addCustomAttributeScopes(of: attributes, to: self)
            }

            let leaf = ScopeCreator.addNestedGenericParameterScopes(
                kinds: genericParameterScopeKinds,
                holderLookupUpperBound: sourceRange.upperBound,
                parent: self
            )

            if genericWhereClause != nil {
                ScopeCreator.constructExpandAndInsert(
                    of: Self(syntax: syntax, portion: .where, parent: leaf),
                    to: leaf
                )
            }
            ScopeCreator.constructExpandAndInsert(
                of: Self(syntax: syntax, portion: .body, parent: leaf),
                to: leaf
            )
            return parent!
        case .where:
            return parent!
        case .body:
            for member in memberBlock.members {
                ScopeCreator.addToScopeTree(of: member.decl, to: self)
            }
            return parent!
        }
    }
}

// MARK: - SourceFileScope

extension SourceFileScope: CreateInsertion {
    public func expandAScopeThatCreatesANewInsertionPoint() -> any SyntaxScopeProtocol {
        var insertionPoint: any SyntaxScopeProtocol = self
        for node in syntax.statements {
            if node.requiresTopLevelCodeScope {
                insertionPoint = ScopeCreator.constructExpandAndInsert(
                    of: TopLevelCodeScope(syntax: node, parent: insertionPoint),
                    to: insertionPoint
                )
                continue
            }

            ScopeCreator.addToScopeTree(of: node, to: insertionPoint)
        }

        return insertionPoint
    }
}

private extension CodeBlockItemSyntax {
    var requiresTopLevelCodeScope: Bool {
        if item.as(VariableDeclSyntax.self) != nil {
            return true
        }

        return item.as(DeclSyntax.self) == nil
    }
}

// MARK: - TopLevelCodeScope

extension TopLevelCodeScope: CreateInsertion {
    public func expandAScopeThatCreatesANewInsertionPoint() -> any SyntaxScopeProtocol {
        ScopeCreator.addToScopeTree(of: syntax, to: self)
    }
}

// MARK: - AbstractFunctionDeclScope

extension AbstractFunctionDeclScope: DoesNotCreateInsertion {
    var genericParameterScopeKinds: [GenericParameterScope.Kind] {
        guard let clause = kind.genericParameterClause else { return [] }
        return clause.parameters.map { .parameter($0) }
    }

    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        if let attributes = kind.attributes {
            ScopeCreator.addCustomAttributeScopes(of: attributes, to: self)
        }

        let leaf = ScopeCreator.addNestedGenericParameterScopes(
            kinds: genericParameterScopeKinds,
            holderLookupUpperBound: sourceRange.upperBound,
            parent: self
        )

        if let parameterClause = kind.parameterClause, !parameterClause.parameters.isEmpty {
            ScopeCreator.constructExpandAndInsert(
                of: ParameterListScope(kind: .function(parameterClause), parent: leaf),
                to: leaf
            )
        }

        if let body = kind.body {
            ScopeCreator.constructExpandAndInsert(
                of: FunctionBodyScope(syntax: body, parent: leaf),
                to: leaf
            )
        }
    }
}

extension AbstractFunctionDeclScope.Kind {
    var genericParameterClause: GenericParameterClauseSyntax? {
        switch self {
        case .function(let decl): return decl.genericParameterClause
        case .initializer(let decl): return decl.genericParameterClause
        case .deinitializer, .accessor, .implicitGetter: return nil
        }
    }
}

private extension AbstractFunctionDeclScope.Kind {
    var parameterClause: FunctionParameterClauseSyntax? {
        switch self {
        case .function(let decl): return decl.signature.parameterClause
        case .initializer(let decl): return decl.signature.parameterClause
        case .deinitializer, .accessor, .implicitGetter: return nil
        }
    }

    var body: (any SyntaxProtocol)? {
        switch self {
        case .function(let decl): return decl.body
        case .initializer(let decl): return decl.body
        case .deinitializer(let decl): return decl.body
        case .accessor(let decl): return decl.body
        case .implicitGetter(let block): return block
        }
    }

    var attributes: AttributeListSyntax? {
        switch self {
        case .function(let decl): return decl.attributes
        case .initializer(let decl): return decl.attributes
        case .deinitializer(let decl): return decl.attributes
        case .accessor(let decl): return decl.attributes
        case .implicitGetter: return nil
        }
    }
}

// MARK: - SubscriptDeclScope

extension SubscriptDeclScope: DoesNotCreateInsertion {
    var genericParameterScopeKinds: [GenericParameterScope.Kind] {
        guard let clause = syntax.genericParameterClause else { return [] }
        return clause.parameters.map { .parameter($0) }
    }

    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addCustomAttributeScopes(of: syntax.attributes, to: self)

        let leaf = ScopeCreator.addNestedGenericParameterScopes(
            kinds: genericParameterScopeKinds,
            holderLookupUpperBound: sourceRange.upperBound,
            parent: self
        )

        if !syntax.parameterClause.parameters.isEmpty {
            ScopeCreator.constructExpandAndInsert(
                of: ParameterListScope(kind: .function(syntax.parameterClause), parent: leaf),
                to: leaf
            )
        }

        guard let accessorBlock = syntax.accessorBlock else {
            return
        }

        switch accessorBlock.accessors {
        case .accessors(let accessors):
            for accessor in accessors {
                ScopeCreator.addToScopeTree(of: accessor, to: leaf)
            }
        case .getter:
            ScopeCreator.constructExpandAndInsert(
                of: AbstractFunctionDeclScope(
                    kind: .implicitGetter(accessorBlock),
                    parent: leaf
                ),
                to: leaf
            )
        }
    }
}

// MARK: - EnumElementScope

extension EnumElementScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        guard let parameterClause = syntax.parameterClause,
            !parameterClause.parameters.isEmpty
        else {
            return
        }

        ScopeCreator.constructExpandAndInsert(
            of: ParameterListScope(kind: .enumCase(parameterClause), parent: self),
            to: self
        )
    }
}

// MARK: - MacroDeclScope

extension MacroDeclScope: DoesNotCreateInsertion {
    var genericParameterScopeKinds: [GenericParameterScope.Kind] {
        guard let clause = syntax.genericParameterClause else { return [] }
        return clause.parameters.map { .parameter($0) }
    }

    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addCustomAttributeScopes(of: syntax.attributes, to: self)

        var leaf = ScopeCreator.addNestedGenericParameterScopes(
            kinds: genericParameterScopeKinds,
            holderLookupUpperBound: sourceRange.upperBound,
            parent: self
        )

        if !syntax.signature.parameterClause.parameters.isEmpty {
            leaf = ScopeCreator.constructExpandAndInsert(
                of: ParameterListScope(
                    kind: .function(syntax.signature.parameterClause),
                    parent: leaf
                ),
                to: leaf
            )
        }

        if let definition = syntax.definition {
            ScopeCreator.constructExpandAndInsert(
                of: MacroDefinitionScope(syntax: definition.value, parent: leaf),
                to: leaf
            )
        }
    }
}

// MARK: - MacroDefinitionScope

extension MacroDefinitionScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax, to: self)
    }
}

// MARK: - MacroExpansionDeclScope

extension MacroExpansionDeclScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        for arg in syntax.arguments {
            ScopeCreator.addToScopeTree(of: arg.expression, to: self)
        }

        if let trailingClosure = syntax.trailingClosure {
            ScopeCreator.addToScopeTree(of: trailingClosure, to: self)
        }

        for additional in syntax.additionalTrailingClosures {
            ScopeCreator.addToScopeTree(of: additional.closure, to: self)
        }
    }
}

// MARK: - CustomAttributeScope

extension CustomAttributeScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        guard case .argumentList(let args) = syntax.arguments else {
            return
        }

        for arg in args {
            ScopeCreator.addToScopeTree(of: arg.expression, to: self)
        }
    }
}

// MARK: - ParameterListScope

extension ParameterListScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        for defaultValue in kind.defaultValues {
            ScopeCreator.constructExpandAndInsert(
                of: DefaultArgumentInitializerScope(syntax: defaultValue, parent: self),
                to: self
            )
        }
    }
}

private extension ParameterListScope.Kind {
    var defaultValues: [ExprSyntax] {
        switch self {
        case .function(let clause):
            return clause.parameters.compactMap { $0.defaultValue?.value }
        case .enumCase(let clause):
            return clause.parameters.compactMap { $0.defaultValue?.value }
        }
    }
}

// MARK: - DefaultArgumentInitializerScope

extension DefaultArgumentInitializerScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax, to: self)
    }
}

// MARK: - FunctionBodyScope

extension FunctionBodyScope: DoesNotCreateInsertion {
    public var insertionPointForDeferredExpansion: (any SyntaxScopeProtocol)? { parent }

    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax, to: self)
    }
}

// MARK: - BraceStmtScope

extension BraceStmtScope: CreateInsertion {
    public func expandAScopeThatCreatesANewInsertionPoint() -> any SyntaxScopeProtocol {
        var insertionPoint: any SyntaxScopeProtocol = self
        for node in syntax {
            insertionPoint = ScopeCreator.addToScopeTree(of: node, to: insertionPoint)
        }

        return insertionPoint
    }
}

// MARK: - NominalTypeScope

extension NominalTypeScope: GenericTypeOrExtensionScopeProtocol {
    var wholePortionAttributes: AttributeListSyntax? { attributes }

    var genericParameterScopeKinds: [GenericParameterScope.Kind] {
        guard let genericParameterClause else { return [] }
        return genericParameterClause.parameters.map { .parameter($0) }
    }
}

// MARK: - ExtensionScope

extension ExtensionScope: GenericTypeOrExtensionScopeProtocol {
    // Extension attributes are attached as siblings of the ExtensionScope rather than
    // children of `.whole`, because `.whole`'s source range starts past the extended
    // type and would not contain the attribute range.
    var wholePortionAttributes: AttributeListSyntax? { nil }

    var genericParameterScopeKinds: [GenericParameterScope.Kind] {
        guard let clause = extendedTypeGenericArgumentClause else { return [] }
        return clause.arguments.map { .argument($0) }
    }
}

// MARK: - TypeAliasScope

extension TypeAliasScope: CreateInsertion {
    public var insertionPointForDeferredExpansion: (any SyntaxScopeProtocol)? {
        switch portion {
        case .whole: return parent
        case .where: return nil
        }
    }

    var genericParameterScopeKinds: [GenericParameterScope.Kind] {
        guard let clause = syntax.genericParameterClause else { return [] }
        return clause.parameters.map { .parameter($0) }
    }

    public func expandAScopeThatCreatesANewInsertionPoint() -> any SyntaxScopeProtocol {
        switch portion {
        case .whole:
            ScopeCreator.addCustomAttributeScopes(of: syntax.attributes, to: self)

            let leaf = ScopeCreator.addNestedGenericParameterScopes(
                kinds: genericParameterScopeKinds,
                holderLookupUpperBound: sourceRange.upperBound,
                parent: self
            )

            if syntax.genericWhereClause != nil {
                ScopeCreator.constructExpandAndInsert(
                    of: TypeAliasScope(syntax: syntax, portion: .where, parent: leaf),
                    to: leaf
                )
            }

            return parent!
        case .where:
            return parent!
        }
    }
}

// MARK: - GenericParameterScope

extension GenericParameterScope: NoExpansion {
    public var insertionPointForDeferredExpansion: (any SyntaxScopeProtocol)? { self }
}

// MARK: - CaptureListScope

extension CaptureListScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.constructExpandAndInsert(
            of: ClosureParametersScope(syntax: syntax, parent: self),
            to: self
        )
    }
}

// MARK: - ClosureParametersScope

extension ClosureParametersScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        guard !syntax.statements.isEmpty else {
            return
        }

        let decls = scanLocalDecls(in: syntax.statements)

        ScopeCreator.constructExpandAndInsert(
            of: BraceStmtScope(
                syntax: syntax.statements,
                parent: self,
                braceRange: sourceRange,
                localFuncs: decls.localFuncs,
                localTypes: decls.localTypes
            ),
            to: self
        )
    }
}

// MARK: - IfExprScope

extension IfExprScope: LabeledConditionalStmtScope, DoesNotCreateInsertion {
    var conditionElementListSyntax: ConditionElementListSyntax {
        syntax.conditions
    }

    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        let insertionPoint = createNestedConditionalClauseScopes(
            until: syntax.body.trimmedRange.upperBound
        )

        ScopeCreator.addToScopeTree(of: syntax.body, to: insertionPoint)

        if let elseBody = syntax.elseBody {
            ScopeCreator.addToScopeTree(of: elseBody, to: self)
        }
    }
}

// MARK: - WhileStmtScope

extension WhileStmtScope: LabeledConditionalStmtScope, DoesNotCreateInsertion {
    var conditionElementListSyntax: ConditionElementListSyntax {
        syntax.conditions
    }

    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        let insertionPoint = createNestedConditionalClauseScopes(
            until: syntax.body.trimmedRange.upperBound
        )

        ScopeCreator.addToScopeTree(of: syntax.body, to: insertionPoint)
    }
}

// MARK: - RepeatWhileScope

extension RepeatWhileScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax.body, to: self)
        ScopeCreator.addToScopeTree(of: syntax.condition, to: self)
    }
}

// MARK: - ForEachStmtScope

extension ForEachStmtScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax.sequence, to: self)

        ScopeCreator.constructExpandAndInsert(
            of: ForEachPatternScope(syntax: syntax, parent: self),
            to: self
        )
    }
}

// MARK: - ForEachPatternScope

extension ForEachPatternScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        if let whereClause = syntax.whereClause {
            ScopeCreator.addToScopeTree(of: whereClause, to: self)
        }

        ScopeCreator.addToScopeTree(of: syntax.body, to: self)
    }
}

// MARK: - DoStmtScope

extension DoStmtScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax.body, to: self)

        for catchClause in syntax.catchClauses {
            ScopeCreator.constructExpandAndInsert(
                of: CaseStmtScope(kind: .catchClause(catchClause), parent: self),
                to: self
            )
        }
    }
}

// MARK: - SwitchExprScope

extension SwitchExprScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax.subject, to: self)

        for case let .switchCase(switchCase) in syntax.cases {
            ScopeCreator.constructExpandAndInsert(
                of: CaseStmtScope(kind: .switchCase(switchCase), parent: self),
                to: self
            )
        }
    }
}

// MARK: - CaseStmtScope

extension CaseStmtScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        for item in kind.caseItemKinds where item.whereClause != nil {
            ScopeCreator.constructExpandAndInsert(
                of: CaseLabelItemScope(kind: item, parent: self),
                to: self
            )
        }

        if !kind.bodyStatements.isEmpty {
            ScopeCreator.constructExpandAndInsert(
                of: CaseStmtBodyScope(kind: kind, parent: self),
                to: self
            )
        }
    }
}

private extension CaseStmtScope.Kind {
    var caseItemKinds: [CaseLabelItemScope.Kind] {
        switch self {
        case .catchClause(let catchClause):
            return catchClause.catchItems.map { .catchItem($0) }
        case .switchCase(let switchCase):
            guard case .case(let label) = switchCase.label else {
                return []
            }

            return label.caseItems.map { .switchCaseItem($0) }
        }
    }

    var bodyStatements: CodeBlockItemListSyntax {
        switch self {
        case .catchClause(let catchClause):
            return catchClause.body.statements
        case .switchCase(let switchCase):
            return switchCase.statements
        }
    }
}

// MARK: - CaseLabelItemScope

extension CaseLabelItemScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        guard let whereClause = kind.whereClause else {
            return
        }

        ScopeCreator.addToScopeTree(of: whereClause, to: self)
    }
}

// MARK: - CaseStmtBodyScope

extension CaseStmtBodyScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        switch kind {
        case .catchClause(let catchClause):
            ScopeCreator.addToScopeTree(of: catchClause.body, to: self)
        case .switchCase(let switchCase):
            ScopeCreator.addToScopeTree(of: switchCase.statements, to: self)
        }
    }
}

// MARK: - GuardStmtScope

extension GuardStmtScope: LabeledConditionalStmtScope, CreateInsertion {
    var conditionElementListSyntax: ConditionElementListSyntax {
        syntax.conditions
    }

    public func expandAScopeThatCreatesANewInsertionPoint() -> any SyntaxScopeProtocol {
        let conditionInsertionPoint = createNestedConditionalClauseScopes(until: lookupUpperBound)

        if !syntax.body.statements.isEmpty {
            ScopeCreator.constructExpandAndInsert(
                of: GuardStmtBodyScope(
                    syntax: syntax.body,
                    parent: conditionInsertionPoint,
                    lookupParent: self
                ),
                to: conditionInsertionPoint
            )
        }

        return conditionInsertionPoint
    }
}

// MARK: - GuardStmtBodyScope

extension GuardStmtBodyScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax, to: self)
    }
}

// MARK: - ConditionalClausePatternUseScope

extension ConditionalClausePatternUseScope: CreateInsertion {
    public func expandAScopeThatCreatesANewInsertionPoint() -> any SyntaxScopeProtocol {
        guard let conditionInitializer else {
            preconditionFailure("Conditional clause scope requires a pattern binding")
        }

        return ScopeCreator.constructExpandAndInsert(
            of: ConditionalClauseInitializerScope(syntax: conditionInitializer, parent: self),
            to: self
        )
    }
}

private extension ConditionalClausePatternUseScope {
    var conditionInitializer: InitializerClauseSyntax? {
        switch syntax.condition {
        case .matchingPattern(let matchingPattern):
            return matchingPattern.initializer
        case .optionalBinding(let optionalBinding):
            return optionalBinding.initializer
        case .expression, .availability:
            return nil
        }
    }
}

// MARK: - ConditionalClauseInitializerScope

extension ConditionalClauseInitializerScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax, to: self)
    }
}

// MARK: - PatternEntryDeclScope

extension PatternEntryDeclScope: CreateInsertion {
    public func expandAScopeThatCreatesANewInsertionPoint() -> any SyntaxScopeProtocol {
        let patternEntry = syntax.bindings[bindingIndex]
        let pattern = patternEntry.pattern

        let leaf = self

        if let expr = patternEntry.initializer?.value {
            ScopeCreator.constructExpandAndInsert(
                of: PatternEntryInitializerScope(syntax: expr, parent: leaf),
                to: leaf
            )
        }

        // TODO: support tuple
        if let identifier = pattern.as(IdentifierPatternSyntax.self) {
            // あってる？
            ScopeCreator.addToScopeTree(of: identifier, to: leaf)
        }

        if let accessorBlock = patternEntry.accessorBlock {
            switch accessorBlock.accessors {
            case .accessors(let accessors):
                for accessor in accessors {
                    ScopeCreator.addToScopeTree(of: accessor, to: leaf)
                }
            case .getter:
                ScopeCreator.constructExpandAndInsert(
                    of: AbstractFunctionDeclScope(
                        kind: .implicitGetter(accessorBlock),
                        parent: leaf
                    ),
                    to: leaf
                )
            }
        }

        if isLocalBinding {
            return self
        }

        return parent!
    }
}

// MARK: - PatternEntryInitializerScope

extension PatternEntryInitializerScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax, to: self)
    }
}

// MARK: - TryScope

extension TryScope: DoesNotCreateInsertion {
    public func expandAScopeThatDoesNotCreateANewInsertionPoint() {
        ScopeCreator.addToScopeTree(of: syntax.expression, to: self)
    }
}
