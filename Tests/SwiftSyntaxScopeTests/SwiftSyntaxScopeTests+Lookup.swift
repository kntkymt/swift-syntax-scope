import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftSyntaxScope

extension SwiftSyntaxScopeTests {
    @Test(arguments: unsupportedLookupTestCases)
    func cantLookupUnsupportedCases(source: String, name: StaticString) {
        let parsed = parseMarkedSource(source)

        let results = runLexicalLookup(
            sourceFile: parsed.syntax,
            position: parsed.position(of: "1️⃣"),
            name: name
        )

        #expect(results == [])
    }
}

// MARK: - Lookup tests

extension SwiftSyntaxScopeTests {
    @Test
    func lookupTopLevelGlobalBindings() {
        assertLexicalNameLookup(
            source: """
                let /*1️⃣*/first = 1
                let /*2️⃣*/second = 2

                let third = /*3️⃣*/second + /*4️⃣*/first
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "second", atMarker: "2️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "first", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )
    }

    @Test
    func lookupBraceStmtBindings() {
        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/a = 10

                    if true {
                        let /*2️⃣*/a = 5

                        if true {
                            let _ = /*3️⃣*/a
                        }
                    }

                    let /*4️⃣*/value = 1
                    let value = /*5️⃣*/value
                }

                func g() {
                    let/*6️⃣*/ a = 1
                    print(/*7️⃣*/ a)
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "value", atMarker: "4️⃣", kind: .identifier)
                ),
                "7️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "6️⃣", kind: .identifier)
                ),
            ]
        )
    }

    @Test
    func lookupConditionBindings() {
        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/a = 1

                    if let /*2️⃣*/a = maybeValue() {
                        let _ = /*3️⃣*/a
                    } else {
                        let _ = /*4️⃣*/a
                    }

                    while let /*5️⃣*/a = maybeValue() {
                        let _ = /*6️⃣*/a
                    }

                    let _ = /*7️⃣*/a
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "5️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "7️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )

        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/a = 1

                    while let /*2️⃣*/a = maybeValue(), let b = maybeValue(/*3️⃣*/a) {
                        _ = b
                    }

                    repeat {
                        let a = 0
                        _ = a
                    } while check(/*4️⃣*/a)
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )
    }

    @Test
    func lookupGuardBindings() {
        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/a = 1

                    guard let /*2️⃣*/a = maybeValue(), let b = maybeValue(/*3️⃣*/a) else {
                        return
                    }

                    _ = b

                    guard let /*4️⃣*/a = maybeValue() else {
                        let _ = /*5️⃣*/a
                        return
                    }

                    let _ = /*6️⃣*/a
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "4️⃣", kind: .identifier),
                    outer: [
                        .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                        .init(name: "a", atMarker: "1️⃣", kind: .identifier),
                    ]
                ),
            ]
        )

        assertLexicalNameLookup(
            source: """
                func f() {
                    guard case let /*1️⃣*/a = maybeValue() else {
                        return
                    }

                    let _ = /*2️⃣*/a
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                )
            ]
        )
    }

    @Test
    func lookupCatchBindings() {
        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/a = 1
                    do {
                        let a = 10
                    } catch {
                        let /*2️⃣*/a = 20
                        let _ = /*3️⃣*/a
                    }

                    let _ = /*4️⃣*/a
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )

        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/a = 1

                    do {
                    } catch let /*2️⃣*/a /*3️⃣*/where check(/*4️⃣*/a) {
                        _ = a
                    }

                    do {
                    } catch /*5️⃣*/{
                        let _ = /*6️⃣*/error
                    }

                    do {
                    } catch SomeError {
                        let _ = /*7️⃣*/error
                    }
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "error", atMarker: "5️⃣", kind: .implicit)
                ),
                "7️⃣": .init(notFound: "error"),
            ]
        )
    }

    @Test
    func lookupForEachBindings() {
        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/a = 1

                    for a in [/*2️⃣*/a] {
                        _ = a
                    }

                    for /*3️⃣*/a in maybeValues() where /*4️⃣*/a > 0 {
                        _ = a
                    }

                    let _ = /*5️⃣*/a
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "3️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )

        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/a = 1
                    for i in 1...5 where { let /*2️⃣*/a = true; return /*3️⃣*/a }() {
                        let b = /*4️⃣*/a
                    }
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )
    }

    @Test
    func lookupSwitchCaseBindings() {
        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/a = 1

                    switch value {
                    case let /*2️⃣*/a:
                        let _ = /*3️⃣*/a
                    case let /*4️⃣*/a where check(/*5️⃣*/a):
                        _ = a
                    default:
                        let _ = /*6️⃣*/a
                    }

                    let _ = /*7️⃣*/a
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "4️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "1️⃣", kind: .identifier)]
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
                "7️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )

        assertLexicalNameLookup(
            source: """
                func f() {
                    switch value {
                    case let /*1️⃣*/a, let /*2️⃣*/a:
                        let _ = /*3️⃣*/a
                    case let b, let c:
                        let _ = /*4️⃣*/b
                        let _ = /*5️⃣*/c
                    default:
                        break
                    }
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
                "4️⃣": .init(notFound: "b"),
                "5️⃣": .init(notFound: "c"),
            ]
        )
    }

    @Test
    func lookupEnumAssociatedValueBindings() {
        assertLexicalNameLookup(
            source: """
                func f() {
                    switch value {
                    case .a(let /*1️⃣*/a):
                        let _ = /*2️⃣*/a
                    case let .b(/*3️⃣*/b):
                        let _ = /*4️⃣*/b
                    case let .c(/*5️⃣*/c), let .d(/*6️⃣*/c):
                        let _ = /*7️⃣*/c
                    default:
                        break
                    }
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "b", atMarker: "3️⃣", kind: .identifier)
                ),
                "7️⃣": .init(
                    innerMost: .init(name: "c", atMarker: "5️⃣", kind: .identifier)
                ),
            ]
        )
    }

    @Test
    func lookupFunctionParameters() {
        assertLexicalNameLookup(
            source: """
                let /*1️⃣*/outer = 1

                func f(/*2️⃣*/a: Int, b: Int = /*3️⃣*/a, c: Int = /*4️⃣*/outer) {
                    let _ = /*5️⃣*/a
                }

                func g(/*6️⃣*/a: Int) {
                    let /*7️⃣*/a = 10
                    let _ = /*8️⃣*/a
                }
                """,
            references: [
                "3️⃣": .init(notFound: "a"),
                "4️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "2️⃣", kind: .identifier)
                ),
                "8️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "7️⃣", kind: .identifier),
                    outer: [.init(name: "a", atMarker: "6️⃣", kind: .identifier)]
                ),
            ]
        )
    }

    @Test
    func lookupClosureParameters() {
        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/b = 1

                    let shorthand = { /*2️⃣*/p in
                        let _ = /*3️⃣*/p
                    }

                    let full = { (/*4️⃣*/x: Int, _ y: Int) in
                        let _ = /*5️⃣*/x
                    }

                    let shadowing = { /*6️⃣*/b in
                        let _ = /*7️⃣*/b
                    }

                    let _ = /*8️⃣*/p
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "p", atMarker: "2️⃣", kind: .identifier)
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "x", atMarker: "4️⃣", kind: .identifier)
                ),
                "7️⃣": .init(
                    innerMost: .init(name: "b", atMarker: "6️⃣", kind: .identifier),
                    outer: [.init(name: "b", atMarker: "1️⃣", kind: .identifier)]
                ),
                "8️⃣": .init(notFound: "p"),
            ]
        )
    }

    @Test
    func lookupCaptures() {
        assertLexicalNameLookup(
            source: """
                func f() {
                    let /*1️⃣*/outer = 1

                    let c1 = { [/*2️⃣*/outer] in /*3️⃣*/outer }
                    let c2 = { [/*4️⃣*/outer = outer] in /*5️⃣*/outer }
                    let c3 = { [aliased = /*6️⃣*/outer] in aliased }
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "2️⃣", kind: .identifier),
                    outer: [.init(name: "outer", atMarker: "1️⃣", kind: .identifier)]
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "4️⃣", kind: .identifier),
                    outer: [.init(name: "outer", atMarker: "1️⃣", kind: .identifier)]
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )
    }

    @Test
    func lookupGenericParameters() {
        assertLexicalNameLookup(
            source: """
                func fn</*1️⃣*/T>(a: T) -> T {
                    let b: /*2️⃣*/T = a
                    return b
                }

                struct Box</*3️⃣*/U> {
                    func unwrap() -> /*4️⃣*/U {
                        fatalError()
                    }
                }

                extension Container</*5️⃣*/V> {
                    func unwrap() -> /*6️⃣*/V {
                        fatalError()
                    }
                }

                struct Pair</*7️⃣*/A, B: /*8️⃣*/A> {
                }

                struct Pair2</*9️⃣*/W: P, X: Q</*🔟*/W>> {
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "T", atMarker: "1️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "U", atMarker: "3️⃣", kind: .identifier)
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "V", atMarker: "5️⃣", kind: .identifier)
                ),
                "8️⃣": .init(
                    innerMost: .init(name: "A", atMarker: "7️⃣", kind: .identifier)
                ),
                "🔟": .init(
                    innerMost: .init(name: "W", atMarker: "9️⃣", kind: .identifier)
                ),
            ]
        )

        assertLexicalNameLookup(
            source: """
                let /*1️⃣*/outer = 1

                struct S {
                    init</*2️⃣*/Z>(value: Z) {
                        let x: /*3️⃣*/Z? = value
                        _ = x
                    }
                }

                extension Foo where T == /*4️⃣*/outer {
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "Z", atMarker: "2️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )
    }

    @Test
    func lookupTypeAlias() {
        assertLexicalNameLookup(
            source: """
                typealias Foo</*1️⃣*/T> = Array</*2️⃣*/T> where /*3️⃣*/T: Equatable

                func f() {
                    typealias /*4️⃣*/Alias = Int
                    let x: /*5️⃣*/Alias = 0
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "T", atMarker: "1️⃣", kind: .identifier)
                ),
                "3️⃣": .init(
                    innerMost: .init(name: "T", atMarker: "1️⃣", kind: .identifier)
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "Alias", atMarker: "4️⃣", kind: .declaration)
                ),
            ]
        )
    }

    @Test
    func lookupInitDeinit() {
        assertLexicalNameLookup(
            source: """
                struct S {
                    init(/*1️⃣*/value: Int) {
                        let _ = /*2️⃣*/value
                    }
                }

                class C {
                    deinit {
                        let _ = /*3️⃣*/value
                    }
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "value", atMarker: "1️⃣", kind: .identifier)
                ),
                "3️⃣": .init(notFound: "value"),
            ]
        )
    }

    @Test
    func lookupNominalTypeNames() {
        assertLexicalNameLookup(
            source: """
                struct /*1️⃣*/Outer {
                    struct /*2️⃣*/Inner {
                        func makeOuter() {
                            let _ = /*3️⃣*/Outer()
                        }
                    }

                    func makeInner() {
                        let _ = /*4️⃣*/Inner()
                    }
                }

                struct /*5️⃣*/A {
                    struct /*6️⃣*/A {
                        func f() {
                            let _ = /*7️⃣*/A()
                        }
                    }
                }

                struct B {
                    let a = /*8️⃣*/c
                    let c = 1
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "Outer", atMarker: "1️⃣", kind: .declaration)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "Inner", atMarker: "2️⃣", kind: .declaration)
                ),
                "7️⃣": .init(
                    innerMost: .init(name: "A", atMarker: "6️⃣", kind: .declaration),
                    outer: [.init(name: "A", atMarker: "5️⃣", kind: .declaration)]
                ),
                "8️⃣": .init(notFound: "c"),
            ]
        )
    }

    @Test
    func lookupTypeMembers() {
        assertLexicalNameLookup(
            source: """
                extension Foo {
                    func /*1️⃣*/helper() {
                    }

                    var /*2️⃣*/computed: Int { 0 }

                    func main() {
                        /*3️⃣*/helper()
                        let _ = /*4️⃣*/computed
                    }
                }

                extension Bar where T: Equatable {
                    func /*5️⃣*/helperW() {
                    }

                    func mainW() {
                        /*6️⃣*/helperW()
                    }
                }

                protocol P {
                    associatedtype /*7️⃣*/Item
                    typealias Copy = /*8️⃣*/Item
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "helper", atMarker: "1️⃣", kind: .declaration)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "computed", atMarker: "2️⃣", kind: .identifier)
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "helperW", atMarker: "5️⃣", kind: .declaration)
                ),
                "8️⃣": .init(
                    innerMost: .init(name: "Item", atMarker: "7️⃣", kind: .declaration)
                ),
            ]
        )
    }

    @Test
    func lookupTryExpression() {
        assertLexicalNameLookup(
            source: """
                func f() throws {
                    let /*1️⃣*/value = 1
                    let direct = try call(/*2️⃣*/value)
                    let inClosure = try { () -> Int in
                        let /*3️⃣*/value = 2
                        return /*4️⃣*/value
                    }()
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "value", atMarker: "1️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "value", atMarker: "3️⃣", kind: .identifier),
                    outer: [.init(name: "value", atMarker: "1️⃣", kind: .identifier)]
                ),
            ]
        )
    }

    @Test
    func lookupCustomAttributeArguments() {
        assertLexicalNameLookup(
            source: """
                let /*1️⃣*/outer = 0

                @Wrapper(value: /*2️⃣*/outer)
                func fn() {}

                @Wrapper(value: /*3️⃣*/outer)
                var v = 0

                @Wrapper(value: /*4️⃣*/outer)
                struct S1 {}

                @Wrapper(value: /*5️⃣*/outer)
                extension X {}

                func g(/*6️⃣*/p: Int) {
                    @Wrapper(value: /*7️⃣*/p)
                    func nested() {}
                }

                struct /*8️⃣*/SType {
                    @AddInit(default: /*9️⃣*/outer)
                    var x: Int

                    @AddCompletionHandler(target: /*🔟*/SType.self)
                    func h(value: Int) async -> Int { value }
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
                "3️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
                "7️⃣": .init(
                    innerMost: .init(name: "p", atMarker: "6️⃣", kind: .identifier)
                ),
                "9️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
                "🔟": .init(
                    innerMost: .init(name: "SType", atMarker: "8️⃣", kind: .declaration)
                ),
            ]
        )
    }

    @Test
    func lookupMacro() {
        assertLexicalNameLookup(
            source: """
                let /*1️⃣*/outer = 0

                macro paramMacro(/*2️⃣*/value: Int) -> Int = /*3️⃣*/value
                macro genericMacro</*4️⃣*/T>(value: T) -> T = /*5️⃣*/T.self
                macro outerMacro() = /*6️⃣*/outer

                struct S {
                    #expandMe(value: /*7️⃣*/outer)
                    #expandMe2 { /*8️⃣*/outer }
                }
                """,
            references: [
                "3️⃣": .init(
                    innerMost: .init(name: "value", atMarker: "2️⃣", kind: .identifier)
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "T", atMarker: "4️⃣", kind: .identifier)
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
                "7️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
                "8️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
            ]
        )
    }

    @Test
    func lookupImplicitSelfType() {
        assertLexicalNameLookup(
            source: """
                protocol /*1️⃣*/P where /*2️⃣*/Self: Equatable {
                    func f() {
                        let _ = /*3️⃣*/Self
                    }
                }

                struct Foo {}

                /*4️⃣*/extension Foo {
                    func bar() {
                        let _ = /*5️⃣*/Self
                    }
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "Self", atMarker: "1️⃣", kind: .implicit)
                ),
                "3️⃣": .init(
                    innerMost: .init(name: "Self", atMarker: "1️⃣", kind: .implicit)
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "Self", atMarker: "4️⃣", kind: .implicit)
                ),
            ]
        )
    }

    @Test
    func lookupImplicitSelf() {
        assertLexicalNameLookup(
            source: """
                class C {
                    func /*1️⃣*/method() {
                        let _ = /*2️⃣*/self
                    }
                }

                func topLevel() {
                    let _ = /*3️⃣*/self
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "self", atMarker: "1️⃣", kind: .implicit)
                ),
                "3️⃣": .init(notFound: "self"),
            ]
        )
    }

    @Test
    func lookupAccessorBindings() {
        assertLexicalNameLookup(
            source: """
                struct S {
                    var withGetSet: Int = 0 {
                        get {
                            let /*1️⃣*/local = 1
                            return /*2️⃣*/local
                        }
                        set {}
                    }

                    var implicitGetter: Int {
                        let /*3️⃣*/localG = 1
                        return /*4️⃣*/localG
                    }

                    var implicitSetter: Int = 0 {
                        /*5️⃣*/set {
                            print(/*6️⃣*/newValue)
                        }
                    }

                    var willSetVar: Int = 0 {
                        /*7️⃣*/willSet {
                            print(/*8️⃣*/newValue)
                        }
                    }

                    var didSetVar: Int = 0 {
                        /*9️⃣*/didSet {
                            print(/*🔟*/oldValue)
                        }
                    }
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "local", atMarker: "1️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "localG", atMarker: "3️⃣", kind: .identifier)
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "newValue", atMarker: "5️⃣", kind: .implicit)
                ),
                "8️⃣": .init(
                    innerMost: .init(name: "newValue", atMarker: "7️⃣", kind: .implicit)
                ),
                "🔟": .init(
                    innerMost: .init(name: "oldValue", atMarker: "9️⃣", kind: .implicit)
                ),
            ]
        )

        assertLexicalNameLookup(
            source: """
                struct S {
                    var explicitSetter: Int = 0 {
                        set(/*1️⃣*/newX) {
                            print(/*2️⃣*/newX)
                        }
                    }

                    var explicitDidSet: Int = 0 {
                        didSet(/*3️⃣*/old) {
                            print(/*4️⃣*/old)
                        }
                    }

                    var setterNamed: Int = 0 {
                        set(newX) {
                            print(/*5️⃣*/newValue)
                        }
                    }

                    var newValueOutsideSetter: Int = 0 {
                        set {}
                        get {
                            return /*6️⃣*/newValue
                        }
                    }

                    var crossAccessor: Int = 0 {
                        get {
                            let inGet = 1
                            return inGet
                        }
                        set {
                            let _ = /*7️⃣*/inGet
                        }
                    }
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "newX", atMarker: "1️⃣", kind: .identifier)
                ),
                "4️⃣": .init(
                    innerMost: .init(name: "old", atMarker: "3️⃣", kind: .identifier)
                ),
                "5️⃣": .init(notFound: "newValue"),
                "6️⃣": .init(notFound: "newValue"),
                "7️⃣": .init(notFound: "inGet"),
            ]
        )
    }

    @Test
    func lookupSubscript() {
        assertLexicalNameLookup(
            source: """
                struct S {
                    subscript(/*1️⃣*/a: Int) -> Int {
                        get { return /*2️⃣*/a }
                        set {}
                    }

                    subscript(/*3️⃣*/b: Int, _: Bool) -> Int {
                        get { return 0 }
                        /*4️⃣*/set {
                            print(/*5️⃣*/b, /*6️⃣*/newValue)
                        }
                    }

                    subscript(/*7️⃣*/c: Int, _: String) -> Int { /*8️⃣*/c }

                    subscript</*9️⃣*/U>(d: U) -> Int where U: Equatable {
                        get { let x: /*🔟*/U? = nil; return 0 }
                    }
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "a", atMarker: "1️⃣", kind: .identifier)
                ),
                "5️⃣": .init(
                    innerMost: .init(name: "b", atMarker: "3️⃣", kind: .identifier)
                ),
                "6️⃣": .init(
                    innerMost: .init(name: "newValue", atMarker: "4️⃣", kind: .implicit)
                ),
                "8️⃣": .init(
                    innerMost: .init(name: "c", atMarker: "7️⃣", kind: .identifier)
                ),
                "🔟": .init(
                    innerMost: .init(name: "U", atMarker: "9️⃣", kind: .identifier)
                ),
            ]
        )

        assertLexicalNameLookup(
            source: """
                struct S {
                    subscript(i: Int) -> Int { return 0 }

                    func f() {
                        let _ = /*1️⃣*/i
                    }
                }
                """,
            references: [
                "1️⃣": .init(notFound: "i")
            ]
        )
    }

    @Test
    func lookupEnumCase() {
        assertLexicalNameLookup(
            source: """
                let /*1️⃣*/outer = 0
                enum E {
                    case fromOuter(x: Int = /*2️⃣*/outer)
                    case sibling(x: Int = 0, y: Int = /*3️⃣*/x)
                    case bareCase
                    func f() {
                        let _ = /*4️⃣*/bareCase
                    }
                }
                """,
            references: [
                "2️⃣": .init(
                    innerMost: .init(name: "outer", atMarker: "1️⃣", kind: .identifier)
                ),
                "3️⃣": .init(notFound: "x"),
                "4️⃣": .init(notFound: "bareCase"),
            ]
        )
    }
}

