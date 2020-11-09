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
	- Two generations: yound(new) and old(tenured) generation. minor(nrusery) collection and majot(full) collection.
	- Multi generations.
	- Remembered set saves the inter-generational porinters.
- Parallel // TODO
- Concurrent // TODO
- Real-time // TODO

### Collectors in OpenJDK

#### Generatios
- young(new) generation
- old(tenured) generation
- permanent generation(metaspace after JDK8)

#### Collection types
- Minor collection(young generation collection)
- Full collection(major collection): collect young, old and permanent generations. But CMS don't collect young generation. And the permanent generation is not exist after JDK8.

#### Collectors
- serial collector: young and old collections are done serially, in a stop-the-world fashion.
	- Young generation: copying
	- Old generation: mark-sweep-compact. sliding. Actually it is a mark-compact algorithm.
	- Usage: default collector in client-class vm. Or use -XX:+UseSerialGC.

- Parallel(throughput) collector: stop-the-world.
	- Young generation: parallel copying.
	- Old generation: serial mark-sweep-compact before jdk8, parallel mark-compact after jdk8.
	- Usage: default collectors in server-class vm. Or use -XX:+UseParallelGC. Before JDK8, use -XX:+UseParallelOldGC to enable parallel mark-compat in old generation. But after JDK8, the parallel old collection is enabled when use -XX:UseParallelGC.

- Concurrent Mark-Sweep (CMS) collector
	- Young generation: parallel copying. ParNew.
	- Old generation: concurrent mark sweep. Init marking(STW), concurrent marking, remark(STW), concurrent sweep. It don't compact.
	- Usage: -XX:+UseConcMarKSweepGC

- G1
	- Data structure: 
		- heap regions
		- remember set(A logical Rset pre region. A set or hashtable of cards.): Store the location which point to this region. 
		- card table(heap 512byte:1byte card): 
		- remember set log
		- collection set
		- previous and next bitmap(64bit:1bit)
		- previous and next top at mark start(TAMS)
	- Init when create vm
		- init arguments
			- heap region size: limit size 1M-32M, suggested count 2048(GrainBytes, GrainWords, LogOfHRGrainBytes, LogOfHRGrainWords, CardsPerRegion, LogCardsPerRegion, G1HeapRegionSize)
			- rem set size(fine-grain, sparse)
			- alignment(SpaceAlignment, HeapAlignment)
			- heap size and alignment(max 3g, min 8m, init 186m)
		- initialize heap
			- create g1CollectedHeap
			- get heap start address and end address(ReservedSpace, memRegion)
			- create card table
	- Initial Marking(STW)
		- Clear the next marking bitmap.
		- STW and then mark all objects from the roots.
	- Concurrent Marking
	- Final Marking(remark)(STW)
		- Drain the mark stack
		- Complete log buffer
	- Cleanup
	- Evacuation

- Epsilon: no-op garbage collector

- shenandoah


- ZGC


### The more usage of collector
- // TODO

