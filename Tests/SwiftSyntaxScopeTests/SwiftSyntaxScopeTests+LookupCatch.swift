import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftSyntaxScope

extension SwiftSyntaxScopeTests {
    @Test
    func lookupCatchNodeFindsTryForceUnwrap() throws {
        let parsed = parseMarkedSource(
            """
            func f() {
                let value = /*1️⃣*/try! /*2️⃣*/throwing()
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isAnyTry)
        #expect(result.position == parsed.position(of: "1️⃣"))
        #expect(result.anyTry?.questionOrExclamationMark?.text == "!")
    }

    @Test
    func lookupCatchNodeFindsTryOptional() throws {
        let parsed = parseMarkedSource(
            """
            func f() {
                let value = /*1️⃣*/try? /*2️⃣*/throwing()
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isAnyTry)
        #expect(result.position == parsed.position(of: "1️⃣"))
        #expect(result.anyTry?.questionOrExclamationMark?.text == "?")
    }

    @Test
    func lookupCatchNodeSkipsPlainTry() throws {
        let parsed = parseMarkedSource(
            """
            /*1️⃣*/func f() throws {
                try /*2️⃣*/throwing()
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isFunction)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeFindsEnclosingFunction() throws {
        let parsed = parseMarkedSource(
            """
            /*1️⃣*/func f() throws {
                try /*2️⃣*/throwing()
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isFunction)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeFindsEnclosingInitializer() throws {
        let parsed = parseMarkedSource(
            """
            struct S {
                /*1️⃣*/init() throws {
                    try /*2️⃣*/throwing()
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isFunction)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeFindsEnclosingClosure() throws {
        let parsed = parseMarkedSource(
            """
            func f() {
                let c = /*1️⃣*/{ () -> Int in
                    try /*2️⃣*/throwing()
                    return 0
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isClosure)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeFindsEnclosingDoCatch() throws {
        let parsed = parseMarkedSource(
            """
            func f() throws {
                /*1️⃣*/do {
                    try /*2️⃣*/throwing()
                } catch {
                    print(error)
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isDoCatch)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeSkipsPlainDoWithoutCatch() throws {
        let parsed = parseMarkedSource(
            """
            /*1️⃣*/func f() throws {
                do {
                    try /*2️⃣*/throwing()
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isFunction)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeNestedDoCatchReturnsInnermost() throws {
        let parsed = parseMarkedSource(
            """
            func f() throws {
                do {
                    /*1️⃣*/do {
                        try /*2️⃣*/throwing()
                    } catch let inner {
                        print(inner)
                    }
                } catch let outer {
                    print(outer)
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isDoCatch)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeTryShadowsDoCatch() throws {
        let parsed = parseMarkedSource(
            """
            func f() throws {
                do {
                    let v = /*1️⃣*/try! /*2️⃣*/throwing()
                } catch {
                    print(error)
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isAnyTry)
        #expect(result.position == parsed.position(of: "1️⃣"))
        #expect(result.anyTry?.questionOrExclamationMark?.text == "!")
    }

    @Test
    func lookupCatchNodeReturnsNilAtTopLevel() {
        let parsed = parseMarkedSource(
            """
            try /*2️⃣*/throwing()
            """
        )

        let result = parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣"))

        #expect(result == nil)
    }

    @Test
    func lookupCatchNodeFindsEnclosingDeinitializer() throws {
        let parsed = parseMarkedSource(
            """
            class C {
                /*1️⃣*/deinit {
                    try /*2️⃣*/throwing()
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isFunction)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeFindsClosureWithCaptureList() throws {
        let parsed = parseMarkedSource(
            """
            func f() {
                let c = /*1️⃣*/{ [weak self] () -> Int in
                    try /*2️⃣*/throwing()
                    return 0
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isClosure)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeFindsEnclosingSubscriptAccessor() throws {
        let parsed = parseMarkedSource(
            """
            struct S {
                subscript(i: Int) -> Int {
                    /*1️⃣*/get throws {
                        try /*2️⃣*/throwing()
                        return 0
                    }
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isFunction)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }

    @Test
    func lookupCatchNodeBeforeInKeywordSkipsClosure() throws {
        let parsed = parseMarkedSource(
            """
            /*1️⃣*/func f() throws {
                let c = { (x: Int = try /*2️⃣*/throwing()) -> Int in
                    return 0
                }
            }
            """
        )

        let result = try #require(parsed.syntax.lookupCatchNode(at: parsed.position(of: "2️⃣")))

        #expect(result.isFunction)
        #expect(result.position == parsed.position(of: "1️⃣"))
    }
}
