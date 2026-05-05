import SwiftSyntax

public protocol SyntaxScopeProtocol: AnyObject, CustomStringConvertible {
    associatedtype Syntax: SyntaxProtocol

    var syntax: Syntax { get }
    var parent: (any SyntaxScopeProtocol)? { get }
    var children: [any SyntaxScopeProtocol] { get set }
    var isExpanded: Bool { get set }

    var scopeTypeDescription: String { get }

    var range: Range<AbsolutePosition> { get }
    var lookupParent: (any SyntaxScopeProtocol)? { get }

    @discardableResult
    func expandAndBeCurrent() -> any SyntaxScopeProtocol
    func expandSpecifically() -> any SyntaxScopeProtocol
    var insertionPointForDeferredExpansion: (any SyntaxScopeProtocol)? { get }

    func addChild(_ child: any SyntaxScopeProtocol)
    var introducedLocalLookupNames: [LookupName] { get }
    var introducedMemberLookupNames: [LookupName] { get }
    func lookupLocalsOrMembers(name: Identifier?) -> [LookupResult]
    func genericParameters() -> GenericParametersInfo?
}

public struct GenericParametersInfo {
    let identity: SyntaxIdentifier
    let names: [LookupName]
}

extension SyntaxScopeProtocol {
    public var lookupParent: (any SyntaxScopeProtocol)? {
        parent
    }

    public var range: Range<AbsolutePosition> {
        syntax.trimmedRange
    }

    public var introducedLocalLookupNames: [LookupName] { [] }

    public var introducedMemberLookupNames: [LookupName] { [] }

    public func genericParameters() -> GenericParametersInfo? {
        nil
    }

    public func sourceRange(
        converter: SourceLocationConverter,
        afterLeadingTrivia: Bool = true,
        afterTrailingTrivia: Bool = false
    ) -> SourceRange {
        SourceRange(
            start: converter.location(for: range.lowerBound),
            end: converter.location(for: range.upperBound)
        )
    }
}

extension SourceRange {
    var description: String {
        // SourceRange uses half-open (..<) semantics; render the upper bound
        // inclusively for display.
        let displayedEndColumn = start == end ? end.column : end.column - 1
        return "[\(start.line):\(start.column) - \(end.line):\(displayedEndColumn)]"
    }
}
