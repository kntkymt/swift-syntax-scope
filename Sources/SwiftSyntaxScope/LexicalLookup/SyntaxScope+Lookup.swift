import SwiftSyntax

public struct LookupOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let includeOuterResults = Self(rawValue: 1 << 0)
}

public extension SourceFileSyntax {
    // entry of lookup
    func lexicalLookup(
        position: AbsolutePosition,
        name: Identifier?,
        options: LookupOptions = []
    ) -> [LookupResult] {
        SourceFileScope(syntax: self).lexicalLookup(
            position: position,
            name: name,
            options: options
        )
    }

    func findStartingScopeForLookup(position: AbsolutePosition)
    -> any SyntaxScopeProtocol
    {
        SourceFileScope(syntax: self).findStartingScopeForLookup(position: position)
    }
}

public extension SourceFileScope {
    // entry of lookup
    func lexicalLookup(
        position: AbsolutePosition,
        name: Identifier?,
        options: LookupOptions = []
    ) -> [LookupResult] {
        let startScope = self.findStartingScopeForLookup(position: position)

        let results = startScope.lookup(
            name: name,
            options: options,
            limit: nil,
            lastListSearched: nil,
            position: position
        )

        return deduplicateLookupResults(results)
    }

    func findStartingScopeForLookup(position: AbsolutePosition)
    -> any SyntaxScopeProtocol
    {
        var current: any SyntaxScopeProtocol = self

        while true {
            if !current.isExpanded {
                current.expandAndBeCurrent()
            }

            guard let child = current.children.last(where: { $0.range.contains(position) })
            else {
                return current
            }

            current = child
        }
    }
}

extension SyntaxScopeProtocol {
    public func lookupLocalsOrMembers(name: Identifier?) -> [LookupResult] {
        var results: [LookupResult] = []

        let locals = introducedLocalLookupNames.filtered(byName: name)
        if !locals.isEmpty {
            results.append(.fromScope(self, withNames: locals))
        }

        let members = introducedMemberLookupNames.filtered(byName: name)
        if !members.isEmpty {
            results.append(.fromMembers(self, withNames: members))
        }

        return results
    }

    func lookup(
        name: Identifier?,
        options: LookupOptions,
        limit: (any SyntaxScopeProtocol)?,
        lastListSearched: SyntaxIdentifier?,
        position: AbsolutePosition
    ) -> [LookupResult] {
        if let limit, refersToSameScope(self, as: limit) {
            return []
        }

        var results: [LookupResult] = []

        // Look for generics before members in violation of lexical ordering because
        // you can say "self.name" to get a name shadowed by a generic but you
        // can't do the opposite to get a generic shadowed by a name.
        let (genericResults, listSearched) = lookInMyGenericParameters(
            name: name,
            lastListSearched: lastListSearched
        )
        results.append(contentsOf: genericResults)
        if !genericResults.isEmpty, !options.contains(.includeOuterResults) {
            return results
        }

        let localOrMembers = lookupLocalsOrMembers(name: name)
        results.append(contentsOf: localOrMembers)
        if !localOrMembers.isEmpty, !options.contains(.includeOuterResults) {
            return results
        }

        guard let parent = lookupParent else {
            return results
        }

        results.append(
            contentsOf: parent.lookup(
                name: name,
                options: options,
                limit: limit,
                lastListSearched: listSearched,
                position: position
            )
        )

        return results
    }

    func lookInMyGenericParameters(
        name: Identifier?,
        lastListSearched: SyntaxIdentifier?
    ) -> (results: [LookupResult], listSearched: SyntaxIdentifier?) {
        guard let info = genericParameters() else {
            return ([], lastListSearched)
        }

        if info.identity == lastListSearched {
            return ([], lastListSearched)
        }

        let filtered = info.names.filtered(byName: name)
        guard !filtered.isEmpty else {
            return ([], info.identity)
        }

        return ([.fromScope(self, withNames: filtered)], info.identity)
    }
}

func refersToSameScope(_ lhs: any SyntaxScopeProtocol, as rhs: any SyntaxScopeProtocol) -> Bool {
    ObjectIdentifier(lhs as AnyObject) == ObjectIdentifier(rhs as AnyObject)
}

extension TopLevelCodeScope {
    public var introducedLocalLookupNames: [LookupName] {
        guard let variableDecl = syntax.item.as(VariableDeclSyntax.self) else {
            return []
        }

        return variableDecl.bindings.reversed().flatMap(\.pattern.introducedNames)
    }
}

extension FunctionBodyScope {
    public var introducedLocalLookupNames: [LookupName] {
        var ancestor: (any SyntaxScopeProtocol)? = parent
        while let current = ancestor {
            if let fn = current as? AbstractFunctionDeclScope {
                var results = fn.kind.parameterLookupResults
                if isMemberContext(of: fn), let selfDecl = implicitSelfDeclSyntax(for: fn) {
                    results.append(.implicit(.self(selfDecl)))
                }
                return results
            }
            ancestor = current.parent
        }
        return []
    }
}

