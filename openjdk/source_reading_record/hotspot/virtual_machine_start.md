## virtual machine start

### related file list
- java.base module: launcher dir, libjli dir
- hotspot: jni, thread, 


### procedure
thread-1 java
- parse parameters, check, get path
- LoadVM : load the libjvm.so, initialize ifn
- call JavaMain in new thread
- wait thread-2

thread-2
- InitializeJVM
	- use ifn->CreateJavaVM (JNI_CreateJavaVM in libjvm.so) to create vm. Init JavaVM(vm) and JNIEnv(env).
	- Threads::create_vm // too many things
		- init_globals: create thread 3-7(GC Thread#0, G1 main marker, G1 conc#0, G1 refine#0, G1 service)
		- os::create_thread: create thread 8(VM Thread)
		- initialize_java_lang_classes: create thread 9, 10(Refefrence Handl, Finalizer)
		- os::initialize_jdk_signal_support: create thread 11(Signal dispatch)
		- ServiceThread::initialize: create thread 12(Service thread)
		- CompileBroker::compilation_init_phase1: create thread 13-15(C2 compilerThre, C1 compilerThre, sweeper thread)
		- MemProfiler::engage: create thread 16(Notification th)
		- PeriodicTask::num_tasks: create thread 17(VM Periodic Tas)
	- set Javavm(vm) and JNIEnv(env)

- LoadMainClass
- get main method and call main method


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

