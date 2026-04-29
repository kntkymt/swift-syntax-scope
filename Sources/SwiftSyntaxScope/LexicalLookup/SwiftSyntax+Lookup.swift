import SwiftSyntax

extension PatternSyntax {
    var introducedNames: [LookupName] {
        if let identifierPattern = self.as(IdentifierPatternSyntax.self),
            identifierPattern.identifier.tokenKind != .wildcard
        {
            return [.identifier(SwiftSyntax.Syntax(identifierPattern))]
        }

        if let valueBinding = self.as(ValueBindingPatternSyntax.self) {
            return valueBinding.pattern.introducedNames
        }

        if let tuplePattern = self.as(TuplePatternSyntax.self) {
            return tuplePattern.elements.flatMap(\.pattern.introducedNames)
        }

        if let expressionPattern = self.as(ExpressionPatternSyntax.self) {
            return nestedPatternBindings(in: SwiftSyntax.Syntax(expressionPattern.expression))
        }

        return []
    }
}

extension VariableDeclSyntax {
    var introducedNames: [LookupName] {
        bindings.flatMap(\.pattern.introducedNames)
    }
}

extension DeclSyntaxProtocol {
    var introducedNames: [LookupName] {
        if let varDecl = self.as(VariableDeclSyntax.self) {
            return varDecl.introducedNames
        }

        if self.is(ActorDeclSyntax.self)
            || self.is(ClassDeclSyntax.self)
            || self.is(EnumDeclSyntax.self)
            || self.is(ProtocolDeclSyntax.self)
            || self.is(StructDeclSyntax.self)
            || self.is(TypeAliasDeclSyntax.self)
            || self.is(AssociatedTypeDeclSyntax.self)
        {
            return [.declaration(SwiftSyntax.Syntax(self))]
        }

        return []
    }
}

extension GenericParameterClauseSyntax {
    var introducedNames: [LookupName] {
        parameters.map { .identifier(SwiftSyntax.Syntax($0)) }
    }
}

extension [PatternSyntax?] {
    var introducedNames: [LookupName] {
        guard
            let firstOptional = first,
            let firstPattern = firstOptional
        else {
            return []
        }

        let firstIntroducedNames = firstPattern.introducedNames

        guard count > 1 else {
            return firstIntroducedNames
        }

        let commonNames = dropFirst().reduce(
            into: Set(firstIntroducedNames.map(\.text))
        ) { result, pattern in
            guard let pattern else {
                result.removeAll()
                return
            }

            result.formIntersection(Set(pattern.introducedNames.map(\.text)))
        }

        return firstIntroducedNames.filter { commonNames.contains($0.text) }
    }
}

private func nestedPatternBindings(in syntax: Syntax) -> [LookupName] {
    var results: [LookupName] = []

    for child in syntax.children(viewMode: .sourceAccurate) {
        if let patternExpr = child.as(PatternExprSyntax.self) {
            results.append(contentsOf: patternExpr.pattern.introducedNames)
        } else {
            results.append(contentsOf: nestedPatternBindings(in: child))
        }
    }

    return results
}
