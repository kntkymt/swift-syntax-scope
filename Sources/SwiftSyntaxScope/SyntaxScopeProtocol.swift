import SwiftSyntax

public protocol SyntaxScopeProtocol: AnyObject, CustomStringConvertible {
    associatedtype Syntax: SyntaxProtocol

    var syntax: Syntax { get }
    var parent: (any SyntaxScopeProtocol)? { get }
    var children: [any SyntaxScopeProtocol] { get set }
    var isExpanded: Bool { get set }

    var scopeTypeDescription: String { get }

    var range: Range<AbsolutePosition> { get }
    var sourceLocationConverter: SourceLocationConverter { get }
    var lookupParent: (any SyntaxScopeProtocol)? { get }

    @discardableResult
    func expandAndBeCurrent() -> any SyntaxScopeProtocol
    func expandSpecifically() -> any SyntaxScopeProtocol
    var insertionPointForDeferredExpansion: (any SyntaxScopeProtocol)? { get }

    func addChild(_ child: any SyntaxScopeProtocol)
    var introducedLookupNames: [LookupName] { get }
    func lookupLocalsOrMembers(name: Identifier?) -> [LookupName]
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

    public var sourceLocationConverter: SourceLocationConverter {
        parent?.sourceLocationConverter
            ?? SourceLocationConverter(fileName: "", tree: syntax.root)
    }

    public var introducedLookupNames: [LookupName] { [] }

    public func genericParameters() -> GenericParametersInfo? {
        nil
    }
}
