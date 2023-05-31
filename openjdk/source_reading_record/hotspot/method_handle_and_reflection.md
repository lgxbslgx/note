本文主要写`MethodHandle`、反射、`VarHandle`相关内容

## 方法handle`MethodHandle`

### 基础用法

```java
import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;

public class FinalMethod {
    static MethodHandle finalMethodHandle = getHandle(); // 非final
//    static final MethodHandle finalMethodHandle = getHandle(); // final

    static MethodHandle getHandle() {
        try {
            return MethodHandles.lookup().findStatic(FinalMethod.class, "testFinal",
                    MethodType.methodType(int.class, int.class, int.class));
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    static int testFinal(int a, int b) {
        return a + b;
    }

    public static int test(int i, int j) throws Throwable {
        return (int) finalMethodHandle.invokeExact(i, j);
    }

    public static void main(String[] args) throws Throwable {
        int sum = 0;
        for (int i = 0; i < 10_000_000; i++) {
            sum = test(sum, 99);
        }
        System.out.println(sum);
    }
}
```

### 字节码

只列出上文`test`方法的字节码:
```
  public static int test(int, int) throws java.lang.Throwable;
    descriptor: (II)I
    flags: (0x0009) ACC_PUBLIC, ACC_STATIC
    Code:
      stack=3, locals=2, args_size=2
         0: getstatic     #42                 // Field finalMethodHandle:Ljava/lang/invoke/MethodHandle;
         3: iload_0
         4: iload_1
         5: invokevirtual #46                 // Method java/lang/invoke/MethodHandle.invokeExact:(II)I
         8: ireturn
      LineNumberTable:
        line 24: 0
    Exceptions:
      throws java.lang.Throwable
```

主要起作用的字节码是: `5: invokevirtual #46 // Method java/lang/invoke/MethodHandle.invokeExact:(II)I`。

### hotspot实现

- 类加载阶段:
如果是调用`类java/lang/invoke/MethodHandle`或`java/lang/invoke/VarHandle`的签名多态方法（`被@PolymorphicSignature注解`），则重写字节码`_invokevirtual`和`invokestatic`为`_invokehandle`。代码在`Rewriter::scan_method -> Rewriter::rewrite_member_reference -> Rewriter::maybe_rewrite_invokehandle`。

- 解释器第一次调用``_invokehandle``时，解析`_invokehandle`的常量池条目，创建对应的类和方法。

调用链:
`TemplateTable::prepare_invoke` ->
`TemplateTable::load_invoke_cp_cache_entry` ->
`TemplateTable::resolve_cache_and_index` ->
`InterpreterRuntime::resolve_from_cache` ->
`InterpreterRuntime::resolve_invokehandle` ->
`LinkResolver::resolve_invoke` ->
`LinkResolver::resolve_invokehandle` ->
`LinkResolver::resolve_handle_call` ->
`LinkResolver::lookup_polymorphic_method` ->
`SystemDictionary::find_method_handle_invoker`

`SystemDictionary::find_method_handle_invoker`会先调用`SystemDictionary::find_method_handle_type`获取方法类型。`SystemDictionary::find_method_handle_type`先从缓存表`SystemDictionary::_invoke_method_type_table`里面找方法，找到则返回方法的类型，如果找不到，`SystemDictionary::find_method_handle_type`会调用Java方法`MethodHandleNatives.java:: findMethodHandleType`来创建方法类型（这个方法类型是实际要调用的方法的类型，不是invokeExact的方法类型）。

`SystemDictionary::find_method_handle_invoker`接着调用Java方法`MethodHandleNatives.java::linkMethod`进行创建若干类，比如`java.lang.invoke.LambdaForm$MH`，该类里面有方法`invokeExact_MT`，`invokeExact_MT`方法里面依次调用方法`Invokers.checkExactType、Invokers.checkCustomized、MethodHandle.invokeBasic`。`MethodHandleNatives.java::linkMethod`创建完类之后，返回`invokeExact_MT`方法的信息让虚拟机调用。所以一个的`invokehandle MethodHandle.invokeExact`字节码变成了下面的调用树（注意，这个调用树只是上文`5: invokevirtual #46 // Method java/lang/invoke/MethodHandle.invokeExact:(II)I`的情况，不是`invokeExact`的话，调用树会有一些区别，不过整体变化不大）：

