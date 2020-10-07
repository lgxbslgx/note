## Scanner. Lexical analysis.

## FA Finite Automata
- Finite states set.
- Finite chars set.
- Transition function.
- One start state.
- Accepting states set.

## RE Regular Expression
- a : char a
- a | b : char a or char b
- ab : string ab
- a* : zero or more char a
- a+ : one or morer cha a
- [1...4] : one char of 1-4, equal to (1|2|3|4)
- ^a : complement, char set except a
- precedence : 
	(), ^ , * + , ab, |

## DFA NFA
- DFA : Deterministic Finite Automata
- NFA : Nondeterministicc Finite Automata

## The steps form RE to scanner
- Thompson's Construction. RE --> NFA
- Subset construction. NFA --> DFA
- Hopcroft's algorithm. Minimize a DFA
- Implement a scanner using minimal DFA. DFA --> scanner. Scan input string, and return the token and category.


### Thompson's Construction. RE --> NFA
- single-letter : a
- concatenation : ab
- alterrrnation : a|b
- closure : a*


### Subset construction. NFA --> DFA
- Like the breath first search using a queue.
- Find all the valid configuration and the relationship of them.
- An example of a fixed-point computations.

- Source NFA : {N, C, f, n0, NA}. Target DFA : {D, C, f, d0, DA}.
- Init. Let the zero valid configuration q0 = closure{n0}.
- Put q0 into Q and queue.
- Search qi in queue, with all the char in C, to find other valid configuration q.
- If the result q in previous step is not in Q, put it into Q and queue and set T[qi, c] = q
- Use Q, T to construct D.

### Hopcroft's algorithm. Minimize a DFA
- Find equivalence states.
- Init set partition : {DA, {D - DA}}.
- Get litter set partition gradually.


### The implementation of scanner
- Generated Table-driven Scanner. Use the state transition diagram.
- Generated Direct-coded Scanner. Use code instead of state transition diagram to reduce memory access.
- Hand-coded scanner. Use code to reduce the overhead of the interfaces between the scanner and the rest of the system.


## Kleene's Constrruction. DFA --> RE
- Can't Understand.