// MARK: - Helpers

extension SwiftSyntaxScopeTests {
    func parseMarkedSource(_ source: String) -> MarkedTestSource {
        MarkedTestSource(source: source)
    }

    struct MarkedTestSource {
        let syntax: SourceFileSyntax

        private let positionsByMarker: [String: AbsolutePosition]

        init(source: String) {
            syntax = Parser.parse(source: source)
            positionsByMarker = SwiftSyntaxScopeTests.extractMarkers(from: syntax)
        }

        func position(of marker: String) -> AbsolutePosition {
            guard let position = positionsByMarker[marker] else {
                preconditionFailure("Missing marker '\(marker)'")
            }

            return position
        }
    }
}

extension SwiftSyntaxScopeTests {
    struct LookupNameRef {
        let name: StaticString
        let atMarker: String
        let kind: LookupName.Kind
    }

    struct LookupReference {
        let innerMost: LookupNameRef?
        let outer: [LookupNameRef]
        private let notFoundName: StaticString?

        var lookupName: StaticString {
            innerMost?.name ?? notFoundName!
        }

        init(innerMost: LookupNameRef, outer: [LookupNameRef] = []) {
            self.innerMost = innerMost
            self.outer = outer
            self.notFoundName = nil
        }

        init(notFound name: StaticString) {
            self.innerMost = nil
            self.outer = []
            self.notFoundName = name
        }
    }

