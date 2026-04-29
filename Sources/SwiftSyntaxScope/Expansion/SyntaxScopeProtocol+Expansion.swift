import SwiftSyntax

// MARK: - Core expansion machinery

extension SyntaxScopeProtocol {
    @discardableResult
    public func expandAndBeCurrent() -> any SyntaxScopeProtocol {
        assert(!isExpanded, "Cannot expand the same scope twice")
        isExpanded = true

        return expandSpecifically()
    }

    public var insertionPointForDeferredExpansion: (any SyntaxScopeProtocol)? { nil }

    public func addChild(_ child: any SyntaxScopeProtocol) {
        assert(child.parent != nil, "Child should not already have parent")

        children.append(child)
    }
}

public protocol CreateInsertion {
    func expandAScopeThatCreatesANewInsertionPoint() -> any SyntaxScopeProtocol
}

extension CreateInsertion {
    public func expandSpecifically() -> any SyntaxScopeProtocol {
        expandAScopeThatCreatesANewInsertionPoint()
    }
}

public protocol DoesNotCreateInsertion {
    func expandAScopeThatDoesNotCreateANewInsertionPoint()
}

extension DoesNotCreateInsertion where Self: SyntaxScopeProtocol {
    public func expandSpecifically() -> any SyntaxScopeProtocol {
        expandAScopeThatDoesNotCreateANewInsertionPoint()
        return parent!
    }
}

public protocol NoExpansion {}

extension NoExpansion where Self: SyntaxScopeProtocol {
    public func expandSpecifically() -> any SyntaxScopeProtocol {
        parent!
    }
}
