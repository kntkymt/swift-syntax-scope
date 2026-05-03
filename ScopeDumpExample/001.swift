func process(value: Int) {
    let threshold = 10
    let doubled = value * 2

    if doubled > threshold {
        print(doubled)
    }
}

// SyntaxScope tree dump:
//
// SourceFileScope [1:1 - 23:0]
// `-AbstractFunctionDeclScope [1:1 - 8:1] 'process(value:)'
//   |-ParameterListScope [1:13 - 1:24]
//   `-FunctionBodyScope [1:26 - 8:1] introduces=[identifier:value]
//     `-BraceStmtScope [1:26 - 8:1]
//       `-PatternEntryDeclScope [2:9 - 8:1] entry 0 introduces=[identifier:threshold]
//         |-PatternEntryInitializerScope [2:21 - 2:22] entry 0
//         `-PatternEntryDeclScope [3:9 - 8:1] entry 0 introduces=[identifier:doubled]
//           |-PatternEntryInitializerScope [3:19 - 3:27] entry 0
//           `-IfExprScope [5:5 - 7:5]
//             `-BraceStmtScope [5:28 - 7:5]
