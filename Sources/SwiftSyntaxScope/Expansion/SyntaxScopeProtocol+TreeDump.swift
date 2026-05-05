extension SyntaxScopeProtocol {
    public func buildFullyExpandedTree() {
        if !isExpanded {
            expandAndBeCurrent()
        }

        forEachChildren { scope in
            if !scope.isExpanded {
                scope.expandAndBeCurrent()
            }
        }
    }

    public func forEachChildren(action: (any SyntaxScopeProtocol) -> Void) {
        children.forEach { child in
            action(child)
            child.forEachChildren(action: action)
        }
    }

    public func dump() -> String {
        dumpTree(prefix: "", isLastChild: true, isRoot: true)
    }

    private func dumpTree(prefix: String, isLastChild: Bool, isRoot: Bool) -> String {
        let marker = isRoot ? "" : (isLastChild ? "`-" : "|-")
        let names = introducedLocalLookupNames + introducedMemberLookupNames
        let suffix =
            names.isEmpty
            ? ""
            : " introduces=[\(names.map(\.dumpDescription).joined(separator: ", "))]"
        let line = prefix + marker + description + suffix
        let childPrefix = prefix + (isRoot ? "" : (isLastChild ? "  " : "| "))

        let childLines = children.enumerated().map { index, child in
            child.dumpTree(
                prefix: childPrefix,
                isLastChild: index == children.count - 1,
                isRoot: false
            )
        }

        return ([line] + childLines).joined(separator: "\n")
    }
}
