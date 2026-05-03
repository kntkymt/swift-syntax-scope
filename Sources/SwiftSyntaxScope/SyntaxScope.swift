import SwiftSyntax

/// Root scope spanning a single Swift source file.
///
/// ```
/// // ← scope start (top of file)
/// let x = 1
/// struct S {}
/// // x and S are visible here
/// // ← scope end (end of file)
/// ```
public final class SourceFileScope: SyntaxScopeProtocol {
    public typealias Syntax = SourceFileSyntax

    public let syntax: Syntax

    public init(syntax: SourceFileSyntax) {
        self.syntax = syntax
    }

    public var parent: (any SyntaxScopeProtocol)? {
        nil
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "SourceFileScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a single top-level statement in a script source file.
/// Each top-level item gets its own scope so that earlier statements introduce names visible to later ones.
///
/// ```
/// let x = 1     // ← scope start (this top-level item)
/// print(x)      // x is visible here (and in following top-level items)
/// // ← scope end (extends through the rest of the file)
/// ```
public final class TopLevelCodeScope: SyntaxScopeProtocol {
    public typealias Syntax = CodeBlockItemSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "TopLevelCodeScope" }

    public var range: Range<AbsolutePosition> {
        syntax.trimmedRange.lowerBound..<lookupUpperBound
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }

    var lookupUpperBound: AbsolutePosition {
        parent?.range.upperBound ?? syntax.trimmedRange.upperBound
    }
}

/// Scope for a function-like declaration. Hosts the parameter list and the body.
///
/// Kind variants:
///
/// - `.function`: `func` declaration
///   ```
///   func f(x: Int) {  // ← scope start
///       // x is visible here
///   }                 // ← scope end
///   ```
///
/// - `.initializer`: `init` declaration
///   ```
///   init(x: Int) {    // ← scope start
///       // x is visible here
///   }                 // ← scope end
///   ```
///
/// - `.deinitializer`: `deinit` declaration
///   ```
///   deinit {          // ← scope start
///       // self is visible here
///   }                 // ← scope end
///   ```
///
/// - `.accessor`: explicit `get` / `set` / `willSet` / `didSet`
///   ```
///   var x: Int {
///       set(newX) {   // ← scope start
///           // newX is visible here
///       }             // ← scope end
///   }
///   ```
///
/// - `.implicitGetter`: implicit getter form
///   ```
///   var x: Int {      // ← scope start (the brace block)
///       1             // implicit getter body
///   }                 // ← scope end
///   ```
public final class AbstractFunctionDeclScope: SyntaxScopeProtocol {
    public typealias Syntax = SwiftSyntax.Syntax

    public enum Kind {
        case function(FunctionDeclSyntax)
        case initializer(InitializerDeclSyntax)
        case deinitializer(DeinitializerDeclSyntax)
        case accessor(AccessorDeclSyntax)
        case implicitGetter(AccessorBlockSyntax)
    }

    public let kind: Kind
    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(kind: Kind, parent: (any SyntaxScopeProtocol)?) {
        self.kind = kind
        switch kind {
        case .function(let decl): self.syntax = SwiftSyntax.Syntax(decl)
        case .initializer(let decl): self.syntax = SwiftSyntax.Syntax(decl)
        case .deinitializer(let decl): self.syntax = SwiftSyntax.Syntax(decl)
        case .accessor(let decl): self.syntax = SwiftSyntax.Syntax(decl)
        case .implicitGetter(let block): self.syntax = SwiftSyntax.Syntax(block)
        }
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "AbstractFunctionDeclScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) '\(compactName)'"
    }
}

/// Scope for a `subscript` declaration. Hosts the generic parameter scopes, the parameter list, and the accessor block.
///
/// ```
/// subscript(i: Int) -> Int {  // ← scope start
///     get { i }               // each accessor is an AbstractFunctionDeclScope child
/// }                           // ← scope end
/// ```
public final class SubscriptDeclScope: SyntaxScopeProtocol {
    public typealias Syntax = SubscriptDeclSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: any SyntaxScopeProtocol) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "SubscriptDeclScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) '\(compactName)'"
    }
}

/// Scope for a single enum case element. Hosts the associated-value parameter list
/// when present, so default-value expressions can be scoped properly.
///
/// ```
/// case foo(x: Int = 0)  // ← scope spans this element
/// ```
///
/// Multi-element case declarations like `case foo, bar(Int)` produce one
/// EnumElementScope per element.
public final class EnumElementScope: SyntaxScopeProtocol {
    public typealias Syntax = EnumCaseElementSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: any SyntaxScopeProtocol) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "EnumElementScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) '\(syntax.name.text)'"
    }
}