```
  LambdaForm$MH::invokeExact_MT
    Invokers::checkExactType
      MethodHandle::type
      Invokers::newWrongMethodTypeException
    Invokers::checkCustomized
      MethodHandleImpl::isCompileConstant
      Invokers::maybeCustomize
    MethodHandle::invokeBasic
      LambdaForm$DMH::invokeStatic
        DirectMethodHandle::internalMemberName
        MethodHandle::linkToStatic
          FinalMethod::testFinal // 我们真正要运行的方法
```

运行多次之后，一些调用会被删除
```
test方法
  LambdaForm$MH::invokeExact_MT
    Invokers::checkExactType
      MethodHandle::type
      // Invokers::newWrongMethodTypeException已被删除
    Invokers::checkCustomized
      MethodHandleImpl::isCompileConstant
      // Invokers::maybeCustomize 已被删除
    MethodHandle::invokeBasic
      LambdaForm$DMH::invokeStatic
        DirectMethodHandle::internalMemberName
        MethodHandle::linkToStatic
          FinalMethod::testFinal // 我们真正要运行的方法
```


解释器就像调用正常java代码一样调用这些代码，C1、C2编译器也会像编译正常java代码一样编译这些方法。

一些用于调试的参数`-XX:+UnlockDiagnosticVMOptions -Djava.lang.invoke.MethodHandle.DUMP_CLASS_FILES=true -XX:+ShowHiddenFrames`。

参考链接:
https://www.zhihu.com/question/535373016/answer/2517526289
https://iklam.github.io/jekyll/update/2017/12/15/lambda-notes-001.html
https://iklam.github.io/jekyll/update/2017/12/19/lambda-notes-002-method-handle.html
https://wiki.openjdk.org/display/HotSpot/Method+handles+and+invokedynamic
https://wiki.openjdk.org/display/HotSpot/Bound+method+handles
https://wiki.openjdk.org/display/HotSpot/Direct+method+handles
https://wiki.openjdk.org/display/HotSpot/Method+handle+invocation
https://wiki.openjdk.org/display/HotSpot/Deconstructing+MethodHandles


## 反射`Reflection`

### 基础用法

```java
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;

public class ReflectionTest {
    public int testAdd(int a, int b) {
        return a + b;
    }

    public static void main(String[] args) {
        try {
            Method method = ReflectionTest.class.getMethod("testAdd", int.class, int.class);
            int res = (int) method.invoke(new ReflectionTest(), 2, 3);
            System.out.println(res);
        } catch (NoSuchMethodException | InvocationTargetException | IllegalAccessException e) {
            e.printStackTrace();
        }
    }
}
```

### 字节码

