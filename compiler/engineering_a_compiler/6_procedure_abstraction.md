## procedure abstraction

### procedure call
- Caller callee
- Implementation: stack, register
- Call return
- Call graph
- Closure: procedure and runtime context

### name space
- Scope: lexical scope, dynamic scope
- Activation record(AR): is like the *frame* in jvm.
- activation record pointer (arp)
- AR Implementation: stack, heap, static allocation, coalesce(combine) AR
- just-in-time compilers
- Object-Oriented Languages
- Object record(OR)

### parameter binding
- The way to pass parameters: call by value, call-by-value-result, call by reference.
- Static Base Addresses(label), Dynamic Base Addresses(AR).
- Access Links(use linked list), grobal display(pointer array).


### linkage convention
- Linkage convention: an agreement between the compiler and operating system that defines the actions taken to call a procedure or function.
- Precall Sequence, Postreturn Sequence, Prologue Sequence, Epilogue Sequence.
- Caller-saves registers, Callee-saves registers.


### heap management(allocate and free)
- explicit management of the heap: first-fit, multipool
- implicit management, avoid the need of *free*: garbage collection
	- incremental gc: reference counting. immediate, real-time
	- batch-oriented gc: mark-sweep collection and copying collection. delayed
		- marking(precise, conservative): adds each unmarked object to the free list.
		- mark-sweep or coping or generational collectors: an old pool and a new pool.