    func assertLexicalNameLookup(
        source: String,
        references: [String: LookupReference],
        sourceLocation: Testing.SourceLocation = #_sourceLocation
    ) {
        let parsed = parseMarkedSource(source)

        for marker in references.keys.sorted() {
            let reference = references[marker]!
            let position = parsed.position(of: marker)

            let innerMostRecord = reference.innerMost.map { $0.asRecord(in: parsed) }
            let expectedNormal = innerMostRecord.map { [$0] } ?? []
            let expectedOuter = expectedNormal + reference.outer.map { $0.asRecord(in: parsed) }

            let normalResults = runLexicalLookup(
                sourceFile: parsed.syntax,
                position: position,
                name: reference.lookupName
            )
            #expect(
                normalResults == expectedNormal,
                "normal-mode lookup at marker '\(marker)' for name '\(reference.lookupName)'",
                sourceLocation: sourceLocation
            )

            let outerResults = runLexicalLookup(
                sourceFile: parsed.syntax,
                position: position,
                name: reference.lookupName,
                options: [.includeOuterResults]
            )
            #expect(
                outerResults == expectedOuter,
                "outer-mode lookup at marker '\(marker)' for name '\(reference.lookupName)'",
                sourceLocation: sourceLocation
            )
        }
    }
}

private extension SwiftSyntaxScopeTests.LookupNameRef {
    func asRecord(in parsed: SwiftSyntaxScopeTests.MarkedTestSource) -> LookupNameRecord {
        LookupNameRecord(
            name: "\(name)",
            position: parsed.position(of: atMarker),
            kind: kind
        )
    }
}