/// Scope for a `macro` declaration. Hosts the generic parameter scopes, the parameter list,
/// and the definition expression scope.
///
/// ```
/// macro foo<T>(value: T) -> T = #externalMacro(...)  // ← scope spans the whole declaration
/// ```
public final class MacroDeclScope: SyntaxScopeProtocol {
    public typealias Syntax = MacroDeclSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: any SyntaxScopeProtocol) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "MacroDeclScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) '\(compactName)'"
    }
}

/// Scope for a macro's definition expression (the `= expr` after the signature).
/// Sees the enclosing macro's parameters and generic parameters.
///
/// ```
/// macro foo<T>(value: T) -> T = #externalMacro(...)
/// //                            ↑ MacroDefinitionScope wraps this expression
/// ```
public final class MacroDefinitionScope: SyntaxScopeProtocol {
    public typealias Syntax = ExprSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: any SyntaxScopeProtocol) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "MacroDefinitionScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a freestanding macro expansion in declaration position (`#foo(args)`).
/// Argument expressions and trailing closures see the enclosing scope.
///
/// ```
/// #foo(value: outer) { ... }  // ← scope wraps the expansion; `outer` resolves to enclosing scope
/// ```
public final class MacroExpansionDeclScope: SyntaxScopeProtocol {
    public typealias Syntax = MacroExpansionDeclSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: any SyntaxScopeProtocol) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "MacroExpansionDeclScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) '\(syntax.macroName.text)'"
    }
}

/// Scope for a custom attribute (property wrapper, attached macro, global actor, etc.).
/// Argument expressions inside the attribute see the enclosing scope.
///
/// ```
/// @Wrapper(value: outer)  // ← scope wraps the attribute; `outer` resolves to enclosing scope
/// var x: Int
/// ```
public final class CustomAttributeScope: SyntaxScopeProtocol {
    public typealias Syntax = AttributeSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: any SyntaxScopeProtocol) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "CustomAttributeScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) '\(syntax.attributeName.trimmedDescription)'"
    }
}

extension AttributeSyntax {
    var isCustomAttribute: Bool {
        switch arguments {
        case .none, .argumentList:
            break
        default:
            return false
        }

        guard let firstChar = attributeName.trimmedDescription.first else {
            return false
        }
        return firstChar.isUppercase
    }
}

/// Scope wrapping a function-like declaration's parameter list.
/// Hosts default-argument initializer scopes so that defaults cannot see sibling parameters.
///
/// - `.function`: function / initializer / subscript parameter clause
///   ```
///   func f(x: Int = 0, y: Int = x) {}
///   //                          ↑ y's default cannot see x
///   ```
///
/// - `.enumCase`: associated-value parameter clause of an enum case
///   ```
///   case foo(x: Int = 0, y: Int = x)
///   //                          ↑ y's default cannot see x
///   ```
public final class ParameterListScope: SyntaxScopeProtocol {
    public typealias Syntax = SwiftSyntax.Syntax

    enum Kind {
        case function(FunctionParameterClauseSyntax)
        case enumCase(EnumCaseParameterClauseSyntax)
    }

