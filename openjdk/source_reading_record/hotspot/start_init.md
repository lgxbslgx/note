## virtual machine start and init

### related file list
- java.base module: share/native/launcher and libjli
- hotspot: share/prims/jni, share/runtime/thread


### start procedure
thread-1 java
- parse parameters, check, get path
- LoadVM : load the libjvm.so, initialize ifn
- call JavaMain and create the vm in new thread
- wait thread-2

thread-2
- InitializeJVM(See vm init)
	- use ifn->CreateJavaVM (JNI_CreateJavaVM in libjvm.so) to create vm. Init JavaVM(vm) and JNIEnv(env).
- LoadMainClass
- get main method and call main methodi(`(*env)->GetStaticMethodID()`, `(*env)->CallStaticVoidMethod()`)


### vm init (JNI_CreateJavaVM)
- Check: ensure that no two threads call this method at the same time and check version.
- Init	// Threads::create_vm do too many things
	- Init thread local storage. ThreadLocalStorage::init(): init thread key. // pthread_key_create
	- Init the output stream module. // tty = defaultStream::instance
	- Init os module. clock, random, page size, processor number, memory size, ticks(don't known), thread id, pax, posix.
	- Init system properties and arguments. A linked list(Node: key-value).
	- Init os module again after parsing arguments. posix, clock, signal, stack, thread, cpu, number of file descriptors. //unknown
	- Init safepoint. // unknown
	- Init output stream logger.
	- Init agent.
	- Init global data. ThreadShadow, basic_type, eventlog, mutex lock, oopsstorage, chunk pool, perf memory, synchronization. // vm_init_globals
	- Create java main thread, attach to current OS thread.
	- init_globals: create thread 3-7(GC Thread#0, G1 main marker, G1 conc#0, G1 refine#0, G1 service)
		- init management: management, thread service, runtime servicce, class loading service.
		- init jvmti oop storage.
		- init bytecodes.
		- init class loader1, load java library.
		- init compilation policy.
		- init code cache.
		- init vm version.
		- init stubRoutine.
		- init universe. global, GCLogPreccious, heap, tlab, metaspace, AOTLoader, other.
		- init barrier.
		- init interpreter stub.
		- more //TODO
	- Threads::add // add main thread
	- os::create_thread: create thread 8(VM Thread)
	- initialize_java_lang_classes: create thread 9, 10(Refefrence Handl, Finalizer)
	- os::initialize_jdk_signal_support: create thread 11(Signal dispatch)
	- ServiceThread::initialize: create thread 12(Service thread)
	- CompileBroker::compilation_init_phase1: create thread 13-15(C2 compilerThre, C1 compilerThre, sweeper thread)
	- MemProfiler::engage: create thread 16(Notification th)
	- PeriodicTask::num_tasks: create thread 17(VM Periodic Tas)
- set Javavm(vm) and JNIEnv(env)


### VM interfaces
- env: A pointer of JNIEnv. Have many mehods. In c, use `(*env)->someFunction()` to call functions in jvm.
```
#ifdef __cplusplus
typedef JNIEnv_ JNIEnv;
#else
typedef const struct JNINativeInterface_ *JNIEnv;
#endif
```

- vm: A pointer of JavaVM. Have little methods. In c, use `(*vm)->someFunctionJ()` to call functions in jvm.
```
#ifdef __cplusplus
typedef JavaVM_ JavaVM;
#else
typedef const struct JNIInvokeInterface_ *JavaVM;
#endif
```

- The method in `jvm.h` and `jvm.cpp`. The native methods in standard library use these methods directly.
```
result = JVM_FindPrimitiveClass(env, utfName);
```