private extension SwiftSyntaxScopeTests {
    typealias UnsupportedLookupTestCase = (source: String, name: StaticString)

    func runLexicalLookup(
        sourceFile: SourceFileSyntax,
        position: AbsolutePosition,
        name: StaticString? = nil,
        options: LookupOptions = []
    ) -> [LookupNameRecord] {
        let results = sourceFile.lexicalLookup(
            position: position,
            name: name.map { Identifier(canonicalName: $0) },
            options: options
        )

        return results.map(LookupNameRecord.init)
    }

    static func extractMarkers(from syntax: SourceFileSyntax) -> [String: AbsolutePosition] {
        var positionsByMarker: [String: AbsolutePosition] = [:]
        var pendingMarkers = [String]()

        for token in syntax.tokens(viewMode: .sourceAccurate) {
            for marker in pendingMarkers {
                guard positionsByMarker[marker] == nil else {
                    preconditionFailure("Duplicate marker '\(marker)'")
                }

                positionsByMarker[marker] = token.positionAfterSkippingLeadingTrivia
            }
            pendingMarkers.removeAll(keepingCapacity: true)

            for piece in token.leadingTrivia.pieces {
                guard let marker = markerName(from: piece) else {
                    continue
                }
                guard positionsByMarker[marker] == nil else {
                    preconditionFailure("Duplicate marker '\(marker)'")
                }

                positionsByMarker[marker] = token.positionAfterSkippingLeadingTrivia
            }

            for piece in token.trailingTrivia.pieces {
                guard let marker = markerName(from: piece) else {
                    continue
                }

                pendingMarkers.append(marker)
            }
        }

        guard pendingMarkers.isEmpty else {
            preconditionFailure("Marker must precede a token")
        }

        return positionsByMarker
    }

