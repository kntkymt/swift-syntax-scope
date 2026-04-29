@MainActor
func run(values: [Int]) {
    for n in values where n > 0 {
        let mapped = values.map { x in x + n }
        print(mapped)
    }

    do {
        try work()
    } catch let error where check(error) {
        switch error {
        case .a(let info) where info > 0:
            print(info)
        case let .b(value):
            print(value)
        }
    }
}

// SyntaxScope tree dump:
//
// SourceFileScope [1:1 - 49:56]
// `-AbstractFunctionDeclScope [1:1 - 18:1] 'run(values:)'
//   |-CustomAttributeScope [1:1 - 1:10] 'MainActor'
//   |-ParameterListScope [2:9 - 2:23]
//   `-FunctionBodyScope [2:25 - 18:1] introduces=[identifier:values]
//     `-BraceStmtScope [2:25 - 18:1]
//       |-ForEachStmtScope [3:5 - 6:5]
//       | `-ForEachPatternScope [3:21 - 6:5] introduces=[identifier:n]
//       |   `-BraceStmtScope [3:33 - 6:5]
//       |     `-PatternEntryDeclScope [4:13 - 4:46] entry 0 introduces=[identifier:mapped]
//       |       `-PatternEntryInitializerScope [4:22 - 4:46] entry 0
//       |         `-ClosureParametersScope [4:40 - 4:46] introduces=[identifier:x]
//       |           `-BraceStmtScope [4:40 - 4:46]
//       `-DoStmtScope [8:5 - 17:5]
//         |-BraceStmtScope [8:8 - 10:5]
//         | `-TryScope [9:9 - 9:18]
//         `-CaseStmtScope [10:7 - 17:5]
//           |-CaseLabelItemScope [10:29 - 10:40] introduces=[identifier:error]
//           `-CaseStmtBodyScope [10:42 - 17:5] introduces=[identifier:error]
//             `-BraceStmtScope [10:42 - 17:5]
//               `-SwitchExprScope [11:9 - 16:9]
//                 |-CaseStmtScope [12:9 - 13:23]
//                 | |-CaseLabelItemScope [12:33 - 12:40] introduces=[identifier:info]
//                 | `-CaseStmtBodyScope [13:13 - 13:23] introduces=[identifier:info]
//                 |   `-BraceStmtScope [13:13 - 13:23]
//                 `-CaseStmtScope [14:9 - 15:24]
//                   `-CaseStmtBodyScope [15:13 - 15:24] introduces=[identifier:value]
//                     `-BraceStmtScope [15:13 - 15:24]
