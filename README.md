# Swift Syntax Scope - Scope Tree System for lexical name lookup

A study project that builds a lexical scope tree on top of [SwiftSyntax](https://github.com/swiftlang/swift-syntax) and uses it to perform lexical name lookup over a Swift source file.

> Note: SwiftSyntax already ships with [SwiftLexicalLookup](https://github.com/swiftlang/swift-syntax/tree/main/Sources/SwiftLexicalLookup), which provides lexical lookup based on SwiftSyntax. This project is a study project re-implementing scope system of swift compiler named [ASTScope](https://github.com/swiftlang/swift/blob/main/lib/AST/ASTScope.cpp) in SwiftSyntax.

## Overview

`SwiftSyntaxScope` parses a Swift source file into a syntax tree, then lazily expands it into a tree of `SyntaxScopeProtocol` nodes that mirror the lexical scopes the compiler reasons about (source file, function body, brace block, generic parameter, conditional clause, case label, etc.).

Two things you can do with that tree:

1. **Lexical Lookup** — given a position and a name in a source file, walk the scope tree outward to find every declaration that name could refer to.
2. **Dump Scope Tree** — print the full scope tree of a source file as an indented text listing, useful for debugging and learning.

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/kntkymt/swift-syntax-scope.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "SwiftSyntaxScope", package: "swift-syntax-scope"),
        ]
    ),
]
```

## Usage

### Lexical Lookup

`SourceFileSyntax` is extended with a `lexicalLookup(position:name:options:)` method. Given a byte position inside the source file and a name, it returns every `LookupName` that the name could resolve to from that position, in the order the compiler would consider them (innermost scope first).

The example below puts a shadowing binding inside the `then` branch and performs the lookup from the `else` branch. The point is that the binding introduced in the `then` branch must NOT leak into the `else` branch — sibling brace blocks have disjoint scopes — so the reference on line 9 has to resolve back to the outer `let doubled` on line 3. A naive textual search for `doubled` cannot make that distinction; a real scope tree can.

```swift
import SwiftParser
import SwiftSyntax
import SwiftSyntaxScope

let source = """
    func process(value: Int) {
        let threshold = 10
        let doubled = value * 2

        if doubled > threshold {
            let doubled = doubled * 2
            print(doubled)
        } else {
            print(doubled) // lookup "doubled" here
        }
    }
    """

let sourceFile = Parser.parse(source: source)

// Find the position of `doubled` inside the `else` branch's `print(doubled)` call (line 9).
let converter = SourceLocationConverter(fileName: "", tree: sourceFile)
let position = converter.position(ofLine: 9, column: 15)

let results = sourceFile.lexicalLookup(
    position: position,
    name: Identifier(canonicalName: "doubled")
)

for result in results {
    print(result)
}
// => identifier: doubled (the outer `let doubled = value * 2` on line 3)
//    The `let doubled = doubled * 2` on line 6 lives only in the `then` branch
//    and is invisible from inside `else`.
```

Pass `.includeOuterResults` in `LookupOptions` to also collect shadowed names from outer scopes instead of stopping at the innermost match — useful when you want to surface the full shadowing chain.

### Dump Scope Tree

The package also ships an executable `swift-scope-dump` that prints the full scope tree of a Swift source file. Useful for visualizing how the scope tree is shaped for a given snippet — and, in particular, how shadowing is represented as nested `PatternEntryDeclScope`s introducing the same identifier.

```sh
swift run swift-scope-dump path/to/file.swift
```

For example, given this input:

```swift
func process(value: Int) {
    let threshold = 10
    let doubled = value * 2

    if doubled > threshold {
        let doubled = doubled * 2
        print(doubled)
    } else {
        print(doubled)
    }
}
```

The output is:

```
SourceFileScope [1:1 - 12:0]
`-AbstractFunctionDeclScope [1:1 - 11:1] 'process(value:)'
  |-ParameterListScope [1:13 - 1:24]
  `-FunctionBodyScope [1:26 - 11:1] introduces=[identifier:value]
    `-BraceStmtScope [1:26 - 11:1]
      `-PatternEntryDeclScope [2:9 - 11:1] entry 0 introduces=[identifier:threshold]
        |-PatternEntryInitializerScope [2:21 - 2:22] entry 0
        `-PatternEntryDeclScope [3:9 - 11:1] entry 0 introduces=[identifier:doubled]
          |-PatternEntryInitializerScope [3:19 - 3:27] entry 0
          `-IfExprScope [5:5 - 10:5]
            |-BraceStmtScope [5:28 - 8:5]
            | `-PatternEntryDeclScope [6:13 - 8:5] entry 0 introduces=[identifier:doubled]
            |   `-PatternEntryInitializerScope [6:23 - 6:33] entry 0
            `-BraceStmtScope [8:12 - 10:5]
```

**Background — lookup only walks the parent chain.** Lexical lookup in this package follows a single rule: starting from the innermost scope that contains the lookup position, repeatedly check the names introduced by the current scope and, if nothing matches, move to its `parent`. Sibling scopes are never visited. This mirrors how the Swift compiler's [ASTScope](https://github.com/swiftlang/swift/blob/main/lib/AST/ASTScope.cpp) lookup works, and it is what makes scope-tree-based lookup correct by construction: a name introduced in some other subtree of the scope tree is, by definition, unreachable.

The `if`/`else` shape above is a direct consequence of that rule. The `then` and `else` branches are represented as two **sibling** `BraceStmtScope`s under the same `IfExprScope`, and the inner `PatternEntryDeclScope` introducing `doubled` lives only under the first (`then`) `BraceStmtScope`. When `lexicalLookup` is called from inside the second (`else`) brace, the parent chain it walks is `else BraceStmtScope → IfExprScope → outer PatternEntryDeclScope (doubled, line 3) → … → SourceFileScope`. The `then` brace and its inner `doubled` are siblings of the starting scope, never on that chain, and therefore correctly invisible — without any extra "is this binding in a different branch?" check at lookup time.

More worked examples (including generics, extensions, `do`/`catch`, `switch`, and closures) live in [`ScopeDumpExample/`](ScopeDumpExample/).

## License

MIT. See [LICENSE](LICENSE).