    static func markerName(from triviaPiece: TriviaPiece) -> String? {
        guard case .blockComment(let text) = triviaPiece else {
            return nil
        }
        guard text.hasPrefix("/*"), text.hasSuffix("*/"), text.count > 4 else {
            preconditionFailure("Marker comment must not be empty")
        }

        return String(text.dropFirst(2).dropLast(2))
    }

    static var unsupportedLookupTestCases: [UnsupportedLookupTestCase] {
        [
            (
                """
                let first = /*1️⃣*/value
                let value = 10
                """,
                "value"
            ),
            (
                """
                func value() -> Int {
                    10
                }

                let first = /*1️⃣*/value()
                """,
                "value"
            ),
            (
                """
                let first = /*1️⃣*/value()

                func value() -> Int {
                    10
                }
                """,
                "value"
            ),
            (
                """
                struct Hoge {}

                let first = /*1️⃣*/Hoge()
                """,
                "Hoge"
            ),
            (
                """
                let first = /*1️⃣*/Hoge()

                struct Hoge {}
                """,
                "Hoge"
            ),
            (
                """
                struct Hoge {
                    func f() {
                        let value = /*1️⃣*/a
                    }
                }

                var a = 10
                """,
                "a"
            ),
            // 参考実装 (ExtensionDeclSyntax.lookup) は memberBlock 範囲内のみ
            // .implicit(.Self) を導入する。 where clause / inheritance clause /
            // extended type 内の Self は SyntaxScope ではなく type-checker 側で
            // extended type に解決される設計のため、ここでは lookup 不可。
            (
                """
                struct Box<T> {}
                extension Box where /*1️⃣*/Self: Equatable {}
                """,
                "Self"
            ),
        ]
    }
}

private final class VariableDeclCollector: SyntaxVisitor {
    private(set) var variables: [VariableDeclSyntax] = []

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        variables.append(node)
        return .skipChildren
    }
}

private func collectVariableDecls(
    in syntax: some SyntaxProtocol
) -> [VariableDeclSyntax] {
    let collector = VariableDeclCollector(viewMode: .sourceAccurate)
    collector.walk(syntax)
    return collector.variables
}

struct LookupNameRecord: Equatable {
    let name: String
    let position: AbsolutePosition
    let kind: LookupName.Kind

    init(name: String, position: AbsolutePosition, kind: LookupName.Kind) {
        self.name = name
        self.position = position
        self.kind = kind
    }

    init(_ lookup: LookupName) {
        self.name = lookup.text
        self.position = lookup.position
        self.kind = lookup.kind
    }
}
