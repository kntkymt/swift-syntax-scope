struct Box<T> where T: Equatable {
    let value: T

    func unwrap(or fallback: T?) -> T {
        guard let resolved = fallback else {
            return value
        }
        return resolved
    }
}

extension Box where T: Comparable {
    func max(_ other: Box<T>) -> T {
        if value > other.value {
            return value
        } else {
            return other.value
        }
    }
}

// SyntaxScope tree dump:
//
// SourceFileScope [1:1 - 49:0]
// |-NominalTypeDeclScope [1:1 - 10:1] 'Box'
// | `-GenericParameterScope [1:13 - 10:1] 'T' introduces=[identifier:T]
// |   |-NominalTypeWhereScope [1:15 - 1:32] 'Box'
// |   `-NominalTypeBodyScope [1:34 - 10:1] 'Box' introduces=[declaration:unwrap, identifier:value]
// |     |-PatternEntryDeclScope [2:9 - 2:16] entry 0
// |     `-AbstractFunctionDeclScope [4:5 - 9:5] 'unwrap(or:)'
// |       |-ParameterListScope [4:16 - 4:32]
// |       `-FunctionBodyScope [4:39 - 9:5] introduces=[identifier:fallback, implicit:self]
// |         `-BraceStmtScope [4:39 - 9:5]
// |           `-GuardStmtScope [5:9 - 9:5]
// |             `-ConditionalClausePatternUseScope [5:15 - 9:5] introduces=[identifier:resolved]
// |               |-ConditionalClauseInitializerScope [5:28 - 5:37]
// |               `-GuardStmtBodyScope [5:44 - 7:9]
// |                 `-BraceStmtScope [5:44 - 7:9]
// `-ExtensionDeclScope [12:14 - 20:1] 'Box'
//   |-ExtensionWhereScope [12:15 - 12:33] 'Box'
//   `-ExtensionBodyScope [12:35 - 20:1] 'Box' introduces=[implicit:Self, declaration:max]
//     `-AbstractFunctionDeclScope [13:5 - 19:5] 'max(_:)'
//       |-ParameterListScope [13:13 - 13:29]
//       `-FunctionBodyScope [13:36 - 19:5] introduces=[identifier:other, implicit:self]
//         `-BraceStmtScope [13:36 - 19:5]
//           `-IfExprScope [14:9 - 18:9]
//             |-BraceStmtScope [14:32 - 16:9]
//             `-BraceStmtScope [16:16 - 18:9]
