import SwiftSyntax

/// Syntax node that can be refered to with an identifier.
protocol IdentifiableSyntax: SyntaxProtocol {
    var identifier: TokenSyntax { get }
}

extension IdentifierPatternSyntax: IdentifiableSyntax {}

extension ClosureParameterSyntax: IdentifiableSyntax {
    var identifier: TokenSyntax {
        secondName ?? firstName
    }
}

extension FunctionParameterSyntax: IdentifiableSyntax {
    var identifier: TokenSyntax {
        secondName ?? firstName
    }
}

extension ClosureShorthandParameterSyntax: IdentifiableSyntax {
    var identifier: TokenSyntax {
        name
    }
}

extension ClosureCaptureSyntax: IdentifiableSyntax {
    var identifier: TokenSyntax {
        name
    }
}

extension AccessorParametersSyntax: IdentifiableSyntax {
    var identifier: TokenSyntax {
        name
    }
}

extension GenericParameterSyntax: IdentifiableSyntax {
    var identifier: TokenSyntax {
        name
    }
}

extension PrimaryAssociatedTypeSyntax: IdentifiableSyntax {
    var identifier: TokenSyntax {
        name
    }
}

// `extension Foo<T>` の T を generic parameter として扱うため、本リポジトリ独自に適合させる。
extension IdentifierTypeSyntax: IdentifiableSyntax {
    var identifier: TokenSyntax {
        name
    }
}
