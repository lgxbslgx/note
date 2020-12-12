## Introduction to optimization

### Considerations
- Safety
- Profitability and performance

### Scope of optimization(granularity)
- Local(a basic block)
- Regional(multiple block, extended basic block EBB)
- Global(intraprocedural, a full procedure)
- Interprocedura(whole-program, universal)

#### Local optimization
- Local value numbering(LVN): find and eliminate redundancies.
	- hash table: key->hashcode of operand and operator, value->number and indentifiers(names).
	- Initially, the hashtable is empty. Later, add or update entry in hashtable according to the operands and oprators. It is no deletion.
	- extend: Commutative operations. Use value number to order operands.
	- extend: Constant folding.
	- extend: Algebraic identities.
	- extend: static single-assignment form.

- Tree-height balancing
	- Find candidate tree. commutative, associative, used more than once. create a priority queue of operator precedence.
	- Create balanced tree.
		- Flatten the tree, create a priority queue of operand rank.
		- Rebuild the tree, create a balanced tree.

#### Region Optimization
- Superlocal Value Numbering
	- 

- Loop Unrolling

#### Gobal Optimization

#### Interprocedural Optimization