```
  public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: (0x0009) ACC_PUBLIC, ACC_STATIC
    Code:
      stack=6, locals=3, args_size=1
         0: ldc           #7                  // class ReflectionTest
         2: ldc           #9                  // String testAdd
         4: iconst_2
         5: anewarray     #11                 // class java/lang/Class
         8: dup
         9: iconst_0
        10: getstatic     #13                 // Field java/lang/Integer.TYPE:Ljava/lang/Class;
        13: aastore
        14: dup
        15: iconst_1
        16: getstatic     #13                 // Field java/lang/Integer.TYPE:Ljava/lang/Class;
        19: aastore
        20: invokevirtual #19                 // Method java/lang/Class.getMethod:(Ljava/lang/String;[Ljava/lang/Class;)Ljava/lang/reflect/Method;
        23: astore_1
        24: aload_1
        25: new           #7                  // class ReflectionTest
        28: dup
        29: invokespecial #23                 // Method "<init>":()V
        32: iconst_2
        33: anewarray     #2                  // class java/lang/Object
        36: dup
        37: iconst_0
        38: iconst_2
        39: invokestatic  #24                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
        42: aastore
        43: dup
        44: iconst_1
        45: iconst_3
        46: invokestatic  #24                 // Method java/lang/Integer.valueOf:(I)Ljava/lang/Integer;
        49: aastore
        50: invokevirtual #28                 // Method java/lang/reflect/Method.invoke:(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;
        53: checkcast     #14                 // class java/lang/Integer
        56: invokevirtual #34                 // Method java/lang/Integer.intValue:()I
        59: istore_2
        60: getstatic     #38                 // Field java/lang/System.out:Ljava/io/PrintStream;
        63: iload_2
        64: invokevirtual #44                 // Method java/io/PrintStream.println:(I)V
        67: goto          75
        70: astore_1
        71: aload_1
        72: invokevirtual #56                 // Method java/lang/ReflectiveOperationException.printStackTrace:()V
        75: return
```

主要起作用的字节码是: `invokevirtual #28  // Method java/lang/reflect/Method.invoke:(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;`

### hotspot实现

hotspot调用`invokevirtual`字节码来运行方法`Method.invoke`，`invokevirtual`相关内容在文档`interpreter.md`中。

`Method`类里面有一个字段`MethodAccessor methodAccessor`，`Method.invode`会调用`MethodAccessor.invoke`（实际上是调用实现类`DirectMethodHandleAccessor.invoke`）用于实际的调用操作。`DirectMethodHandleAccessor`里面有`MethodHandle target`，`DirectMethodHandleAccessor.invoke`则调用`MethodHandle.invokeExact`来实现具体操作。我们可以看到，反射调用方法的时候使用了方法handle。

整体调用树如下：
```
Method.invoke
  DirectMethodHandleAccessor.invoke
    DirectMethodHandleAccessor.invokeImpl
      MethodHandle.invokeExact // 这里的详细操作和上文`MethodHandle`相关内容一样
```

所以，如果只是简单得调用方法，则使用`MethodHandle`就行了，这样性能会好一点。特别地，如果新建的`MethodHandle`对象是`常量`的并且重复多次调用同一个方法，则使用`MehodHandle`性能很好。如果要获取方法的其他信息，则用反射才行。

## 字段handle`VarHandle`

### 基础用法

```java
import java.lang.invoke.MethodHandles;
import java.lang.invoke.VarHandle;

public class VarHandleTest {
    public int val;

    public VarHandleTest(int val) {
        this.val = val;
    }

    public static VarHandle valHandle = getHandle();

    static VarHandle getHandle() {
        try {
            return MethodHandles.lookup().findVarHandle(VarHandleTest.class, "val", int.class);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    public static void main(String[] args) {
        int testVal = (int) valHandle.getAcquire(new VarHandleTest(11));
        System.out.println(testVal); // Expected output: 11
    }
}

```

### 字节码

```
  public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: (0x0009) ACC_PUBLIC, ACC_STATIC
    Code:
      stack=4, locals=2, args_size=1
         0: getstatic     #37                 // Field valHandle:Ljava/lang/invoke/VarHandle;
         3: new           #8                  // class VarHandleTest
         6: dup
         7: bipush        11
         9: invokespecial #41                 // Method "<init>":(I)V
        12: invokevirtual #44                 // Method java/lang/invoke/VarHandle.getAcquire:(LVarHandleTest;)I
        15: istore_1
        16: getstatic     #50                 // Field java/lang/System.out:Ljava/io/PrintStream;
        19: iload_1
        20: invokevirtual #56                 // Method java/io/PrintStream.println:(I)V
        23: return
```

主要起作用的字节码是: `12: invokevirtual #44  // Method java/lang/invoke/VarHandle.getAcquire:(LVarHandleTest;)I`

### hotspot实现

这里的实现和`MethodHandle`类似，`12: invokevirtual`应该也会改写成`invokehandle`，先不展开看了。

