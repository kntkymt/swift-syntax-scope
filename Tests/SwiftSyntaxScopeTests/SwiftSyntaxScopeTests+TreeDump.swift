import Testing

extension SwiftSyntaxScopeTests {
    @Test(arguments: treeDumpTestCases)
    func buildScopeTree(source: String, expected: String) {
        assertTreeDump(source: source, expected: expected)
    }
}

private extension SwiftSyntaxScopeTests {
    static var treeDumpTestCases: [TreeDumpTestCase] {
        [
            (
                """
                func f() {
                    let a = 1
                    let b = 2
                }
                """,
                """
                SourceFileScope [1:1 - 4:1]
                `-AbstractFunctionDeclScope [1:1 - 4:1] 'f()'
                  `-FunctionBodyScope [1:10 - 4:1]
                    `-BraceStmtScope [1:10 - 4:1]
                      `-PatternEntryDeclScope [2:9 - 4:1] entry 0 introduces=[identifier:a]
                        |-PatternEntryInitializerScope [2:13 - 2:13] entry 0
                        `-PatternEntryDeclScope [3:9 - 4:1] entry 0 introduces=[identifier:b]
                          `-PatternEntryInitializerScope [3:13 - 3:13] entry 0
                """
            ),
            (
                """
                func f(a: Int) {
                    let a = 10
                    let b = a
                }
                """,
                """
                SourceFileScope [1:1 - 4:1]
                `-AbstractFunctionDeclScope [1:1 - 4:1] 'f(a:)'
                  |-ParameterListScope [1:7 - 1:14]
                  `-FunctionBodyScope [1:16 - 4:1] introduces=[identifier:a]
                    `-BraceStmtScope [1:16 - 4:1]
                      `-PatternEntryDeclScope [2:9 - 4:1] entry 0 introduces=[identifier:a]
                        |-PatternEntryInitializerScope [2:13 - 2:14] entry 0
                        `-PatternEntryDeclScope [3:9 - 4:1] entry 0 introduces=[identifier:b]
                          `-PatternEntryInitializerScope [3:13 - 3:13] entry 0
                """
            ),
            (
                """
                func f(a: Int = 0, b: Int = 1) {
                }
                """,
                """
                SourceFileScope [1:1 - 2:1]
                `-AbstractFunctionDeclScope [1:1 - 2:1] 'f(a:b:)'
                  |-ParameterListScope [1:7 - 1:30]
                  | |-DefaultArgumentInitializerScope [1:17 - 1:17]
                  | `-DefaultArgumentInitializerScope [1:29 - 1:29]
                  `-FunctionBodyScope [1:32 - 2:1] introduces=[identifier:a, identifier:b]
                """
            ),
            (
                """
                struct Outer {
                    struct Inner {
                    }
                }

                let value = 1
                """,
                """
                SourceFileScope [1:1 - 6:13]
                |-NominalTypeDeclScope [1:1 - 4:1] 'Outer'
                | `-NominalTypeBodyScope [1:14 - 4:1] 'Outer' introduces=[declaration:Inner]
                |   `-NominalTypeDeclScope [2:5 - 3:5] 'Inner'
                |     `-NominalTypeBodyScope [2:18 - 3:5] 'Inner'
                `-TopLevelCodeScope [6:1 - 6:13] introduces=[identifier:value]
                  `-PatternEntryDeclScope [6:5 - 6:13] entry 0
                    `-PatternEntryInitializerScope [6:13 - 6:13] entry 0
                """
            ),
            (
                """
                let a = 1

                struct Outer {
                }

                let b = a
                """,
                """
                SourceFileScope [1:1 - 6:9]
                `-TopLevelCodeScope [1:1 - 6:9] introduces=[identifier:a]
                  |-PatternEntryDeclScope [1:5 - 1:9] entry 0
                  | `-PatternEntryInitializerScope [1:9 - 1:9] entry 0
                  |-NominalTypeDeclScope [3:1 - 4:1] 'Outer'
                  | `-NominalTypeBodyScope [3:14 - 4:1] 'Outer'
                  `-TopLevelCodeScope [6:1 - 6:9] introduces=[identifier:b]
                    `-PatternEntryDeclScope [6:5 - 6:9] entry 0
                      `-PatternEntryInitializerScope [6:9 - 6:9] entry 0
                """
            ),
            (
                """
                func f() {
                    struct Local {
                    }

                    let value = 1
                }
                """,
                """
                SourceFileScope [1:1 - 6:1]
                `-AbstractFunctionDeclScope [1:1 - 6:1] 'f()'
                  `-FunctionBodyScope [1:10 - 6:1]
                    `-BraceStmtScope [1:10 - 6:1] introduces=[declaration:Local]
                      |-NominalTypeDeclScope [2:5 - 3:5] 'Local'
                      | `-NominalTypeBodyScope [2:18 - 3:5] 'Local'
                      `-PatternEntryDeclScope [5:9 - 6:1] entry 0 introduces=[identifier:value]
                        `-PatternEntryInitializerScope [5:17 - 5:17] entry 0
                """
            ),
            (
                """
                func f() {
                    let a = 1

                    if let c = p() {
                        let d = 4
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 7:1]
                `-AbstractFunctionDeclScope [1:1 - 7:1] 'f()'
                  `-FunctionBodyScope [1:10 - 7:1]
                    `-BraceStmtScope [1:10 - 7:1]
                      `-PatternEntryDeclScope [2:9 - 7:1] entry 0 introduces=[identifier:a]
                        |-PatternEntryInitializerScope [2:13 - 2:13] entry 0
                        `-IfExprScope [4:5 - 6:5]
                          `-ConditionalClausePatternUseScope [4:8 - 6:5] introduces=[identifier:c]
                            |-ConditionalClauseInitializerScope [4:14 - 4:18]
                            `-BraceStmtScope [4:20 - 6:5]
                              `-PatternEntryDeclScope [5:13 - 6:5] entry 0 introduces=[identifier:d]
                                `-PatternEntryInitializerScope [5:17 - 5:17] entry 0
                """
            ),
            (
                """
                func f() {
                    let a = 1

                    if let c = p() {
                        let d = 4
                    }

                    if let e = p() {
                        let f = 4
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 11:1]
                `-AbstractFunctionDeclScope [1:1 - 11:1] 'f()'
                  `-FunctionBodyScope [1:10 - 11:1]
                    `-BraceStmtScope [1:10 - 11:1]
                      `-PatternEntryDeclScope [2:9 - 11:1] entry 0 introduces=[identifier:a]
                        |-PatternEntryInitializerScope [2:13 - 2:13] entry 0
                        |-IfExprScope [4:5 - 6:5]
                        | `-ConditionalClausePatternUseScope [4:8 - 6:5] introduces=[identifier:c]
                        |   |-ConditionalClauseInitializerScope [4:14 - 4:18]
                        |   `-BraceStmtScope [4:20 - 6:5]
                        |     `-PatternEntryDeclScope [5:13 - 6:5] entry 0 introduces=[identifier:d]
                        |       `-PatternEntryInitializerScope [5:17 - 5:17] entry 0
                        `-IfExprScope [8:5 - 10:5]
                          `-ConditionalClausePatternUseScope [8:8 - 10:5] introduces=[identifier:e]
                            |-ConditionalClauseInitializerScope [8:14 - 8:18]
                            `-BraceStmtScope [8:20 - 10:5]
                              `-PatternEntryDeclScope [9:13 - 10:5] entry 0 introduces=[identifier:f]
                                `-PatternEntryInitializerScope [9:17 - 9:17] entry 0
                """
            ),
            (
                """
                func f() {
                    do {
                        let a = 1
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 5:1]
                `-AbstractFunctionDeclScope [1:1 - 5:1] 'f()'
                  `-FunctionBodyScope [1:10 - 5:1]
                    `-BraceStmtScope [1:10 - 5:1]
                      `-DoStmtScope [2:5 - 4:5]
                        `-BraceStmtScope [2:8 - 4:5]
                          `-PatternEntryDeclScope [3:13 - 4:5] entry 0 introduces=[identifier:a]
                            `-PatternEntryInitializerScope [3:17 - 3:17] entry 0
                """
            ),
            (
                """
                func f() {
                    let a = 1
                    do {
                        let b = 10
                    } catch {
                        let c = 10
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 8:1]
                `-AbstractFunctionDeclScope [1:1 - 8:1] 'f()'
                  `-FunctionBodyScope [1:10 - 8:1]
                    `-BraceStmtScope [1:10 - 8:1]
                      `-PatternEntryDeclScope [2:9 - 8:1] entry 0 introduces=[identifier:a]
                        |-PatternEntryInitializerScope [2:13 - 2:13] entry 0
                        `-DoStmtScope [3:5 - 7:5]
                          |-BraceStmtScope [3:8 - 5:5]
                          | `-PatternEntryDeclScope [4:13 - 5:5] entry 0 introduces=[identifier:b]
                          |   `-PatternEntryInitializerScope [4:17 - 4:18] entry 0
                          `-CaseStmtScope [5:7 - 7:5]
                            `-CaseStmtBodyScope [5:13 - 7:5] introduces=[implicit:error]
                              `-BraceStmtScope [5:13 - 7:5]
                                `-PatternEntryDeclScope [6:13 - 7:5] entry 0 introduces=[identifier:c]
                                  `-PatternEntryInitializerScope [6:17 - 6:18] entry 0
                """
            ),
            (
                """
                func f() {
                    do {
                        work()
                    } catch let error where check(error) {
                        _ = error
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 7:1]
                `-AbstractFunctionDeclScope [1:1 - 7:1] 'f()'
                  `-FunctionBodyScope [1:10 - 7:1]
                    `-BraceStmtScope [1:10 - 7:1]
                      `-DoStmtScope [2:5 - 6:5]
                        |-BraceStmtScope [2:8 - 4:5]
                        `-CaseStmtScope [4:7 - 6:5]
                          |-CaseLabelItemScope [4:29 - 4:40] introduces=[identifier:error]
                          `-CaseStmtBodyScope [4:42 - 6:5] introduces=[identifier:error]
                            `-BraceStmtScope [4:42 - 6:5]
                """
            ),
            (
                """
                func f() {
                    for i in 10...15 {
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 4:1]
                `-AbstractFunctionDeclScope [1:1 - 4:1] 'f()'
                  `-FunctionBodyScope [1:10 - 4:1]
                    `-BraceStmtScope [1:10 - 4:1]
                      `-ForEachStmtScope [2:5 - 3:5]
                        `-ForEachPatternScope [2:22 - 3:5] introduces=[identifier:i]
                """
            ),
            (
                """
                func f() {
                    for i in 10...15 where i > 12 {
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 4:1]
                `-AbstractFunctionDeclScope [1:1 - 4:1] 'f()'
                  `-FunctionBodyScope [1:10 - 4:1]
                    `-BraceStmtScope [1:10 - 4:1]
                      `-ForEachStmtScope [2:5 - 3:5]
                        `-ForEachPatternScope [2:22 - 3:5] introduces=[identifier:i]
                """
            ),
            (
                """
                func f() {
                    let a = 1
                    for i in 1...5 where { let a = true; return a }() {
                        let b = a
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 6:1]
                `-AbstractFunctionDeclScope [1:1 - 6:1] 'f()'
                  `-FunctionBodyScope [1:10 - 6:1]
                    `-BraceStmtScope [1:10 - 6:1]
                      `-PatternEntryDeclScope [2:9 - 6:1] entry 0 introduces=[identifier:a]
                        |-PatternEntryInitializerScope [2:13 - 2:13] entry 0
                        `-ForEachStmtScope [3:5 - 5:5]
                          `-ForEachPatternScope [3:20 - 5:5] introduces=[identifier:i]
                            |-ClosureParametersScope [3:28 - 3:51]
                            | `-BraceStmtScope [3:28 - 3:51]
                            |   `-PatternEntryDeclScope [3:32 - 3:51] entry 0 introduces=[identifier:a]
                            |     `-PatternEntryInitializerScope [3:36 - 3:39] entry 0
                            `-BraceStmtScope [3:55 - 5:5]
                              `-PatternEntryDeclScope [4:13 - 5:5] entry 0 introduces=[identifier:b]
                                `-PatternEntryInitializerScope [4:17 - 4:17] entry 0
                """
            ),
            (
                """
                func f() {
                    while let a = p() {
                        let b = a
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 5:1]
                `-AbstractFunctionDeclScope [1:1 - 5:1] 'f()'
                  `-FunctionBodyScope [1:10 - 5:1]
                    `-BraceStmtScope [1:10 - 5:1]
                      `-WhileStmtScope [2:5 - 4:5]
                        `-ConditionalClausePatternUseScope [2:11 - 4:5] introduces=[identifier:a]
                          |-ConditionalClauseInitializerScope [2:17 - 2:21]
                          `-BraceStmtScope [2:23 - 4:5]
                            `-PatternEntryDeclScope [3:13 - 4:5] entry 0 introduces=[identifier:b]
                              `-PatternEntryInitializerScope [3:17 - 3:17] entry 0
                """
            ),
            (
                """
                func f() {
                    while let a = p(), let b = q(a) {
                        let c = b
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 5:1]
                `-AbstractFunctionDeclScope [1:1 - 5:1] 'f()'
                  `-FunctionBodyScope [1:10 - 5:1]
                    `-BraceStmtScope [1:10 - 5:1]
                      `-WhileStmtScope [2:5 - 4:5]
                        `-ConditionalClausePatternUseScope [2:11 - 4:5] introduces=[identifier:a]
                          |-ConditionalClauseInitializerScope [2:17 - 2:21]
                          `-ConditionalClausePatternUseScope [2:24 - 4:5] introduces=[identifier:b]
                            |-ConditionalClauseInitializerScope [2:30 - 2:35]
                            `-BraceStmtScope [2:37 - 4:5]
                              `-PatternEntryDeclScope [3:13 - 4:5] entry 0 introduces=[identifier:c]
                                `-PatternEntryInitializerScope [3:17 - 3:17] entry 0
                """
            ),
            (
                """
                func f() {
                    while check({
                        let inner = 1
                        return inner > 0
                    }) {
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 7:1]
                `-AbstractFunctionDeclScope [1:1 - 7:1] 'f()'
                  `-FunctionBodyScope [1:10 - 7:1]
                    `-BraceStmtScope [1:10 - 7:1]
                      `-WhileStmtScope [2:5 - 6:5]
                        `-ClosureParametersScope [3:9 - 5:5]
                          `-BraceStmtScope [3:9 - 5:5]
                            `-PatternEntryDeclScope [3:13 - 5:5] entry 0 introduces=[identifier:inner]
                              `-PatternEntryInitializerScope [3:21 - 3:21] entry 0
                """
            ),
            (
                """
                func f() {
                    repeat {
                        let value = 1
                    } while check({
                        let inner = 0
                        return inner >= 0
                    })
                }
                """,
                """
                SourceFileScope [1:1 - 8:1]
                `-AbstractFunctionDeclScope [1:1 - 8:1] 'f()'
                  `-FunctionBodyScope [1:10 - 8:1]
                    `-BraceStmtScope [1:10 - 8:1]
                      `-RepeatWhileScope [2:5 - 7:6]
                        |-BraceStmtScope [2:12 - 4:5]
                        | `-PatternEntryDeclScope [3:13 - 4:5] entry 0 introduces=[identifier:value]
                        |   `-PatternEntryInitializerScope [3:21 - 3:21] entry 0
                        `-ClosureParametersScope [5:9 - 7:5]
                          `-BraceStmtScope [5:9 - 7:5]
                            `-PatternEntryDeclScope [5:13 - 7:5] entry 0 introduces=[identifier:inner]
                              `-PatternEntryInitializerScope [5:21 - 5:21] entry 0
                """
            ),
            (
                """
                func f() {
                    guard let a = p() else {
                        let b = 1
                    }

                    let c = a
                }
                """,
                """
                SourceFileScope [1:1 - 7:1]
                `-AbstractFunctionDeclScope [1:1 - 7:1] 'f()'
                  `-FunctionBodyScope [1:10 - 7:1]
                    `-BraceStmtScope [1:10 - 7:1]
                      `-GuardStmtScope [2:5 - 7:1]
                        `-ConditionalClausePatternUseScope [2:11 - 7:1] introduces=[identifier:a]
                          |-ConditionalClauseInitializerScope [2:17 - 2:21]
                          |-GuardStmtBodyScope [2:28 - 4:5]
                          | `-BraceStmtScope [2:28 - 4:5]
                          |   `-PatternEntryDeclScope [3:13 - 4:5] entry 0 introduces=[identifier:b]
                          |     `-PatternEntryInitializerScope [3:17 - 3:17] entry 0
                          `-PatternEntryDeclScope [6:9 - 7:1] entry 0 introduces=[identifier:c]
                            `-PatternEntryInitializerScope [6:13 - 6:13] entry 0
                """
            ),
            (
                """
                func f() {
                    guard let a = p(), let b = q(a) else {
                        let d = 1
                    }

                    let c = b
                }
                """,
                """
                SourceFileScope [1:1 - 7:1]
                `-AbstractFunctionDeclScope [1:1 - 7:1] 'f()'
                  `-FunctionBodyScope [1:10 - 7:1]
                    `-BraceStmtScope [1:10 - 7:1]
                      `-GuardStmtScope [2:5 - 7:1]
                        `-ConditionalClausePatternUseScope [2:11 - 7:1] introduces=[identifier:a]
                          |-ConditionalClauseInitializerScope [2:17 - 2:21]
                          `-ConditionalClausePatternUseScope [2:24 - 7:1] introduces=[identifier:b]
                            |-ConditionalClauseInitializerScope [2:30 - 2:35]
                            |-GuardStmtBodyScope [2:42 - 4:5]
                            | `-BraceStmtScope [2:42 - 4:5]
                            |   `-PatternEntryDeclScope [3:13 - 4:5] entry 0 introduces=[identifier:d]
                            |     `-PatternEntryInitializerScope [3:17 - 3:17] entry 0
                            `-PatternEntryDeclScope [6:9 - 7:1] entry 0 introduces=[identifier:c]
                              `-PatternEntryInitializerScope [6:13 - 6:13] entry 0
                """
            ),
            (
                """
                func f() {
                    guard case let a = p() else {
                        return
                    }

                    let b = a
                }
                """,
                """
                SourceFileScope [1:1 - 7:1]
                `-AbstractFunctionDeclScope [1:1 - 7:1] 'f()'
                  `-FunctionBodyScope [1:10 - 7:1]
                    `-BraceStmtScope [1:10 - 7:1]
                      `-GuardStmtScope [2:5 - 7:1]
                        `-ConditionalClausePatternUseScope [2:11 - 7:1] introduces=[identifier:a]
                          |-ConditionalClauseInitializerScope [2:22 - 2:26]
                          |-GuardStmtBodyScope [2:33 - 4:5]
                          | `-BraceStmtScope [2:33 - 4:5]
                          `-PatternEntryDeclScope [6:9 - 7:1] entry 0 introduces=[identifier:b]
                            `-PatternEntryInitializerScope [6:13 - 6:13] entry 0
                """
            ),
            (
                """
                func f() {
                    let a = 1
                    switch 1 {
                    case 1:
                        let b = a
                    case 2:
                        let b = a
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 9:1]
                `-AbstractFunctionDeclScope [1:1 - 9:1] 'f()'
                  `-FunctionBodyScope [1:10 - 9:1]
                    `-BraceStmtScope [1:10 - 9:1]
                      `-PatternEntryDeclScope [2:9 - 9:1] entry 0 introduces=[identifier:a]
                        |-PatternEntryInitializerScope [2:13 - 2:13] entry 0
                        `-SwitchExprScope [3:5 - 8:5]
                          |-CaseStmtScope [4:5 - 5:17]
                          | `-CaseStmtBodyScope [5:9 - 5:17]
                          |   `-BraceStmtScope [5:9 - 5:17]
                          |     `-PatternEntryDeclScope [5:13 - 5:17] entry 0 introduces=[identifier:b]
                          |       `-PatternEntryInitializerScope [5:17 - 5:17] entry 0
                          `-CaseStmtScope [6:5 - 7:17]
                            `-CaseStmtBodyScope [7:9 - 7:17]
                              `-BraceStmtScope [7:9 - 7:17]
                                `-PatternEntryDeclScope [7:13 - 7:17] entry 0 introduces=[identifier:b]
                                  `-PatternEntryInitializerScope [7:17 - 7:17] entry 0
                """
            ),
            (
                """
                func f() {
                    switch value {
                    case .a(let x) where check(x):
                        let b = x
                    case let .b(y):
                        let b = y
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 8:1]
                `-AbstractFunctionDeclScope [1:1 - 8:1] 'f()'
                  `-FunctionBodyScope [1:10 - 8:1]
                    `-BraceStmtScope [1:10 - 8:1]
                      `-SwitchExprScope [2:5 - 7:5]
                        |-CaseStmtScope [3:5 - 4:17]
                        | |-CaseLabelItemScope [3:26 - 3:33] introduces=[identifier:x]
                        | `-CaseStmtBodyScope [4:9 - 4:17] introduces=[identifier:x]
                        |   `-BraceStmtScope [4:9 - 4:17]
                        |     `-PatternEntryDeclScope [4:13 - 4:17] entry 0 introduces=[identifier:b]
                        |       `-PatternEntryInitializerScope [4:17 - 4:17] entry 0
                        `-CaseStmtScope [5:5 - 6:17]
                          `-CaseStmtBodyScope [6:9 - 6:17] introduces=[identifier:y]
                            `-BraceStmtScope [6:9 - 6:17]
                              `-PatternEntryDeclScope [6:13 - 6:17] entry 0 introduces=[identifier:b]
                                `-PatternEntryInitializerScope [6:17 - 6:17] entry 0
                """
            ),
            (
                """
                extension Foo {
                }
                """,
                """
                SourceFileScope [1:1 - 2:1]
                `-ExtensionDeclScope [1:14 - 2:1] 'Foo'
                  `-ExtensionBodyScope [1:15 - 2:1] 'Foo' introduces=[implicit:Self]
                """
            ),
            (
                """
                extension Foo {
                    func bar() {
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 4:1]
                `-ExtensionDeclScope [1:14 - 4:1] 'Foo'
                  `-ExtensionBodyScope [1:15 - 4:1] 'Foo' introduces=[implicit:Self, declaration:bar]
                    `-AbstractFunctionDeclScope [2:5 - 3:5] 'bar()'
                      `-FunctionBodyScope [2:16 - 3:5] introduces=[implicit:self]
                """
            ),
            (
                """
                struct Foo {
                }

                extension Foo {
                    func bar() {
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 7:1]
                |-NominalTypeDeclScope [1:1 - 2:1] 'Foo'
                | `-NominalTypeBodyScope [1:12 - 2:1] 'Foo'
                `-ExtensionDeclScope [4:14 - 7:1] 'Foo'
                  `-ExtensionBodyScope [4:15 - 7:1] 'Foo' introduces=[implicit:Self, declaration:bar]
                    `-AbstractFunctionDeclScope [5:5 - 6:5] 'bar()'
                      `-FunctionBodyScope [5:16 - 6:5] introduces=[implicit:self]
                """
            ),
            (
                """
                struct Foo<T> where T: Equatable {
                }
                """,
                """
                SourceFileScope [1:1 - 2:1]
                `-NominalTypeDeclScope [1:1 - 2:1] 'Foo'
                  `-GenericParameterScope [1:13 - 2:1] 'T' introduces=[identifier:T]
                    |-NominalTypeWhereScope [1:15 - 1:32] 'Foo'
                    `-NominalTypeBodyScope [1:34 - 2:1] 'Foo'
                """
            ),
            (
                """
                struct Foo<T, U> {
                }
                """,
                """
                SourceFileScope [1:1 - 2:1]
                `-NominalTypeDeclScope [1:1 - 2:1] 'Foo'
                  `-GenericParameterScope [1:14 - 2:1] 'T' introduces=[identifier:T]
                    `-GenericParameterScope [1:16 - 2:1] 'U' introduces=[identifier:U]
                      `-NominalTypeBodyScope [1:18 - 2:1] 'Foo'
                """
            ),
            (
                """
                func f<T>(a: T) {
                }
                """,
                """
                SourceFileScope [1:1 - 2:1]
                `-AbstractFunctionDeclScope [1:1 - 2:1] 'f(a:)'
                  `-GenericParameterScope [1:9 - 2:1] 'T' introduces=[identifier:T]
                    |-ParameterListScope [1:10 - 1:15]
                    `-FunctionBodyScope [1:17 - 2:1] introduces=[identifier:a]
                """
            ),
            (
                """
                extension Foo where T: Equatable {
                    func bar() {
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 4:1]
                `-ExtensionDeclScope [1:14 - 4:1] 'Foo'
                  |-ExtensionWhereScope [1:15 - 1:32] 'Foo'
                  `-ExtensionBodyScope [1:34 - 4:1] 'Foo' introduces=[implicit:Self, declaration:bar]
                    `-AbstractFunctionDeclScope [2:5 - 3:5] 'bar()'
                      `-FunctionBodyScope [2:16 - 3:5] introduces=[implicit:self]
                """
            ),
            (
                """
                extension Foo<T> {
                    func bar() {
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 4:1]
                `-ExtensionDeclScope [1:17 - 4:1] 'Foo<T>'
                  `-GenericParameterScope [1:16 - 4:1] 'T' introduces=[identifier:T]
                    `-ExtensionBodyScope [1:18 - 4:1] 'Foo<T>' introduces=[implicit:Self, declaration:bar]
                      `-AbstractFunctionDeclScope [2:5 - 3:5] 'bar()'
                        `-FunctionBodyScope [2:16 - 3:5] introduces=[implicit:self]
                """
            ),
            (
                """
                func f() {
                    let a = { b in
                        let c = b
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 5:1]
                `-AbstractFunctionDeclScope [1:1 - 5:1] 'f()'
                  `-FunctionBodyScope [1:10 - 5:1]
                    `-BraceStmtScope [1:10 - 5:1]
                      `-PatternEntryDeclScope [2:9 - 5:1] entry 0 introduces=[identifier:a]
                        `-PatternEntryInitializerScope [2:13 - 4:5] entry 0
                          `-ClosureParametersScope [3:9 - 4:5] introduces=[identifier:b]
                            `-BraceStmtScope [3:9 - 4:5]
                              `-PatternEntryDeclScope [3:13 - 4:5] entry 0 introduces=[identifier:c]
                                `-PatternEntryInitializerScope [3:17 - 3:17] entry 0
                """
            ),
            (
                """
                func f() {
                    let a = { (x: Int, y: Int) in
                        let c = x
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 5:1]
                `-AbstractFunctionDeclScope [1:1 - 5:1] 'f()'
                  `-FunctionBodyScope [1:10 - 5:1]
                    `-BraceStmtScope [1:10 - 5:1]
                      `-PatternEntryDeclScope [2:9 - 5:1] entry 0 introduces=[identifier:a]
                        `-PatternEntryInitializerScope [2:13 - 4:5] entry 0
                          `-ClosureParametersScope [3:9 - 4:5] introduces=[identifier:x, identifier:y]
                            `-BraceStmtScope [3:9 - 4:5]
                              `-PatternEntryDeclScope [3:13 - 4:5] entry 0 introduces=[identifier:c]
                                `-PatternEntryInitializerScope [3:17 - 3:17] entry 0
                """
            ),
            (
                """
                func f() {
                    call({
                        let inner = 1
                    })
                }
                """,
                """
                SourceFileScope [1:1 - 5:1]
                `-AbstractFunctionDeclScope [1:1 - 5:1] 'f()'
                  `-FunctionBodyScope [1:10 - 5:1]
                    `-BraceStmtScope [1:10 - 5:1]
                      `-ClosureParametersScope [3:9 - 4:5]
                        `-BraceStmtScope [3:9 - 4:5]
                          `-PatternEntryDeclScope [3:13 - 4:5] entry 0 introduces=[identifier:inner]
                            `-PatternEntryInitializerScope [3:21 - 3:21] entry 0
                """
            ),
            (
                """
                typealias Foo = Int
                """,
                """
                SourceFileScope [1:1 - 1:19]
                `-TypeAliasDeclScope [1:1 - 1:19] 'Foo'
                """
            ),
            (
                """
                typealias Foo<T> = Array<T>
                """,
                """
                SourceFileScope [1:1 - 1:27]
                `-TypeAliasDeclScope [1:1 - 1:27] 'Foo'
                  `-GenericParameterScope [1:16 - 1:27] 'T' introduces=[identifier:T]
                """
            ),
            (
                """
                typealias Foo<T> = Array<T> where T: Equatable
                """,
                """
                SourceFileScope [1:1 - 1:46]
                `-TypeAliasDeclScope [1:1 - 1:46] 'Foo'
                  `-GenericParameterScope [1:16 - 1:46] 'T' introduces=[identifier:T]
                    `-TypeAliasWhereScope [1:29 - 1:46] 'Foo'
                """
            ),
            (
                """
                struct S {
                    func f() {}
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 3:1] 'S' introduces=[declaration:f]
                    `-AbstractFunctionDeclScope [2:5 - 2:15] 'f()'
                      `-FunctionBodyScope [2:14 - 2:15] introduces=[implicit:self]
                """
            ),
            (
                """
                struct S {
                    init(value: Int) {}
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 3:1] 'S'
                    `-AbstractFunctionDeclScope [2:5 - 2:23] 'init(value:)'
                      |-ParameterListScope [2:9 - 2:20]
                      `-FunctionBodyScope [2:22 - 2:23] introduces=[identifier:value, implicit:self]
                """
            ),
            (
                """
                class C {
                    deinit {}
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'C'
                  `-NominalTypeBodyScope [1:9 - 3:1] 'C'
                    `-AbstractFunctionDeclScope [2:5 - 2:13] 'deinit'
                      `-FunctionBodyScope [2:12 - 2:13] introduces=[implicit:self]
                """
            ),
            (
                """
                struct S<T> {
                    init<U>(value: T, other: U) where U: Equatable {}
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'S'
                  `-GenericParameterScope [1:11 - 3:1] 'T' introduces=[identifier:T]
                    `-NominalTypeBodyScope [1:13 - 3:1] 'S'
                      `-AbstractFunctionDeclScope [2:5 - 2:53] 'init(value:other:)'
                        `-GenericParameterScope [2:11 - 2:53] 'U' introduces=[identifier:U]
                          |-ParameterListScope [2:12 - 2:31]
                          `-FunctionBodyScope [2:52 - 2:53] introduces=[identifier:value, identifier:other, implicit:self]
                """
            ),
            (
                """
                func f() {
                    let outer = 1
                    let c = { [outer] in outer }
                }
                """,
                """
                SourceFileScope [1:1 - 4:1]
                `-AbstractFunctionDeclScope [1:1 - 4:1] 'f()'
                  `-FunctionBodyScope [1:10 - 4:1]
                    `-BraceStmtScope [1:10 - 4:1]
                      `-PatternEntryDeclScope [2:9 - 4:1] entry 0 introduces=[identifier:outer]
                        |-PatternEntryInitializerScope [2:17 - 2:17] entry 0
                        `-PatternEntryDeclScope [3:9 - 4:1] entry 0 introduces=[identifier:c]
                          `-PatternEntryInitializerScope [3:13 - 3:32] entry 0
                            `-CaptureListScope [3:26 - 3:32] introduces=[identifier:outer]
                              `-ClosureParametersScope [3:26 - 3:32]
                                `-BraceStmtScope [3:26 - 3:32]
                """
            ),
            (
                """
                func f() throws {
                    let a = try p()
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-AbstractFunctionDeclScope [1:1 - 3:1] 'f()'
                  `-FunctionBodyScope [1:17 - 3:1]
                    `-BraceStmtScope [1:17 - 3:1]
                      `-PatternEntryDeclScope [2:9 - 3:1] entry 0 introduces=[identifier:a]
                        `-PatternEntryInitializerScope [2:13 - 2:19] entry 0
                          `-TryScope [2:13 - 2:19]
                """
            ),
            (
                """
                func f() throws {
                    let a = try? p()
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-AbstractFunctionDeclScope [1:1 - 3:1] 'f()'
                  `-FunctionBodyScope [1:17 - 3:1]
                    `-BraceStmtScope [1:17 - 3:1]
                      `-PatternEntryDeclScope [2:9 - 3:1] entry 0 introduces=[identifier:a]
                        `-PatternEntryInitializerScope [2:13 - 2:20] entry 0
                          `-TryScope [2:13 - 2:20]
                """
            ),
            (
                """
                func f() {
                    let a = try! p()
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-AbstractFunctionDeclScope [1:1 - 3:1] 'f()'
                  `-FunctionBodyScope [1:10 - 3:1]
                    `-BraceStmtScope [1:10 - 3:1]
                      `-PatternEntryDeclScope [2:9 - 3:1] entry 0 introduces=[identifier:a]
                        `-PatternEntryInitializerScope [2:13 - 2:20] entry 0
                          `-TryScope [2:13 - 2:20]
                """
            ),
            (
                """
                func f() throws {
                    let a = try { () in
                        let inner = 1
                        return inner
                    }()
                }
                """,
                """
                SourceFileScope [1:1 - 6:1]
                `-AbstractFunctionDeclScope [1:1 - 6:1] 'f()'
                  `-FunctionBodyScope [1:17 - 6:1]
                    `-BraceStmtScope [1:17 - 6:1]
                      `-PatternEntryDeclScope [2:9 - 6:1] entry 0 introduces=[identifier:a]
                        `-PatternEntryInitializerScope [2:13 - 5:7] entry 0
                          `-TryScope [2:13 - 5:7]
                            `-ClosureParametersScope [3:9 - 5:5]
                              `-BraceStmtScope [3:9 - 5:5]
                                `-PatternEntryDeclScope [3:13 - 5:5] entry 0 introduces=[identifier:inner]
                                  `-PatternEntryInitializerScope [3:21 - 3:21] entry 0
                """
            ),
            (
                """
                struct S {
                    var x: Int = 0 {
                        get { return 1 }
                        set { print(newValue) }
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 6:1]
                `-NominalTypeDeclScope [1:1 - 6:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 6:1] 'S' introduces=[identifier:x]
                    `-PatternEntryDeclScope [2:9 - 5:5] entry 0
                      |-PatternEntryInitializerScope [2:18 - 2:18] entry 0
                      |-AbstractFunctionDeclScope [3:9 - 3:24] 'get'
                      | `-FunctionBodyScope [3:13 - 3:24] introduces=[implicit:self]
                      |   `-BraceStmtScope [3:13 - 3:24]
                      `-AbstractFunctionDeclScope [4:9 - 4:31] 'set'
                        `-FunctionBodyScope [4:13 - 4:31] introduces=[implicit:newValue, implicit:self]
                          `-BraceStmtScope [4:13 - 4:31]
                """
            ),
            (
                """
                struct S {
                    var x: Int = 0 {
                        willSet { print(newValue) }
                        didSet(old) { print(old) }
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 6:1]
                `-NominalTypeDeclScope [1:1 - 6:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 6:1] 'S' introduces=[identifier:x]
                    `-PatternEntryDeclScope [2:9 - 5:5] entry 0
                      |-PatternEntryInitializerScope [2:18 - 2:18] entry 0
                      |-AbstractFunctionDeclScope [3:9 - 3:35] 'willSet'
                      | `-FunctionBodyScope [3:17 - 3:35] introduces=[implicit:newValue, implicit:self]
                      |   `-BraceStmtScope [3:17 - 3:35]
                      `-AbstractFunctionDeclScope [4:9 - 4:34] 'didSet(old)'
                        `-FunctionBodyScope [4:21 - 4:34] introduces=[identifier:old, implicit:self]
                          `-BraceStmtScope [4:21 - 4:34]
                """
            ),
            (
                """
                struct S {
                    var x: Int { return 1 }
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 3:1] 'S' introduces=[identifier:x]
                    `-PatternEntryDeclScope [2:9 - 2:27] entry 0
                      `-AbstractFunctionDeclScope [2:16 - 2:27] 'get'
                        `-FunctionBodyScope [2:16 - 2:27] introduces=[implicit:self]
                          `-BraceStmtScope [2:16 - 2:27]
                """
            ),
            (
                """
                struct S {
                    var x: Int {
                        let inner = 1
                        return inner
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 6:1]
                `-NominalTypeDeclScope [1:1 - 6:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 6:1] 'S' introduces=[identifier:x]
                    `-PatternEntryDeclScope [2:9 - 5:5] entry 0
                      `-AbstractFunctionDeclScope [2:16 - 5:5] 'get'
                        `-FunctionBodyScope [2:16 - 5:5] introduces=[implicit:self]
                          `-BraceStmtScope [2:16 - 5:5]
                            `-PatternEntryDeclScope [3:13 - 5:5] entry 0 introduces=[identifier:inner]
                              `-PatternEntryInitializerScope [3:21 - 3:21] entry 0
                """
            ),
            (
                """
                struct S {
                    subscript(i: Int) -> Int {
                        get { return 1 }
                        set { print(newValue) }
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 6:1]
                `-NominalTypeDeclScope [1:1 - 6:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 6:1] 'S'
                    `-SubscriptDeclScope [2:5 - 5:5] 'subscript(i:)' introduces=[identifier:i]
                      |-ParameterListScope [2:14 - 2:21]
                      |-AbstractFunctionDeclScope [3:9 - 3:24] 'get'
                      | `-FunctionBodyScope [3:13 - 3:24] introduces=[implicit:self]
                      |   `-BraceStmtScope [3:13 - 3:24]
                      `-AbstractFunctionDeclScope [4:9 - 4:31] 'set'
                        `-FunctionBodyScope [4:13 - 4:31] introduces=[implicit:newValue, implicit:self]
                          `-BraceStmtScope [4:13 - 4:31]
                """
            ),
            (
                """
                struct S {
                    subscript(i: Int) -> Int { i }
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 3:1] 'S'
                    `-SubscriptDeclScope [2:5 - 2:34] 'subscript(i:)' introduces=[identifier:i]
                      |-ParameterListScope [2:14 - 2:21]
                      `-AbstractFunctionDeclScope [2:30 - 2:34] 'get'
                        `-FunctionBodyScope [2:30 - 2:34] introduces=[implicit:self]
                          `-BraceStmtScope [2:30 - 2:34]
                """
            ),
            (
                """
                protocol P {
                    subscript(i: Int) -> Int { get set }
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'P' introduces=[implicit:Self]
                  `-NominalTypeBodyScope [1:12 - 3:1] 'P'
                    `-SubscriptDeclScope [2:5 - 2:40] 'subscript(i:)' introduces=[identifier:i]
                      |-ParameterListScope [2:14 - 2:21]
                      |-AbstractFunctionDeclScope [2:32 - 2:34] 'get'
                      `-AbstractFunctionDeclScope [2:36 - 2:38] 'set'
                """
            ),
            (
                """
                struct S<T> {
                    subscript<U>(i: U) -> T where U: Equatable {
                        get { return 1 as! T }
                    }
                }
                """,
                """
                SourceFileScope [1:1 - 5:1]
                `-NominalTypeDeclScope [1:1 - 5:1] 'S'
                  `-GenericParameterScope [1:11 - 5:1] 'T' introduces=[identifier:T]
                    `-NominalTypeBodyScope [1:13 - 5:1] 'S'
                      `-SubscriptDeclScope [2:5 - 4:5] 'subscript(i:)' introduces=[identifier:i]
                        `-GenericParameterScope [2:16 - 4:5] 'U' introduces=[identifier:U]
                          |-ParameterListScope [2:17 - 2:22]
                          `-AbstractFunctionDeclScope [3:9 - 3:30] 'get'
                            `-FunctionBodyScope [3:13 - 3:30] introduces=[implicit:self]
                              `-BraceStmtScope [3:13 - 3:30]
                """
            ),
            (
                """
                enum E {
                    case foo
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'E'
                  `-NominalTypeBodyScope [1:8 - 3:1] 'E'
                    `-EnumElementScope [2:10 - 2:12] 'foo'
                """
            ),
            (
                """
                enum E {
                    case foo, bar(Int)
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'E'
                  `-NominalTypeBodyScope [1:8 - 3:1] 'E'
                    |-EnumElementScope [2:10 - 2:13] 'foo'
                    `-EnumElementScope [2:15 - 2:22] 'bar'
                      `-ParameterListScope [2:18 - 2:22]
                """
            ),
            (
                """
                enum E {
                    case baz(label: Int = 0)
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'E'
                  `-NominalTypeBodyScope [1:8 - 3:1] 'E'
                    `-EnumElementScope [2:10 - 2:28] 'baz'
                      `-ParameterListScope [2:13 - 2:28]
                        `-DefaultArgumentInitializerScope [2:27 - 2:27]
                """
            ),
            (
                """
                enum E: Int {
                    case qux = 1
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'E'
                  `-NominalTypeBodyScope [1:13 - 3:1] 'E'
                    `-EnumElementScope [2:10 - 2:16] 'qux'
                """
            ),
            (
                """
                enum E {
                    case foo(x: Int = 0, y: Int = 1)
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'E'
                  `-NominalTypeBodyScope [1:8 - 3:1] 'E'
                    `-EnumElementScope [2:10 - 2:36] 'foo'
                      `-ParameterListScope [2:13 - 2:36]
                        |-DefaultArgumentInitializerScope [2:23 - 2:23]
                        `-DefaultArgumentInitializerScope [2:35 - 2:35]
                """
            ),
            (
                """
                @Wrapper
                func f() {}
                """,
                """
                SourceFileScope [1:1 - 2:11]
                `-AbstractFunctionDeclScope [1:1 - 2:11] 'f()'
                  |-CustomAttributeScope [1:1 - 1:8] 'Wrapper'
                  `-FunctionBodyScope [2:10 - 2:11]
                """
            ),
            (
                """
                let outer = 0
                @Wrapper(value: outer)
                func f() {}
                """,
                """
                SourceFileScope [1:1 - 3:11]
                `-TopLevelCodeScope [1:1 - 3:11] introduces=[identifier:outer]
                  |-PatternEntryDeclScope [1:5 - 1:13] entry 0
                  | `-PatternEntryInitializerScope [1:13 - 1:13] entry 0
                  `-AbstractFunctionDeclScope [2:1 - 3:11] 'f()'
                    |-CustomAttributeScope [2:1 - 2:22] 'Wrapper'
                    `-FunctionBodyScope [3:10 - 3:11]
                """
            ),
            (
                """
                @Wrapper(value: 1)
                @MainActor
                func f() {}
                """,
                """
                SourceFileScope [1:1 - 3:11]
                `-AbstractFunctionDeclScope [1:1 - 3:11] 'f()'
                  |-CustomAttributeScope [1:1 - 1:18] 'Wrapper'
                  |-CustomAttributeScope [2:1 - 2:10] 'MainActor'
                  `-FunctionBodyScope [3:10 - 3:11]
                """
            ),
            (
                """
                @available(*, deprecated)
                @inline(__always)
                func f() {}
                """,
                """
                SourceFileScope [1:1 - 3:11]
                `-AbstractFunctionDeclScope [1:1 - 3:11] 'f()'
                  `-FunctionBodyScope [3:10 - 3:11]
                """
            ),
            (
                """
                @MainActor
                struct S {}
                """,
                """
                SourceFileScope [1:1 - 2:11]
                `-NominalTypeDeclScope [1:1 - 2:11] 'S'
                  |-CustomAttributeScope [1:1 - 1:10] 'MainActor'
                  `-NominalTypeBodyScope [2:10 - 2:11] 'S'
                """
            ),
            (
                """
                @MyAttr
                typealias A = Int
                """,
                """
                SourceFileScope [1:1 - 2:17]
                `-TypeAliasDeclScope [1:1 - 2:17] 'A'
                  `-CustomAttributeScope [1:1 - 1:7] 'MyAttr'
                """
            ),
            (
                """
                @Wrapper(value: 1)
                var x = 0
                """,
                """
                SourceFileScope [1:1 - 2:9]
                `-TopLevelCodeScope [1:1 - 2:9] introduces=[identifier:x]
                  |-CustomAttributeScope [1:1 - 1:18] 'Wrapper'
                  `-PatternEntryDeclScope [2:5 - 2:9] entry 0
                    `-PatternEntryInitializerScope [2:9 - 2:9] entry 0
                """
            ),
            (
                """
                @Wrapper
                var a = 0, b = 1
                """,
                """
                SourceFileScope [1:1 - 2:16]
                `-TopLevelCodeScope [1:1 - 2:16] introduces=[identifier:b, identifier:a]
                  |-PatternEntryDeclScope [2:5 - 2:10] entry 0
                  | `-PatternEntryInitializerScope [2:9 - 2:9] entry 0
                  `-PatternEntryDeclScope [2:12 - 2:16] entry 1
                    `-PatternEntryInitializerScope [2:16 - 2:16] entry 1
                """
            ),
            (
                """
                @Wrapper
                extension X {}
                """,
                """
                SourceFileScope [1:1 - 2:14]
                |-CustomAttributeScope [1:1 - 1:8] 'Wrapper'
                `-ExtensionDeclScope [2:12 - 2:14] 'X'
                  `-ExtensionBodyScope [2:13 - 2:14] 'X' introduces=[implicit:Self]
                """
            ),
            (
                """
                struct S {
                    @MainActor
                    subscript(i: Int) -> Int { 0 }
                }
                """,
                """
                SourceFileScope [1:1 - 4:1]
                `-NominalTypeDeclScope [1:1 - 4:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 4:1] 'S'
                    `-SubscriptDeclScope [2:5 - 3:34] 'subscript(i:)' introduces=[identifier:i]
                      |-CustomAttributeScope [2:5 - 2:14] 'MainActor'
                      |-ParameterListScope [3:14 - 3:21]
                      `-AbstractFunctionDeclScope [3:30 - 3:34] 'get'
                        `-FunctionBodyScope [3:30 - 3:34] introduces=[implicit:self]
                          `-BraceStmtScope [3:30 - 3:34]
                """
            ),
            (
                """
                macro foo()
                """,
                """
                SourceFileScope [1:1 - 1:11]
                `-MacroDeclScope [1:1 - 1:11] 'foo()'
                """
            ),
            (
                """
                macro foo(value: Int)
                """,
                """
                SourceFileScope [1:1 - 1:21]
                `-MacroDeclScope [1:1 - 1:21] 'foo(value:)' introduces=[identifier:value]
                  `-ParameterListScope [1:10 - 1:21]
                """
            ),
            (
                """
                macro foo<T>(value: T) -> T
                """,
                """
                SourceFileScope [1:1 - 1:27]
                `-MacroDeclScope [1:1 - 1:27] 'foo(value:)' introduces=[identifier:value]
                  `-GenericParameterScope [1:12 - 1:27] 'T' introduces=[identifier:T]
                    `-ParameterListScope [1:13 - 1:22]
                """
            ),
            (
                """
                macro foo<T>(value: T) -> T = #externalMacro(module: "M", type: "F")
                """,
                """
                SourceFileScope [1:1 - 1:68]
                `-MacroDeclScope [1:1 - 1:68] 'foo(value:)' introduces=[identifier:value]
                  `-GenericParameterScope [1:12 - 1:68] 'T' introduces=[identifier:T]
                    |-ParameterListScope [1:13 - 1:22]
                    `-MacroDefinitionScope [1:31 - 1:68]
                """
            ),
            (
                """
                @AttachedMacro
                macro foo() = #externalMacro(module: "M", type: "F")
                """,
                """
                SourceFileScope [1:1 - 2:52]
                `-MacroDeclScope [1:1 - 2:52] 'foo()'
                  |-CustomAttributeScope [1:1 - 1:14] 'AttachedMacro'
                  `-MacroDefinitionScope [2:15 - 2:52]
                """
            ),
            (
                """
                struct S {
                    #expandMe()
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 3:1] 'S'
                    `-MacroExpansionDeclScope [2:5 - 2:15] 'expandMe'
                """
            ),
            (
                """
                struct S {
                    #expandMe(value: 1)
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 3:1] 'S'
                    `-MacroExpansionDeclScope [2:5 - 2:23] 'expandMe'
                """
            ),
            (
                """
                struct S {
                    #expandMe { x in x }
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 3:1] 'S'
                    `-MacroExpansionDeclScope [2:5 - 2:24] 'expandMe'
                      `-ClosureParametersScope [2:22 - 2:24] introduces=[identifier:x]
                        `-BraceStmtScope [2:22 - 2:24]
                """
            ),
            (
                """
                @attached(member, names: arbitrary)
                macro AddInit() = #externalMacro(module: "M", type: "F")
                """,
                """
                SourceFileScope [1:1 - 2:56]
                `-MacroDeclScope [1:1 - 2:56] 'AddInit()'
                  `-MacroDefinitionScope [2:19 - 2:56]
                """
            ),
            (
                """
                @Observable
                class C { var x = 0 }
                """,
                """
                SourceFileScope [1:1 - 2:21]
                `-NominalTypeDeclScope [1:1 - 2:21] 'C'
                  |-CustomAttributeScope [1:1 - 1:11] 'Observable'
                  `-NominalTypeBodyScope [2:9 - 2:21] 'C' introduces=[identifier:x]
                    `-PatternEntryDeclScope [2:15 - 2:19] entry 0
                      `-PatternEntryInitializerScope [2:19 - 2:19] entry 0
                """
            ),
            (
                """
                @AddCompletionHandler(name: "x")
                func f(value: Int) async -> Int { value }
                """,
                """
                SourceFileScope [1:1 - 2:41]
                `-AbstractFunctionDeclScope [1:1 - 2:41] 'f(value:)'
                  |-CustomAttributeScope [1:1 - 1:32] 'AddCompletionHandler'
                  |-ParameterListScope [2:7 - 2:18]
                  `-FunctionBodyScope [2:33 - 2:41] introduces=[identifier:value]
                    `-BraceStmtScope [2:33 - 2:41]
                """
            ),
            (
                """
                struct S {
                    #expandMe(value: 1) { x in x } extra: { y in y }
                }
                """,
                """
                SourceFileScope [1:1 - 3:1]
                `-NominalTypeDeclScope [1:1 - 3:1] 'S'
                  `-NominalTypeBodyScope [1:10 - 3:1] 'S'
                    `-MacroExpansionDeclScope [2:5 - 2:52] 'expandMe'
                      |-ClosureParametersScope [2:32 - 2:34] introduces=[identifier:x]
                      | `-BraceStmtScope [2:32 - 2:34]
                      `-ClosureParametersScope [2:50 - 2:52] introduces=[identifier:y]
                        `-BraceStmtScope [2:50 - 2:52]
                """
            ),
        ]
    }
}
