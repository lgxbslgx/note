## The directory of hotspot in jdk main line(now jdk16)

### The location
- jdk/src/hotspot

### structure
- Class Loader
- Runtime
- Execution Engine
	- Assembler
	- Interpreter
	- C1 Compiler
	- C2 Compiler
- GC
- Interface

### source code
- cpu  CPU related code. Assembler, template interpreter, compiler backend, some runtime methods, stub.
	- aarch64
	- arm
	- ppc
	- s390
	- x86
	- zero
- os  OS related code. Memory management, thread management, other OS related code.
	- aix
	- bsd
	- linux
	- posix
	- windows
- os_cpu  CPU and OS related code. Atomic operation, some memory and thread methods, others.
	- aix_ppc
	- bsd_x86
	- bsd_zero
	- linux_aarch64
	- linux_arm
	- linux_ppc
	- linux_s390
	- linux_x86
	- linux_zero
	- windows_aarch64
	- windows_x86
- share  Platform-independent code. 
	- adlc  Architecture description language compiler.(AD file compiler)
	- aot  Ahead of time code.
	- asm  Assembler interfaces.
	- c1  The client compiler. (c1 compiler)
	- ci  Compiler common service and the interfaces that compiler invokes vm. // TODO
	- classfile  Handle class file: class loader, system dicionary, symbol table.
	- code  Manage the compiled code.
	- compiler  The interfaces that vm invokes compiler.
	- gc  Garbage collection.
		- epsilon    Epsilon GC. // TODO
		- g1         Garbage First GC.
		- parallel   ParallelScevenge and PSOld GC.
		- serial     Serial and SerialOld GC.
		- shared     The shared code in garbage collection.
		- shenandoah Shenandoah GC. // TODO
		- z          ZGC  // TODO
	- interpreter  Interpreter: template interpreter and cpp interpreter. 
	- jfr  Java flight record.
	- jvmci  Jvm compiler interfaces. //TODO
	- libadt  Abstract data types.
	- logging  Log.
	- memory  Memory management.
	- metaprogramming  //TODO
	- oops  Object system.
	- opto  The server compiler(c2 compiler)
	- precompiled  //TODO
	- prims  VM Interfaces.(JNI, JVMTI)
	- runtime  Runtime library. (thread management, lock, reflect, safepoint, others)
	- services  JMX service.
	- utilities  Tools.


### structure vs source
- Common: libadt, utilities, logging
- Class Loader: prims(little), classfile
- Runtime: memory, oops, runtime
- Execution engine: adlc, ci, code, compiler, jvmci
	- Assembler: asm
	- Interpreter: interpreter
	- C1: c1
	- C2: opto
- GC: gc/
- Interfaces: prims, services
- other: aot, jfr, metaprogramming, precompiled

