## intermediate representations(IR)
- taxonomy: structural organization, level of abstraction, naming discipline
- structural: Graphical, linear, hybrid.
- abstraction: high level near-source, low level near target-machine.
- naming: the choice of a naming scheme.

### concrete IR
- Graphical IR: based on trees and graphs.
- Linear IR: resemble assembly code or pseudo code.
- Hybrid IR: combine graphical ir and linear ir.
- SSA(static single-assignment) form.
- Symbol tables.

### Graphical IR
- Syntax-related trees
	- parse trees
	- abstract syntax trees(AST): source-level, low-level

- Graphs
	- Directed acyclic graph(DAG): reduce memory, expose redundancies
	- Control-flow graph(CFG): A CFG has a node for every basic block and an edge for each possible control transfer between blocks. Usage: optimization analysis, instruction scheduling, global register allocation.
	- Data Dependence Graph: a graph that models the flow of values from definitions to uses in a code fragment. Usage: instruction scheduling.
	- Call Graph: a graph that represents the calling relationships among the procedures in a program.

### Linear IR
- One-address code
- Two-address code
- Three-address code

- stack-machine code(one-address code)
	- Java and smalltalk80 use byte code

- Three-address code
	- Android dalvik and LLVM.
	- representation: simple array, pointer array, linked list

### Naming
- Naming temporary values.
- SSA(static single-assignment) form.
- Memory models.
	- register to register
	- memory to memory

### Symbol tables
- Hash table: constant-time lookup
- Multiset discrimination
- Scoped symbol table: Handling Nested Scopes. Link many table in a list.