private func isMemberContext(of scope: any SyntaxScopeProtocol) -> Bool {
    var current: (any SyntaxScopeProtocol)? = scope.parent
    while let s = current {
        if let n = s as? NominalTypeScope, n.portion == .body { return true }
        if let e = s as? ExtensionScope, e.portion == .body { return true }
        current = s.parent
    }
    return false
}

private func implicitSelfDeclSyntax(for scope: AbstractFunctionDeclScope) -> DeclSyntax? {
    switch scope.kind {
    case .function(let decl): return DeclSyntax(decl)
    case .initializer(let decl): return DeclSyntax(decl)
    case .deinitializer(let decl): return DeclSyntax(decl)
    case .accessor(let decl): return DeclSyntax(decl)
    case .implicitGetter:
        var current: (any SyntaxScopeProtocol)? = scope.parent
        while let s = current {
            if let pat = s as? PatternEntryDeclScope { return DeclSyntax(pat.syntax) }
            if let sub = s as? SubscriptDeclScope { return DeclSyntax(sub.syntax) }
            current = s.parent
        }
        return nil
    }
}

extension AbstractFunctionDeclScope.Kind {
    var parameterLookupResults: [LookupName] {
        switch self {
        case .function(let decl):
            return parameterClauseLookupResults(decl.signature.parameterClause)
        case .initializer(let decl):
            return parameterClauseLookupResults(decl.signature.parameterClause)
        case .deinitializer, .implicitGetter:
            return []
        case .accessor(let decl):
            return accessorLookupResults(decl)
        }
    }
}

internal func parameterClauseLookupResults(
    _ parameterClause: FunctionParameterClauseSyntax
) -> [LookupName] {
    parameterClause.parameters.compactMap { parameter -> LookupName? in
        guard parameter.identifier.tokenKind != .wildcard else {
            return nil
        }

        return .identifier(SwiftSyntax.Syntax(parameter))
    }
}

private func accessorLookupResults(
    _ decl: AccessorDeclSyntax
) -> [LookupName] {
    if let explicit = decl.parameters {
        return [.identifier(SwiftSyntax.Syntax(explicit))]
    }

    switch decl.accessorSpecifier.tokenKind {
    case .keyword(.set), .keyword(.willSet):
        return [.implicit(.newValue(decl))]
    case .keyword(.didSet):
        return [.implicit(.oldValue(decl))]
    default:
        return []
    }
}

extension AbstractFunctionDeclScope {
    public func genericParameters() -> GenericParametersInfo? {
        guard let clause = kind.genericParameterClause else { return nil }
        return GenericParametersInfo(
            identity: clause.id,
            names: clause.introducedNames
        )
    }
}

extension SubscriptDeclScope {
    public var introducedLocalLookupNames: [LookupName] {
        parameterClauseLookupResults(syntax.parameterClause)
    }

    public func genericParameters() -> GenericParametersInfo? {
        guard let clause = syntax.genericParameterClause else { return nil }
        return GenericParametersInfo(
            identity: clause.id,
            names: clause.introducedNames
        )
    }
}

extension MacroDeclScope {
    public var introducedLocalLookupNames: [LookupName] {
        parameterClauseLookupResults(syntax.signature.parameterClause)
    }

    public func genericParameters() -> GenericParametersInfo? {
        guard let clause = syntax.genericParameterClause else { return nil }
        return GenericParametersInfo(
            identity: clause.id,
            names: clause.introducedNames
        )
    }
}

extension NominalTypeScope {
    public func genericParameters() -> GenericParametersInfo? {
        guard let clause = genericParameterClause else { return nil }
        return GenericParametersInfo(
            identity: clause.id,
            names: clause.introducedNames
        )
    }
}

extension ExtensionScope {
    public func genericParameters() -> GenericParametersInfo? {
        guard let clause = extendedTypeGenericArgumentClause else { return nil }

        let names: [LookupName] = clause.arguments.compactMap { arg in
            guard case .type(let type) = arg.argument else { return nil }
            guard let ident = type.as(IdentifierTypeSyntax.self) else { return nil }
            return .identifier(SwiftSyntax.Syntax(ident))
        }
        guard !names.isEmpty else { return nil }

        return GenericParametersInfo(identity: clause.id, names: names)
    }
}

extension CaptureListScope {
    public var introducedLocalLookupNames: [LookupName] {
        captureItems.map { item -> LookupName in
            .identifier(SwiftSyntax.Syntax(item))
        }
    }
}

extension ClosureParametersScope {
    public var introducedLocalLookupNames: [LookupName] {
        guard let parameterClause = syntax.signature?.parameterClause else {
            return []
        }

        switch parameterClause {
        case .simpleInput(let list):
            return list.compactMap { parameter -> LookupName? in
                guard parameter.name.tokenKind != .wildcard else {
                    return nil
                }
                return .identifier(SwiftSyntax.Syntax(parameter))
            }
        case .parameterClause(let clause):
            return clause.parameters.compactMap { parameter -> LookupName? in
                guard parameter.identifier.tokenKind != .wildcard else {
                    return nil
                }
                return .identifier(SwiftSyntax.Syntax(parameter))
            }
        }
    }
}

