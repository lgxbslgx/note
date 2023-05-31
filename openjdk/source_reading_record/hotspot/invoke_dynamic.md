本文主要写`invoke_dynamic`相关内容

## hotspot实现

hotspot遇到`invoke_dynamic`时，根据常量池index获取对应的`bootstrap方法`，调用`bootstrap方法`动态生成对应的方法，返回一个方法（`CallSite`），之后的相同调用（什么时候是相同调用由编译器决定，下文有详细内容）都使用这个动态生成的方法，无需再次生成。

调用`bootstrap方法`方法时，使用的**参数**在`属性BootstrapMethods`中。
```
BootstrapMethods_attribute {
    u2 attribute_name_index;
    u4 attribute_length;
    u2 num_bootstrap_methods;
    {
        u2 bootstrap_method_ref;
        u2 num_bootstrap_arguments;
        u2 bootstrap_arguments[num_bootstrap_arguments]; // 参数在这里
    } bootstrap_methods[num_bootstrap_methods];
}
```

调用这个动态生成的方法时，使用的**参数**在栈上，**调用`invoke_dynamic`前要把参数先放到栈上（这一步由编译器完成的）**。

调用哪个`bootstrap方法`方法由编译器决定，也就是`invoke_dynamic`后面的`常量池index、属性BootstrapMethods index`由编译器决定。如果编译器认为2个`invoke_dynamic`是一样的，则可以使用同一个`bootstrap方法`，这时候的这2个`invoke_dynamic`就对应一个`index`，所以只需要调用一次。**可以理解成`属性BootstrapMethods`里面的每个`bootstrap方法`都只需调用一次**。


## 使用字节码`invoke_dynamic`的地方
- lambda表达式
  - 对应的`bootstrap方法`为`java.base/java.lang.invoke.LambdaMetafactory.metafactory`
  - 每个lambda表达式都不一样，所以每个lambda表达式都会对应一个新的`bootstrap方法`
  - 相关操作在javac的`jdk.compiler/com/sun/tools/javac/comp/LambdaToMethod.class::visitLambda和visitReference`
- 字符串常量连接
  - 对应的`bootstrap方法`为`java.base/java.lang.invoke.StringConcatFactory.makeConcatWithConstants和makeConcat`
  - 一般连接是2个`String`对象连接，所以`bootstrap方法`一样。有时候也有1个`String`和一个字符串常量连接，这时候会有一个新的`bootstrap方法`。总的来说，就是看操作数类型确定`bootstrap方法`。
  - 相关操作在javac的`jdk.compiler/com/sun/tools/javac/jvm/StringConcat.class`
- switch模式匹配
  - 对应的`bootstrap方法`为`java.base/java.lang.runtime.SwitchBootstraps.enumSwitch和typeSwitch`
  - 相关操作在javac的`jdk.compiler/com/sun/tools/javac/comp/TransPatterns.class`
- 记录类record
  - 对应的`bootstrap方法`为`java.base/java.lang.runtime.ObjectMethods.bootstrap`
  - 相关操作在javac的`jdk.compiler/com/sun/tools/javac/comp/Lower.class::generateRecordMethod`


### lambda表达式的例子

- lambda表达式使用:

```java
import java.util.function.Function;

public class LambdaTest {
    public static void main(String[] args) {
        String ss = "ss";
        int cap = 11;
        Function<String, String> f = (a) -> a + cap;
        String str = f.apply(ss);
        System.out.println(str);
    }
}
```

- javac生成的字节码:
```
  public static void main(java.lang.String[]);
    descriptor: ([Ljava/lang/String;)V
    flags: (0x0009) ACC_PUBLIC, ACC_STATIC
    Code:
      stack=2, locals=5, args_size=1
         0: ldc           #7                  // String ss
         2: astore_1
         3: bipush        11
         5: istore_2
         6: iload_2
         7: invokedynamic #9,  0              // InvokeDynamic #0:apply:(I)Ljava/util/function/Function;
        12: astore_3
        13: aload_3
        14: aload_1
        15: invokeinterface #13,  2           // InterfaceMethod java/util/function/Function.apply:(Ljava/lang/Object;)Ljava/lang/Object;
        20: checkcast     #18                 // class java/lang/String
        23: astore        4
        25: getstatic     #20                 // Field java/lang/System.out:Ljava/io/PrintStream;
        28: aload         4
        30: invokevirtual #26                 // Method java/io/PrintStream.println:(Ljava/lang/String;)V
        33: return

BootstrapMethods:
  0: #55 REF_invokeStatic java/lang/invoke/LambdaMetafactory.metafactory:(Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodHandle;Ljava/lang/invoke/MethodType;)Ljava/lang/invoke/CallSite;
    Method arguments:
      #47 (Ljava/lang/Object;)Ljava/lang/Object;
      #48 REF_invokeStatic LambdaTest.lambda$main$0:(ILjava/lang/String;)Ljava/lang/String;
      #51 (Ljava/lang/String;)Ljava/lang/String;
```

- `invokedynamic`相关的内容:
```
7: invokedynamic #9,  0   // InvokeDynamic #0:apply:(I)Ljava/util/function/Function;

BootstrapMethods:
  0: #55 REF_invokeStatic java/lang/invoke/LambdaMetafactory.metafactory:(Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodType;Ljava/lang/invoke/MethodHandle;Ljava/lang/invoke/MethodType;)Ljava/lang/invoke/CallSite;
```


### 参考链接
https://iklam.github.io/jekyll/update/2017/12/15/lambda-notes-001.html
https://iklam.github.io/jekyll/update/2017/12/19/lambda-notes-002-method-handle.html
https://cr.openjdk.org/~briangoetz/lambda/lambda-translation.html

