- 没有被关键字`native`和注解`IntrinsicCandidate`方法修饰，单纯解释执行和按平常一样编译后执行。

- **关键字`native`修饰的方法表示该方法不用Java代码实现（比如由C/C++实现）**
  - 解释器会调用其`native`代码
  - C1、C2编译器**一般**不编译这些native方法（因为根本没有字节码，只有native代码、机器指令，没法编译）。

- 注解`IntrinsicCandidate`修饰的方法，表示执行引擎**可能**会对它进行优化（这种优化叫`intrinsic`，即虚拟机内部**可能**有更好的实现方式，**可能**不执行该方法的Java代码。）。
  - 这里的`执行引擎`包括解释器、C1编译器、C2编译器。
  - 可能被`intrinsic`的类和方法信息在`vmIntrinsics.hpp`等文件
  - **解释器很少对`IntrinsicCandidate`的方法进行处理，一般是解释执行对应的java代码。**
  - **C1、C2，特别是C2，对`IntrinsicCandidate`的方法优化很多，已经`intrinsic`的情况下，则使用`intrinsic`的实现即可，不需要使用java代码。**
  - 被解释器`intrinsic`的方法在`AbstractInterpreter::MethodKind`中。
  - 被C1`intrinsic`的方法在`c1_Compiler.cpp::Compiler::is_intrinsic_supported`中
  - 被C2`intrinsic`的方法在`c2compiler.cpp::C2Compiler::is_intrinsic_supported`中

- 如果方法被`native`和`IntrinsicCandidate`一起修饰，说明该方法不用Java代码实现，且可能会被执行引擎`intrinsic`
  - `执行引擎`如果不`intrinsic`该方法，会调用其native代码
  - **解释器很少对`IntrinsicCandidate`的方法进行处理，所以一般都是执行对应的native代码。**
  - **C1、C2，特别是C2，对`IntrinsicCandidate`的方法优化很多，已经`intrinsic`的情况下，则使用`intrinsic`的方法即可，不需要使用native代码。**
  - 上文提到`C1、C2编译器**一般**不编译native方法`。而这里方法被`native`和`IntrinsicCandidate`一起修饰的情况，C1、C2编译器也会处理（`intrinsic`）native方法。

综合: 
- 是否`native`表示：是否用Java代码实现
- 是否`IntrinsicCandidate`表示：虚拟机内部是否**可能**有更好的实现