extension GenericParameterScope {
    public var introducedLocalLookupNames: [LookupName] {
        switch kind {
        case .parameter(let p):
            return [.identifier(SwiftSyntax.Syntax(p))]
        case .argument(let a):
            switch a.argument {
            case .type(let t):
                guard let ident = t.as(IdentifierTypeSyntax.self) else { return [] }
                return [.identifier(SwiftSyntax.Syntax(ident))]
            default:
                return []
            }
        }
    }
}

extension BraceStmtScope {
    public var introducedLocalLookupNames: [LookupName] {
        let localFuncResults: [LookupName] = localFuncs.map { decl -> LookupName in
            .declaration(SwiftSyntax.Syntax(decl))
        }

        let localTypeResults = localTypes.flatMap(\.introducedNames)

        return (localFuncResults + localTypeResults).sorted {
            $0.position > $1.position
        }
    }
}

extension NominalTypeScope {
    public var introducedLocalLookupNames: [LookupName] {
        switch portion {
        case .whole:
            // whole doesn't introduce their own name, it's handled by top level lookup
            if syntax.is(ProtocolDeclSyntax.self) {
                return [.implicit(.Self(DeclSyntax(syntax)))]
            }

            return []
        case .where, .body:
            return []
        }
    }

    public var introducedMemberLookupNames: [LookupName] {
        switch portion {
        case .whole, .where:
            return []
        case .body:
            return bodyMemberLookupNames
        }
    }
}

extension ExtensionScope {
    public var introducedLocalLookupNames: [LookupName] {
        switch portion {
        case .whole, .where:
            // 参考実装 (ExtensionDeclSyntax.lookup) は memberBlock 範囲内のみ
            // .implicit(.Self) を導入する。 where clause / inheritance clause /
            // extended type 内の Self は SyntaxScope ではなく type-checker 側で
            // extended type として解決される設計のため、ここでは導入しない。
            return []
        case .body:
            return [.implicit(.Self(DeclSyntax(syntax)))]
        }
    }

    public var introducedMemberLookupNames: [LookupName] {
        switch portion {
        case .whole, .where:
            return []
        case .body:
            return bodyMemberLookupNames
        }
    }
}

extension GenericTypeOrExtensionScopeProtocol {
    var bodyMemberLookupNames: [LookupName] {
        let localFuncResults: [LookupName] = memberBlock.members.compactMap {
            member -> LookupName? in
            guard let decl = member.decl.as(FunctionDeclSyntax.self) else {
                return nil
            }

            return .declaration(SwiftSyntax.Syntax(decl))
        }

        let localOtherResults = memberBlock.members.flatMap(\.decl.introducedNames)

        return (localFuncResults + localOtherResults).sorted {
            $0.position > $1.position
        }
    }
}

extension PatternEntryDeclScope {
    public var introducedLocalLookupNames: [LookupName] {
        guard isLocalBinding else {
            return []
        }

        let binding = syntax.bindings[bindingIndex]

        return binding.pattern.introducedNames
    }
}

extension PatternEntryInitializerScope {
    public var lookupParent: (any SyntaxScopeProtocol)? {
        guard let patternEntryDeclScope = parent as? PatternEntryDeclScope else {
            return parent?.lookupParent
        }

        if !patternEntryDeclScope.isLocalBinding,
            let typeScope = patternEntryDeclScope.parent
                as? any GenericTypeOrExtensionScopeProtocol,
            typeScope.portion == .body
        {
            return patternEntryDeclScope.parent?.lookupParent
        }

        return patternEntryDeclScope.lookupParent
    }
}

extension ForEachPatternScope {
    public var introducedLocalLookupNames: [LookupName] {
        syntax.pattern.introducedNames
    }
}

extension CaseLabelItemScope {
    public var introducedLocalLookupNames: [LookupName] {
        guard let pattern = kind.pattern else {
            return []
        }

        return pattern.introducedNames
    }
}

extension CaseStmtBodyScope {
    public var introducedLocalLookupNames: [LookupName] {
        let optionalPatterns: [PatternSyntax?]
        switch kind {
        case .catchClause(let catchClause):
            optionalPatterns = catchClause.catchItems.map { $0.pattern }

            let names = optionalPatterns.introducedNames
            if names.isEmpty {
                let containsExpressionPattern = optionalPatterns.contains {
                    $0?.is(ExpressionPatternSyntax.self) ?? false
                }
                if !containsExpressionPattern {
                    return [.implicit(.error(catchClause))]
                }
            }
            return names
        case .switchCase(let switchCase):
            guard case .case(let label) = switchCase.label else {
                return []
            }
            optionalPatterns = label.caseItems.map { $0.pattern }
        }

        return optionalPatterns.introducedNames
    }
}

extension ConditionalClausePatternUseScope {
    public var introducedLocalLookupNames: [LookupName] {
        guard let conditionPattern else {
            return []
        }

        return conditionPattern.introducedNames
    }
}

extension ConditionalClauseInitializerScope {
    public var lookupParent: (any SyntaxScopeProtocol)? {
        parent?.lookupParent
    }
}

