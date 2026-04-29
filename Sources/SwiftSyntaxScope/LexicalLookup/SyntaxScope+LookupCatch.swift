import SwiftSyntax

enum CatchNode {
    case function(AbstractFunctionDeclScope.Kind)
    case closure(ClosureExprSyntax)
    case doCatch(DoStmtSyntax)
    case anyTry(TryExprSyntax)

    var function: AbstractFunctionDeclScope.Kind? {
        guard case .function(let kind) = self else { return nil }
        return kind
    }

    var closure: ClosureExprSyntax? {
        guard case .closure(let closure) = self else { return nil }
        return closure
    }

    var doCatch: DoStmtSyntax? {
        guard case .doCatch(let doStmt) = self else { return nil }
        return doStmt
    }

    var anyTry: TryExprSyntax? {
        guard case .anyTry(let tryExpr) = self else { return nil }
        return tryExpr
    }

    var isFunction: Bool { function != nil }
    var isClosure: Bool { closure != nil }
    var isDoCatch: Bool { doCatch != nil }
    var isAnyTry: Bool { anyTry != nil }

    var position: AbsolutePosition {
        switch self {
        case .function(.function(let d)): return d.positionAfterSkippingLeadingTrivia
        case .function(.initializer(let d)): return d.positionAfterSkippingLeadingTrivia
        case .function(.deinitializer(let d)): return d.positionAfterSkippingLeadingTrivia
        case .function(.accessor(let d)): return d.positionAfterSkippingLeadingTrivia
        case .function(.implicitGetter(let b)): return b.positionAfterSkippingLeadingTrivia
        case .closure(let c): return c.positionAfterSkippingLeadingTrivia
        case .doCatch(let d): return d.positionAfterSkippingLeadingTrivia
        case .anyTry(let t): return t.positionAfterSkippingLeadingTrivia
        }
    }
}

extension SourceFileSyntax {
    func lookupCatchNode(at position: AbsolutePosition) -> CatchNode? {
        let innermost = findStartingScopeForLookup(position: position)

        var innerBodyScope: BraceStmtScope? = nil
        var current: (any SyntaxScopeProtocol)? = innermost

        while let scope = current {
            if let body = innerBodyScope,
                let bodyParent = body.parent,
                refersToSameScope(scope, as: bodyParent)
            {
                if let caught = catchNode(of: scope),
                    !locationIsPriorToStartOfCatchScope(position: position, node: caught)
                {
                    return caught
                }
            }

            if let tryScope = scope as? TryScope,
                tryScope.syntax.questionOrExclamationMark != nil
            {
                return .anyTry(tryScope.syntax)
            }

            innerBodyScope = scope as? BraceStmtScope
            current = scope.parent
        }

        return nil
    }
}

private func catchNode(of scope: any SyntaxScopeProtocol) -> CatchNode? {
    if let closureParams = scope as? ClosureParametersScope {
        return .closure(closureParams.syntax)
    }

    if scope is FunctionBodyScope {
        var ancestor = scope.parent
        while let current = ancestor {
            if let fn = current as? AbstractFunctionDeclScope {
                return .function(fn.kind)
            }
            ancestor = current.parent
        }
        return nil
    }

    if let doStmt = scope as? DoStmtScope, !doStmt.syntax.catchClauses.isEmpty {
        return .doCatch(doStmt.syntax)
    }

    return nil
}

private func locationIsPriorToStartOfCatchScope(
    position: AbsolutePosition,
    node: CatchNode
) -> Bool {
    guard case .closure(let closure) = node else {
        return false
    }

    if let signature = closure.signature {
        return position < signature.inKeyword.positionAfterSkippingLeadingTrivia
    }

    return position <= closure.positionAfterSkippingLeadingTrivia
}