    let kind: Kind
    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(kind: Kind, parent: (any SyntaxScopeProtocol)?) {
        self.kind = kind
        switch kind {
        case .function(let clause): self.syntax = SwiftSyntax.Syntax(clause)
        case .enumCase(let clause): self.syntax = SwiftSyntax.Syntax(clause)
        }
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "ParameterListScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a parameter's default-value expression.
/// Sees the enclosing scope but NOT the other parameters of the same function.
///
/// ```
/// func f(x: Int, y: Int = 0) {}
/// //                      ↑ DefaultArgumentInitializerScope; x is not visible here
/// ```
public final class DefaultArgumentInitializerScope: SyntaxScopeProtocol {
    public typealias Syntax = ExprSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "DefaultArgumentInitializerScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for the body of a function-like declaration.
/// Sees parameters (and `self` for methods) from the enclosing function-decl scope.
///
/// ```
/// func f(x: Int) {  // ← scope start
///     // x is visible here
/// }                 // ← scope end
/// ```
public final class FunctionBodyScope: SyntaxScopeProtocol {
    public typealias Syntax = SwiftSyntax.Syntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: any SyntaxProtocol, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = SwiftSyntax.Syntax(syntax)
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "FunctionBodyScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a braced block of statements.
/// Local funcs and types are visible from the top of the block (hoisted); local `let`/`var` are visible only from their declaration onward.
///
/// ```
/// {                 // ← scope start
///     // g is visible here (hoisted), x is not visible here
///     let x = 1
///     // x is visible here
///     g()
///     func g() {}
/// }                 // ← scope end
/// ```
public final class BraceStmtScope: SyntaxScopeProtocol {
    public typealias Syntax = CodeBlockItemListSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?
    let braceRange: Range<AbsolutePosition>
    let localFuncs: [FunctionDeclSyntax]
    let localTypes: [any DeclSyntaxProtocol]

    init(
        syntax: Syntax,
        parent: any SyntaxScopeProtocol,
        braceRange: Range<AbsolutePosition>,
        localFuncs: [FunctionDeclSyntax],
        localTypes: [any DeclSyntaxProtocol]
    ) {
        self.syntax = syntax
        self.parent = parent
        self.braceRange = braceRange
        self.localFuncs = localFuncs
        self.localTypes = localTypes
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "BraceStmtScope" }

    public var range: Range<AbsolutePosition> {
        braceRange
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

enum Portion {
    case whole
    case `where`
    case body

    var name: String {
        switch self {
        case .whole: return "Decl"
        case .where: return "Where"
        case .body: return "Body"
        }
    }
}

/// Scope for a nominal type declaration (`actor`, `class`, `enum`, `protocol`, `struct`).
///
/// Portion variants:
///
/// - `.whole`: outer scope spanning the entire decl; hosts the generic parameter scopes
///   ```
///   struct S<T> where T: P { /* members */ }
///   // ↑ ─────────────────────────────────── ↑   .whole spans the entire decl
///   ```
///
/// - `.where`: scope of the generic `where` clause (sees generic parameters)
///   ```
///   struct S<T> where T: P { /* members */ }
///   //                ↑──↑   .where covers just the where clause
///   ```
///
/// - `.body`: scope of the member block (sees generic parameters and members)
///   ```
///   struct S<T> where T: P { /* members */ }
///   //                     ↑─────────────↑   .body covers the member block
///   ```
public final class NominalTypeScope: SyntaxScopeProtocol {
    public let syntax: DeclSyntax
    let portion: Portion
    public let parent: (any SyntaxScopeProtocol)?
    let nominalName: TokenSyntax
    let memberBlock: MemberBlockSyntax
    let genericParameterClause: GenericParameterClauseSyntax?
    let genericWhereClause: GenericWhereClauseSyntax?
    let attributes: AttributeListSyntax
    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    init(
        syntax: DeclSyntax,
        portion: Portion,
        parent: any SyntaxScopeProtocol
    ) {
        guard let nominalType = nominalType(of: syntax) else {
            preconditionFailure("Expected a nominal type declaration")
        }

        self.syntax = syntax
        self.portion = portion
        self.parent = parent
        self.nominalName = nominalType.name
        self.memberBlock = nominalType.memberBlock
        self.genericParameterClause = nominalType.genericParameterClause
        self.genericWhereClause = nominalType.genericWhereClause
        self.attributes = nominalType.attributes
    }

    public var scopeTypeDescription: String {
        "NominalType\(portion.name)Scope"
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) '\(nominalName.text)'"
    }

    public var range: Range<AbsolutePosition> {
        switch portion {
        case .whole: return syntax.trimmedRange
        case .where:
            guard let genericWhereClause else {
                preconditionFailure(".where portion requires a generic where clause")
            }
            return genericWhereClause.trimmedRange
        case .body: return memberBlock.trimmedRange
        }
    }
}

/// Scope for an `extension` declaration.
///
/// Portion variants:
///
/// - `.whole`: starts past the extended type so resolving the extended type does not re-enter this scope
///   ```
///   extension S<T> where T: P { /* members */ }
///   //           ↑─────────────────────────────↑   .whole begins past `S<T>`
///   ```
///
/// - `.where`: scope of the generic `where` clause
///   ```
///   extension S<T> where T: P { /* members */ }
///   //                   ↑──↑   .where covers just the where clause
///   ```
///
/// - `.body`: scope of the member block
///   ```
///   extension S<T> where T: P { /* members */ }
///   //                        ↑─────────────↑   .body covers the member block
///   ```
public final class ExtensionScope: SyntaxScopeProtocol {
    public let syntax: ExtensionDeclSyntax
    let portion: Portion
    public let parent: (any SyntaxScopeProtocol)?

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    init(
        syntax: ExtensionDeclSyntax,
        portion: Portion,
        parent: any SyntaxScopeProtocol
    ) {
        self.syntax = syntax
        self.portion = portion
        self.parent = parent
    }

    var memberBlock: MemberBlockSyntax { syntax.memberBlock }
    var genericWhereClause: GenericWhereClauseSyntax? { syntax.genericWhereClause }

    public var scopeTypeDescription: String {
        "Extension\(portion.name)Scope"
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) '\(syntax.extendedType.trimmedDescription)'"
    }

    public var range: Range<AbsolutePosition> {
        switch portion {
        case .whole:
            // Mirrors the compiler's `ExtensionScope::moveStartPastExtendedNominal`:
            // start past the extended type so that resolving the extended
            // nominal does not recursively re-enter this scope.
            return syntax.extendedType.trimmedRange
                .upperBound..<syntax.trimmedRange.upperBound
        case .where:
            guard let genericWhereClause else {
                return syntax.trimmedRange
            }
            return genericWhereClause.trimmedRange
        case .body:
            return memberBlock.trimmedRange
        }
    }
}

extension ExtensionScope {
    var extendedTypeGenericArgumentClause: GenericArgumentClauseSyntax? {
        if let ident = syntax.extendedType.as(IdentifierTypeSyntax.self) {
            return ident.genericArgumentClause
        }
        if let member = syntax.extendedType.as(MemberTypeSyntax.self) {
            return member.genericArgumentClause
        }
        return nil
    }
}

/// Scope for a `typealias` declaration.
///
/// Portion variants:
///
/// - `.whole`: entire decl; hosts the generic parameter scopes
///   ```
///   typealias A<T> = Array<T> where T: P
///   // ↑ ──────────────────────────────↑   .whole spans the entire decl
///   ```
///
/// - `.where`: scope of the generic `where` clause
///   ```
///   typealias A<T> = Array<T> where T: P
///   //                              ↑──↑   .where covers just the where clause
///   ```
public final class TypeAliasScope: SyntaxScopeProtocol {
    public typealias Syntax = TypeAliasDeclSyntax

    enum Portion {
        case whole
        case `where`

        var name: String {
            switch self {
            case .whole: return "Decl"
            case .where: return "Where"
            }
        }
    }

    public let syntax: Syntax
    let portion: Portion
    public let parent: (any SyntaxScopeProtocol)?

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    init(syntax: Syntax, portion: Portion, parent: any SyntaxScopeProtocol) {
        self.syntax = syntax
        self.portion = portion
        self.parent = parent
    }

    public var scopeTypeDescription: String {
        "TypeAlias\(portion.name)Scope"
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) '\(syntax.name.text)'"
    }

    public var range: Range<AbsolutePosition> {
        switch portion {
        case .whole:
            return syntax.trimmedRange
        case .where:
            guard let whereClause = syntax.genericWhereClause else {
                preconditionFailure(".where portion requires a generic where clause")
            }
            return whereClause.trimmedRange
        }
    }
}

/// Scope introduced by a single generic parameter, extending from past the parameter to the end of its holder declaration.
///
/// Kind variants:
///
/// - `.parameter`: a parameter in a generic clause (e.g. `<T>`)
///   ```
///   func f<T>(x: T) -> T { /* body */ }
///   //       ↑ ← scope start (right after `<T>`); T visible through end of decl
///   ```
///
/// - `.argument`: a generic argument used in an extension's extended type (e.g. `extension Foo<T>`)
///   ```
///   extension Foo<T> { /* members */ }
///   //              ↑ ← scope start (right after `<T>`); T visible through end of decl
///   ```
public final class GenericParameterScope: SyntaxScopeProtocol {
    public typealias Syntax = SwiftSyntax.Syntax

    enum Kind {
        case parameter(GenericParameterSyntax)
        case argument(GenericArgumentSyntax)
    }

    let kind: Kind
    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?
    let holderLookupUpperBound: AbsolutePosition

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    init(
        kind: Kind,
        holderLookupUpperBound: AbsolutePosition,
        parent: any SyntaxScopeProtocol
    ) {
        self.kind = kind
        switch kind {
        case .parameter(let p):
            self.syntax = SwiftSyntax.Syntax(p)
        case .argument(let a):
            self.syntax = SwiftSyntax.Syntax(a)
        }
        self.holderLookupUpperBound = holderLookupUpperBound
        self.parent = parent
    }

    public var range: Range<AbsolutePosition> {
        syntax.trimmedRange.upperBound..<holderLookupUpperBound
    }

    public var scopeTypeDescription: String { "GenericParameterScope" }

    public var description: String {
        let nameText = introducedName?.text ?? "_"
        return "\(scopeTypeDescription) \(rangeDescription) '\(nameText)'"
    }
}

extension GenericParameterScope {
    var introducedName: TokenSyntax? {
        switch kind {
        case .parameter(let p):
            return p.name
        case .argument(let a):
            switch a.argument {
            case .type(let t):
                return t.as(IdentifierTypeSyntax.self)?.name
            default:
                return nil
            }
        }
    }
}

/// Scope for a closure's capture list. Capture initializers see the outer scope; the closure's parameters and body see the captured names.
///
/// ```
/// { [x = self.x] in   // ← scope start (capture list)
///     // x is visible here
/// }                   // ← scope end
/// ```
public final class CaptureListScope: SyntaxScopeProtocol {
    public typealias Syntax = ClosureExprSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "CaptureListScope" }

    public var range: Range<AbsolutePosition> {
        syntax.statements.positionAfterSkippingLeadingTrivia..<syntax.trimmedRange.upperBound
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }

    var captureItems: [ClosureCaptureSyntax] {
        guard let captureClause = syntax.signature?.capture else { return [] }
        return Array(captureClause.items)
    }
}

/// Scope for a closure's parameter list. The body sees the parameters.
///
/// ```
/// { x in        // ← scope start
///     // x is visible here
/// }             // ← scope end
/// // x is not visible here
/// ```
public final class ClosureParametersScope: SyntaxScopeProtocol {
    public typealias Syntax = ClosureExprSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "ClosureParametersScope" }

    public var range: Range<AbsolutePosition> {
        syntax.statements.positionAfterSkippingLeadingTrivia..<syntax.trimmedRange.upperBound
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for an `if` expression, covering the condition list, the then body, and the optional else body.
///
/// ```
/// if let x = p() {  // ← scope start
///     // x is visible here
/// } else {
///     // x is not visible here
/// }                 // ← scope end
/// // x is not visible here
/// ```
public final class IfExprScope: SyntaxScopeProtocol {
    public typealias Syntax = IfExprSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "IfExprScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a `while` statement, covering the condition list and the loop body.
///
/// ```
/// while let x = p() {  // ← scope start
///     // x is visible here
/// }                    // ← scope end
/// // x is not visible here
/// ```
public final class WhileStmtScope: SyntaxScopeProtocol {
    public typealias Syntax = WhileStmtSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "WhileStmtScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a `repeat`/`while` statement. The body and the trailing condition are siblings under this scope.
///
/// ```
/// repeat {        // ← scope start
///     // body
/// } while cond    // ← scope end
/// ```
public final class RepeatWhileScope: SyntaxScopeProtocol {
    public typealias Syntax = RepeatStmtSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "RepeatWhileScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a `for`-`in` statement, covering the pattern, the sequence, the optional `where` clause, and the loop body.
///
/// ```
/// for x in xs {   // ← scope start
///     // x is visible here
/// }               // ← scope end
/// // x is not visible here
/// ```
public final class ForEachStmtScope: SyntaxScopeProtocol {
    public typealias Syntax = ForStmtSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "ForEachStmtScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Inner scope of a `for`-`in` statement covering the optional `where` clause and the body, where pattern bindings are visible.
///
/// ```
/// for x in xs where x > 0 {  // ← scope start (at `where` if present, otherwise the body)
///     // x is visible here
/// }                          // ← scope end
/// ```
public final class ForEachPatternScope: SyntaxScopeProtocol {
    public typealias Syntax = ForStmtSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "ForEachPatternScope" }

    public var range: Range<AbsolutePosition> {
        let lowerBound =
            syntax.whereClause?.trimmedRange.lowerBound
            ?? syntax.body.trimmedRange.lowerBound

        return lowerBound..<syntax.body.trimmedRange.upperBound
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a `do`/`catch` statement. The body and each `catch` clause are hosted as siblings.
///
/// ```
/// do {
///     try f()
/// } catch let e {  // each catch lives in a CaseStmtScope
///     // e is visible here
/// }
/// ```
public final class DoStmtScope: SyntaxScopeProtocol {
    public typealias Syntax = DoStmtSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "DoStmtScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a `switch` expression. The subject expression and each case clause are hosted as siblings.
///
/// ```
/// switch s {
/// case .a(let x):  // each case lives in its own CaseStmtScope
///     // x is visible here
/// }
/// ```
public final class SwitchExprScope: SyntaxScopeProtocol {
    public typealias Syntax = SwitchExprSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "SwitchExprScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a single case clause. Hosts a `CaseLabelItemScope` for any label item with a `where` clause, plus a `CaseStmtBodyScope` for the body.
///
/// Kind variants:
///
/// - `.catchClause`: a `catch` clause of a `do` statement
///   ```
///   do {
///       try f()
///   } catch let e where cond {  // ← scope start
///       // e is visible here
///   }                           // ← scope end
///   ```
///
/// - `.switchCase`: a `case` clause of a `switch` expression
///   ```
///   switch s {
///   case .a(let x) where x > 0:  // ← scope start
///       // x is visible here
///   }                            // ← scope end (next case)
///   ```
public final class CaseStmtScope: SyntaxScopeProtocol {
    public typealias Syntax = SwiftSyntax.Syntax

    enum Kind {
        case catchClause(CatchClauseSyntax)
        case switchCase(SwitchCaseSyntax)
    }

    let kind: Kind
    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(kind: Kind, parent: (any SyntaxScopeProtocol)?) {
        self.kind = kind
        switch kind {
        case .catchClause(let catchClause):
            self.syntax = SwiftSyntax.Syntax(catchClause)
        case .switchCase(let switchCase):
            self.syntax = SwiftSyntax.Syntax(switchCase)
        }
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "CaseStmtScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a single case-label item that has a `where` clause; the pattern bindings are visible inside the `where` condition.
///
/// Kind variants:
///
/// - `.catchItem`: a single item of a `catch` clause
///   ```
///   } catch let e where cond {}
///   //                  ↑──↑   scope covers the where condition; e is visible here
///   ```
///
/// - `.switchCaseItem`: a single item of a switch `case` label
///   ```
///   case .a(let x) where x > 0:
///   //                   ↑───↑   scope covers the where condition; x is visible here
///   ```
public final class CaseLabelItemScope: SyntaxScopeProtocol {
    public typealias Syntax = SwiftSyntax.Syntax

    enum Kind {
        case catchItem(CatchItemSyntax)
        case switchCaseItem(SwitchCaseItemSyntax)
    }

    let kind: Kind
    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(kind: Kind, parent: (any SyntaxScopeProtocol)?) {
        self.kind = kind
        switch kind {
        case .catchItem(let item):
            self.syntax = SwiftSyntax.Syntax(item)
        case .switchCaseItem(let item):
            self.syntax = SwiftSyntax.Syntax(item)
        }
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "CaseLabelItemScope" }

    public var range: Range<AbsolutePosition> {
        guard let whereClause = kind.whereClause else {
            return syntax.trimmedRange
        }

        return whereClause.condition.trimmedRange
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for the body statements of a case clause (catch or switch case). Pattern bindings introduced by the label items are visible here.
///
/// ```
/// case .a(let x):
///     // ← scope start
///     // x is visible here
///     // ← scope end (next case)
/// ```
public final class CaseStmtBodyScope: SyntaxScopeProtocol {
    public typealias Syntax = SwiftSyntax.Syntax

    let kind: CaseStmtScope.Kind
    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(kind: CaseStmtScope.Kind, parent: (any SyntaxScopeProtocol)?) {
        self.kind = kind
        switch kind {
        case .catchClause(let catchClause):
            self.syntax = SwiftSyntax.Syntax(catchClause)
        case .switchCase(let switchCase):
            self.syntax = SwiftSyntax.Syntax(switchCase)
        }
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "CaseStmtBodyScope" }

    public var range: Range<AbsolutePosition> {
        switch kind {
        case .catchClause(let catchClause):
            return catchClause.body.trimmedRange
        case .switchCase(let switchCase):
            return switchCase.statements.trimmedRange
        }
    }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a `guard` statement. Conditions bind into the enclosing scope after the statement, while the else body cannot see them.
///
/// ```
/// guard let x = p() else {  // ← scope start
///     // x is not visible here
///     return
/// }
/// // x is visible here
/// ```
public final class GuardStmtScope: SyntaxScopeProtocol {
    public typealias Syntax = GuardStmtSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "GuardStmtScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }

    public var range: Range<AbsolutePosition> {
        syntax.trimmedRange.lowerBound..<lookupUpperBound
    }

    var lookupUpperBound: AbsolutePosition {
        parent?.range.upperBound ?? syntax.trimmedRange.upperBound
    }
}

/// Scope for the `else` body of a `guard` statement. Conditions bound by the guard are NOT visible here (they only bind on the success path).
///
/// ```
/// guard let x = p() else {
///     // ← scope start
///     // x is not visible here
///     return
/// } // ← scope end
/// ```
public final class GuardStmtBodyScope: SyntaxScopeProtocol {
    public typealias Syntax = CodeBlockSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?
    public let lookupParent: (any SyntaxScopeProtocol)?

    init(
        syntax: Syntax,
        parent: (any SyntaxScopeProtocol)?,
        lookupParent: (any SyntaxScopeProtocol)?
    ) {
        self.syntax = syntax
        self.parent = parent
        self.lookupParent = lookupParent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "GuardStmtBodyScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope introduced by a single conditional-clause pattern binding (`if let x`, `while let x`, `guard let x`, etc.). The binding is visible from this scope onward.
///
/// ```
/// if let x = p() {  // ← scope start (right after the pattern)
///     // x is visible here
/// }                 // ← scope end
/// ```
public final class ConditionalClausePatternUseScope: SyntaxScopeProtocol {
    public typealias Syntax = ConditionElementSyntax

    public let parent: (any SyntaxScopeProtocol)?
    public let syntax: Syntax
    let lookupUpperBound: AbsolutePosition

    init(
        syntax: Syntax,
        parent: (any SyntaxScopeProtocol)?,
        lookupUpperBound: AbsolutePosition
    ) {
        self.syntax = syntax
        self.parent = parent
        self.lookupUpperBound = lookupUpperBound
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "ConditionalClausePatternUseScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }

    public var range: Range<AbsolutePosition> {
        syntax.trimmedRange.lowerBound..<lookupUpperBound
    }

    var conditionPattern: PatternSyntax? {
        switch syntax.condition {
        case .matchingPattern(let matchingPattern):
            return matchingPattern.pattern
        case .optionalBinding(let optionalBinding):
            return optionalBinding.pattern
        case .expression, .availability:
            return nil
        }
    }
}

/// Scope for the initializer expression of a conditional-clause pattern binding (the right-hand side of `if let x = rhs`). The binding itself is NOT visible inside its own initializer.
///
/// ```
/// if let x = computeX() {} // x is not visible inside `computeX()`
/// ```
public final class ConditionalClauseInitializerScope: SyntaxScopeProtocol {
    public typealias Syntax = InitializerClauseSyntax

    public let parent: (any SyntaxScopeProtocol)?
    public let syntax: Syntax

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "ConditionalClauseInitializerScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

/// Scope for a single binding entry of a `var` / `let` declaration. For local bindings, the introduced name is visible from this entry to the end of the enclosing block.
///
/// ```
/// let x = 1, y = x   // y's initializer can see x
/// // x and y are visible here
/// ```
public final class PatternEntryDeclScope: SyntaxScopeProtocol {
    public typealias Syntax = VariableDeclSyntax

    public let parent: (any SyntaxScopeProtocol)?
    public let syntax: Syntax
    let bindingIndex: SyntaxChildrenIndex
    let isLocalBinding: Bool

    init(
        syntax: Syntax,
        parent: (any SyntaxScopeProtocol)?,
        bindingIndex: SyntaxChildrenIndex,
        isLocalBinding: Bool
    ) {
        self.syntax = syntax
        self.parent = parent
        self.bindingIndex = bindingIndex
        self.isLocalBinding = isLocalBinding
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "PatternEntryDeclScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription) \(patternEntryDescriptionSuffix)"
    }

    public var range: Range<AbsolutePosition> {
        let bindingRange = syntax.bindings[bindingIndex].trimmedRange

        guard isLocalBinding else {
            return bindingRange
        }

        return bindingRange.lowerBound..<lookupUpperBound
    }

    var lookupUpperBound: AbsolutePosition {
        guard isLocalBinding, let parent else {
            return syntax.trimmedRange.upperBound
        }

        return parent.range.upperBound
    }
}

/// Scope for the initializer expression of a pattern entry. The binding declared by the entry is NOT visible inside its own initializer.
///
/// ```
/// let x = computeX()  // x is not visible inside `computeX()`
/// ```
public final class PatternEntryInitializerScope: SyntaxScopeProtocol {
    public typealias Syntax = ExprSyntax

    public let parent: (any SyntaxScopeProtocol)?
    public let syntax: Syntax

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "PatternEntryInitializerScope" }

    public var description: String {
        guard let parent = parent as? PatternEntryDeclScope else {
            return "\(scopeTypeDescription) \(rangeDescription)"
        }

        return
            "\(scopeTypeDescription) \(rangeDescription) \(parent.patternEntryDescriptionSuffix)"
    }
}

/// Scope wrapping a `try` expression so that the inner expression is walked under a try-marker scope.
///
/// ```
/// try f()  // TryScope wraps `f()`
/// ```
public final class TryScope: SyntaxScopeProtocol {
    public typealias Syntax = TryExprSyntax

    public let syntax: Syntax
    public let parent: (any SyntaxScopeProtocol)?

    init(syntax: Syntax, parent: (any SyntaxScopeProtocol)?) {
        self.syntax = syntax
        self.parent = parent
    }

    public var children: [any SyntaxScopeProtocol] = []
    public var isExpanded: Bool = false

    public var scopeTypeDescription: String { "TryScope" }

    public var description: String {
        "\(scopeTypeDescription) \(rangeDescription)"
    }
}

extension CaseLabelItemScope.Kind {
    var whereClause: WhereClauseSyntax? {
        switch self {
        case .catchItem(let item):
            return item.whereClause
        case .switchCaseItem(let item):
            return item.whereClause
        }
    }

    var pattern: PatternSyntax? {
        switch self {
        case .catchItem(let item):
            return item.pattern
        case .switchCaseItem(let item):
            return item.pattern
        }
    }
}

func scanLocalDecls(
    in statements: CodeBlockItemListSyntax
) -> (localFuncs: [FunctionDeclSyntax], localTypes: [any DeclSyntaxProtocol]) {
    var localFuncs = [FunctionDeclSyntax]()
    var localTypes = [any DeclSyntaxProtocol]()

    for element in statements {
        guard let decl = element.item.as(DeclSyntax.self) else {
            continue
        }

        if let funcDecl = decl.as(FunctionDeclSyntax.self) {
            localFuncs.append(funcDecl)
        } else if decl.as(VariableDeclSyntax.self) == nil {
            localTypes.append(decl)
        }
    }

    return (localFuncs, localTypes)
}

private extension AbstractFunctionDeclScope {
    var compactName: String {
        switch kind {
        case .function(let decl):
            let labels = decl.signature.parameterClause.parameters.map { parameter in
                "\(parameter.firstName.text):"
            }.joined()
            return "\(decl.name.text)(\(labels))"
        case .initializer(let decl):
            let labels = decl.signature.parameterClause.parameters.map { parameter in
                "\(parameter.firstName.text):"
            }.joined()
            return "init(\(labels))"
        case .deinitializer:
            return "deinit"
        case .accessor(let decl):
            if let param = decl.parameters?.name {
                return "\(decl.accessorSpecifier.text)(\(param.text))"
            }
            return decl.accessorSpecifier.text
        case .implicitGetter:
            return "get"
        }
    }
}

private extension SubscriptDeclScope {
    var compactName: String {
        let labels = syntax.parameterClause.parameters.map { parameter in
            "\(parameter.firstName.text):"
        }.joined()
        return "subscript(\(labels))"
    }
}

private extension MacroDeclScope {
    var compactName: String {
        let labels = syntax.signature.parameterClause.parameters.map { parameter in
            "\(parameter.firstName.text):"
        }.joined()
        return "\(syntax.name.text)(\(labels))"
    }
}

private extension PatternEntryDeclScope {
    var patternEntryDescriptionSuffix: String {
        let entryIndex = syntax.bindings.distance(
            from: syntax.bindings.startIndex,
            to: bindingIndex
        )

        return "entry \(entryIndex)"
    }
}

private extension SyntaxScopeProtocol {
    var rangeDescription: String {
        let converter = SourceLocationConverter(fileName: "", tree: syntax.root)
        return sourceRange(converter: converter).description
    }
}

private func nominalType(of decl: DeclSyntax) -> (
    name: TokenSyntax,
    memberBlock: MemberBlockSyntax,
    genericParameterClause: GenericParameterClauseSyntax?,
    genericWhereClause: GenericWhereClauseSyntax?,
    attributes: AttributeListSyntax
)? {
    if let decl = decl.as(ActorDeclSyntax.self) {
        return (
            decl.name, decl.memberBlock, decl.genericParameterClause, decl.genericWhereClause,
            decl.attributes
        )
    }

    if let decl = decl.as(ClassDeclSyntax.self) {
        return (
            decl.name, decl.memberBlock, decl.genericParameterClause, decl.genericWhereClause,
            decl.attributes
        )
    }

    if let decl = decl.as(EnumDeclSyntax.self) {
        return (
            decl.name, decl.memberBlock, decl.genericParameterClause, decl.genericWhereClause,
            decl.attributes
        )
    }

    if let decl = decl.as(ProtocolDeclSyntax.self) {
        return (decl.name, decl.memberBlock, nil, decl.genericWhereClause, decl.attributes)
    }

    if let decl = decl.as(StructDeclSyntax.self) {
        return (
            decl.name, decl.memberBlock, decl.genericParameterClause, decl.genericWhereClause,
            decl.attributes
        )
    }

    return nil
}
