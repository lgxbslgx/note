## The Garbage Collection

### Common garbage collection algorithms
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
	- Threaded compaction. Two pass and sliding. Don't need additional space.
		- Update forward references. Threading the roots, unthreading forward references, threading all objects.
		- Update backward references. Unthreading backward references, move objects.
		- the method I think: 1.threading roots and all the objects. 2.unthreading all the objects and move objects.
	- One-pass algorithm. Use bitmap and offset vector.
		- Compute Locations. Get the offset vector. Don't need to traverse all the objects. It uses the bitmap which is created in marking stage.
		- Update references.

- Copying. Semispaces. Fast Allocation and elimination of fragmentation. One pass and don't need additional spaces. Need twice spaces.
	- According to roots and  worklist, copy objects to another semispaces. Use free and scan pointer.

- Reference counting. 
	- Add reference count when a object reference another object. And delete reference count when a object no longer reference another object. If the count of a object becomes zero, the object will be freed.
	- Deferral reference counting. Use zero count table.
	- Coalescing reference counting. Log the dirty object at the first time. // TODO
	- Buffering reference counting. // TODO
	- Cyclic reference counting.
		- Use tracing collection.
		- Trial deletion. Mark candidates(grey), scan(black, white), collect candidates(white). // TODO

### Comparing garbage collector
- Time
	- Throughput
	- Pause time
	- Frequency of collection
	- Promptness
- Space
	- Additional Space
	- Footprint

### Advanced topics
- Allocate memory.
	- Sequential allocation. Free-list Allocation(first-fit, next-fit, best-fit). Use balanced binary tree or bitmap to speed. Use segregated-fit(multi list) to speed. 
- Partitioning and generational. 
	- Two generations: yound(new) and old(tenured) generation. minor(nrusery) collection and major(full) collection.
	- Multi generations.
	- Remembered set saves the inter-generational porinters.
- Parallel // TODO
- Concurrent // TODO
- Real-time // TODO
