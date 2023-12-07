- 没有被`native`和`IntrinsicCandidate`方法修饰，单纯解释执行和按平常一样编译后执行。

- `native`修饰的方法表示 该方法不用Java代码实现、或者说不显式用Java代码实现（因为有`MethodHandle`等一些例外，`MethodHandle`是动态生成java代码）。解释器会调用其`native`代码（比如由C/C++实现），C1、C2编译器**一般**不编译这些方法（因为有`IntrinsicCandidate`等例外）。

- `IntrinsicCandidate`注解修饰的方法，表示执行引擎可能会对它进行优化，具体的信息在`vmIntrinsics.hpp`等文件。这里的`执行引擎`包括了解释器、C1编译器、C2编译器。解释器很少对`IntrinsicCandidate`的方法进行处理（被解释器优化的方法在`AbstractInterpreter::MethodKind`中），单纯解释执行对应的java代码。而C2对`IntrinsicCandidate`的方法优化最多。（被C1优化的方法在`LIRGenerator::do_Intrinsic`中，被C2优化的方法在`C2Compiler::is_intrinsic_supported`中）

- 如果方法被`native`和`IntrinsicCandidate`方法一起修饰，则解释器一般会调用其native代码（因为有`MethodHandle`等一些例外），C1、C2会根据是否已经`intrinsic`处理该方法，来选择是否优化它。

综合: 是否`native`主要给解释器用的。是否`IntrinsicCandidate`，解释器、C1、C2都会用到，C2用得多一点。

