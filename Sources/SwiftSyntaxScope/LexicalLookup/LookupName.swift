import SwiftSyntax

/// An entity that is implicitly declared based on the syntactic structure of the program.
public enum ImplicitDecl {
    /// `self` keyword representing object instance.
    /// Introduced at member boundary.
    /// Associated syntax node could be: `FunctionDeclSyntax`,
    /// `AccessorDeclSyntax`, `SubscriptDeclSyntax`,
    /// `DeinitializerDeclSyntax`, or `InitializerDeclSyntax`.
    case `self`(DeclSyntax)
    /// `Self` keyword representing object type.
    /// Associated syntax node could be: `ExtensionDeclSyntax`,
    /// or `ProtocolDeclSyntax`.
    case `Self`(DeclSyntax)
    /// `error` available by default inside `catch`
    /// block that does not specify a catch pattern.
    case error(CatchClauseSyntax)
    /// `newValue` available by default inside `set` and `willSet`.
    case newValue(AccessorDeclSyntax)
    /// `oldValue` available by default inside `didSet`.
    case oldValue(AccessorDeclSyntax)

    /// Syntax associated with this name.
    var syntax: SyntaxProtocol {
        switch self {
        case .self(let syntax): return syntax
        case .Self(let syntax): return syntax
        case .error(let syntax): return syntax
        case .newValue(let syntax): return syntax
        case .oldValue(let syntax): return syntax
        }
    }

    /// The name of the implicit declaration.
    var name: StaticString {
        switch self {
        case .self: return "self"
        case .Self: return "Self"
        case .error: return "error"
        case .newValue: return "newValue"
        case .oldValue: return "oldValue"
        }
    }

    /// Identifier used for name comparison.
    var identifier: Identifier {
        Identifier(canonicalName: name)
    }

    /// Position of this implicit name.
    var position: AbsolutePosition {
        switch self {
        case .self(let declSyntax):
            switch Syntax(declSyntax).as(SyntaxEnum.self) {
            case .functionDecl(let functionDecl):
                return functionDecl.name.positionAfterSkippingLeadingTrivia
            case .initializerDecl(let initializerDecl):
                return initializerDecl.initKeyword.positionAfterSkippingLeadingTrivia
            case .subscriptDecl(let subscriptDecl):
                return subscriptDecl.accessorBlock?.positionAfterSkippingLeadingTrivia
                    ?? subscriptDecl.endPositionBeforeTrailingTrivia
            case .variableDecl(let variableDecl):
                return variableDecl.bindings.first?.accessorBlock?
                    .positionAfterSkippingLeadingTrivia
                    ?? variableDecl.bindings.positionAfterSkippingLeadingTrivia
            case .accessorDecl(let accessorDecl):
                return accessorDecl.accessorSpecifier.positionAfterSkippingLeadingTrivia
            case .deinitializerDecl(let deinitializerDecl):
                return deinitializerDecl.deinitKeyword.positionAfterSkippingLeadingTrivia
            default:
                return declSyntax.positionAfterSkippingLeadingTrivia
            }
        case .Self(let declSyntax):
            switch Syntax(declSyntax).as(SyntaxEnum.self) {
            case .protocolDecl(let protocolDecl):
                return protocolDecl.name.positionAfterSkippingLeadingTrivia
            case .extensionDecl(let extensionDecl):
                return extensionDecl.extensionKeyword.positionAfterSkippingLeadingTrivia
            default:
                return declSyntax.positionAfterSkippingLeadingTrivia
            }
        case .newValue(let accessorDecl), .oldValue(let accessorDecl):
            return accessorDecl.accessorSpecifier.positionAfterSkippingLeadingTrivia
        case .error(let catchClause):
            return catchClause.catchItems.positionAfterSkippingLeadingTrivia
        }
    }
}

public enum LookupName {
    public enum Kind {
        case identifier
        case declaration
        case implicit
    }

    /// Identifier associated with the name.
    /// Could be an identifier of a variable, function or closure parameter and more.
    case identifier(Syntax)
    /// Declaration associated with the name.
    /// Could be class, struct, actor, protocol, function and more.
    case declaration(Syntax)
    /// Name introduced implicitly by certain syntax nodes.
    case implicit(ImplicitDecl)

    public var kind: Kind {
        switch self {
        case .identifier: return .identifier
        case .declaration: return .declaration
        case .implicit: return .implicit
        }
    }

    /// Syntax associated with this name.
    public var syntax: SyntaxProtocol {
        switch self {
        case .identifier(let syntax): return syntax
        case .declaration(let syntax): return syntax
        case .implicit(let implicitName): return implicitName.syntax
        }
    }

    /// Position of this name.
    ///
    /// For some syntax nodes, their position doesn't reflect
    /// the position at which a particular name was introduced at.
    /// Such cases are function parameters (as they can
    /// contain two identifiers) and function declarations (where name
    /// is precided by access modifiers and `func` keyword).
    var position: AbsolutePosition {
        switch self {
        case .identifier(let syntax):
            return (syntax.asProtocol(SyntaxProtocol.self) as! IdentifiableSyntax).identifier
                .positionAfterSkippingLeadingTrivia
        case .declaration(let syntax):
            return (syntax.asProtocol(SyntaxProtocol.self) as! NamedDeclSyntax).name
                .positionAfterSkippingLeadingTrivia
        case .implicit(let implicitName):
            return implicitName.position
        }
    }

    /// Raw text of the introduced name (uses the source spelling, including backticks).
    public var text: String {
        switch self {
        case .identifier(let syntax):
            return (syntax.asProtocol(SyntaxProtocol.self) as! IdentifiableSyntax).identifier.text
        case .declaration(let syntax):
            return (syntax.asProtocol(SyntaxProtocol.self) as! NamedDeclSyntax).name.text
        case .implicit(let kind):
            return String(describing: kind.name)
        }
    }

    /// Canonical identifier used for name comparison (strips backticks).
    var identifier: Identifier? {
        switch self {
        case .identifier(let syntax):
            return Identifier(
                (syntax.asProtocol(SyntaxProtocol.self) as! IdentifiableSyntax).identifier
            )
        case .declaration(let syntax):
            return Identifier(
                (syntax.asProtocol(SyntaxProtocol.self) as! NamedDeclSyntax).name
            )
        case .implicit(let kind):
            return kind.identifier
        }
    }
}

extension LookupName {
    var dumpDescription: String {
        "\(kind):\(text)"
    }
}

extension [LookupName] {
    func filtered(byName name: Identifier?) -> [LookupName] {
        guard let name else {
            return self
        }

        return filter { $0.identifier == name }
    }
}
