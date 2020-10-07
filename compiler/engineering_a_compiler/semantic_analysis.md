## Semantic analysis. Context-sensitive checking.
- Type system.
- Attribute grammar.
- Ad hoc syntax-directed translation.

### overview
- What kind of value is stored in x?  Data type.
- Howw big is x? Data length.
- If x is a procedure, what arguments does it take? What kind of value, if any, does it return? Data transmission.
- How long must x’s value be preserved? Data lifetime.
- Who is responsible for allocating space for x (and initializing it)? Data allocation and destroy.

### Type system
- The set of types and the rules that use types to specify program behavior.
- Purpose: safety, expressiveness, and runtime efficiency.

- *type safety*
- Strongly typed language. every expression have an unambigious type, 如果不经过自主强制转换，类型永远不会变. eg: Java, python
- Untyped. eg: assembly, BCPL
- weakly typed. eg: javascript, php, c
- Statically typed, eg: java, c
- dynamically typed, eg: python

- *improving expressiveness*
- Operator overload.

- *generating better code*
- The type are determined at compile time can reduce runtime cost.

- *type checking*
- Type inference and identifying type-related errors.
- Base types (built-in types), rules constructing new types, a method for determining if two types are equivalent or compatible, rules for inferring the type of each expression.
- Type: numbers, characters, booleans, compound and constructed types, arrays, strings, enumerated types, structures(record) and variants, union, pointers
- Type equivalence: name equivalence, structural equivalence
- Inference rules: Declarations(variable, constant), expression, function(type signature, function prototype)
- Statically typed and statically checked. Dynamically typed and dynamically checked.

### Attribute grammar framework
- Attribute: a value attached to one or more of the nodes in a parse tree.
- Attribute context-free grammar: a set of productions and a set of attribute rules.
- A production has one or more attribute rules. A node(symbol)(terminal or nonterminal) has one or more attributes.
- Evaluation methods: dynamic methods(topologically sort the attribute dependence graph), oblivious methods(repeated), Rule-Based Methods(static analysis offline).

### Ad hoc syntax-directed translation
- Action. Snippets of code.
- Two simplifications.
	- Values flow in only one direction, from leaves to root.
	- One single value per grammar symbol.
- Generate an AST(abstract syntax tree).

