## compiler
Translate software written in one language into another language.

## Algorithm Overview
- greedy algorithms (register allocation)
- heuristic search techniques(list scheduling)
- graph algorithms (dead-code elimination)
- dynamic programming (instruction selection)
- finite automata and push-down automata(scanning and parsing)
- fixed-point algorithms (data-flow analysis)

## Fundamental Principles
- The compiler must preserve the meaning of the program being compiled
- The compiler must improve the input program in some discernible way

## Compiler Structure
- Front End
	- Scanner. Lexical analysis. A stream of characters --> A stream of classified words.
	- Parser. Systactic analysis.  Words --> Sentences.
	- Elaboration. Semantic analysis. 
	- Intermediate Representation Generation. --> Intermediate representation
- Middle Section. Optimizer.
	- Analysis. Data flow Analysis, dependencies analysis, 
	- Transformation.
- Back End
	- Inst Selection
	- Inst Scheduling
	- Reg Allocation

