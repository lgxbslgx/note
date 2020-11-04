## The Garbage Collection

### reachable analysis


### garbage collection algorithms
- Mark-sweep. 
	- Mark is a procedure that traverses object graph(depth-first or width-first) and sets the marked bit. Sweep traverses object list linearly to free unreachable objects and unset the marked bit.
	- Tricolor. Black, grey, white.
	- Bitmap marking. Pre-block or single or hybrid. // TODO
	- Lazy sweeping. Use a reclaimList to reuse blocks instead of sweeping immediately.
	- Use cache in marking. Use a FIFO queue.

- Mark-compact. 
	- Mark and compact.
	- Rearrange objects: arbitrary, linearising, sliding. Sliding is best.
	- Two-finger. Two pass and arbitrary order. Fixed size objects. Simple and fast.
		- Relocate. Set free pointer to the first gap. Set scan pointer to the last live object. Set a threshold. Move the live object of scan pointer to free pointer and set new address.
		- Update references. The references of roots and live objects.
	- Lisp 2 algorithm. Three pass and sliding order.
		- Compute the new location and store in object header. Scan and free pointer.
		- Update references of roots and live objects.
		- Move live objects.
	- Threaded compaction.
		- Update forward references. Threading the roots, unthreading roots, threading all objects.
		- Update backward references. Unthreading all objects.
	- One-pass algorithm.

- Copying. 
- Reference counting. 


### Collectors in OpenJDK


### The usage of collector


