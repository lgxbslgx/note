## contex-free grammer CFG
- Production. Each rule in a CFG is called a production.
- Nonterminal symbol. A syntactic variable used in a grammar’s productions.
- Terminal symbol. A word that can occur in a sentence.
- SN. Sentence notation.
- Parse tree or syntax tree. A graph that represents a derivation.
- CFG LR(1) LL(1) RE

- Scanner outputs a stream of word. Parser outputs a parse tree (syntax tree).
- *It is important to write the grammer.*

## top-down parsing  
- Eliminating Left Recursion. Indirect left recursion -> Direct left recursion. -> Right recursion.
- Expand the leftmost nonterminal to eliminate indirect left recursion.
- Rewrite grammer using intermedia nonterminal to tranform direct left recursion to right recursion.
- Left-factoring to eliminate backtracking.

### recursive-descent parser
- Apply to backtrack free grammer.
- Like tree pre-order traversal using recursion.

### Table-driven LL(1) parser
- Scan input from left to right, construct leftmost derivation, use a lookahead of 1 symbol.
- Apply to backtrack free grammer.
- Like tree pre-order traversal using a stack. 

## bottom-up parsing
### LR(1) parser
- Scan input from left to right, construct rightmost derivation, use a lookahead of 1 symbol.
- Tree post-order traversal using a stack.
- Table driven.

### BUilding LR(1) tables
- Don't read carefully.// TODO

