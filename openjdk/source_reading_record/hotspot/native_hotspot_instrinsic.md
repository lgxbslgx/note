- 没有被`native`和`HotspotIntrinsic`方法修饰，单纯解释执行和按平常一样编译。

- `native`修饰的方法表示 该方法不用Java代码实现、或者说不显式用Java代码实现（因为有`MethodHandle`等一些例外）。解释器会调用其`native`代码（比如由C/C++实现），C1、C2编译器**一般**不编译这些方法（因为有`HotspotIntrinsic`等例外）。

- `HotspotIntrinsic`注解修饰的方法，表示hotspot的执行引擎会对它进行优化。这里的`执行引擎`包括了解释器、C1编译器、C2编译器。很多时候，解释器一般没有对`HotspotIntrinsic`的方法进行处理，单纯解释执行对应的java代码。而C2对`HotspotIntrinsic`的方法优化最多。

- 如果方法被`native`和`HotspotIntrinsic`方法一起修饰，则解释器一般会调用其native代码（因为有`MethodHandle`等一些例外），C1、C2会根据是否已经`intrinsic`处理该方法，来选择是否优化它。

综合: 是否`native`主要给解释器用的。是否`HotspotIntrinsic`，解释器、C1、C2都会用到，C2用得多一点。

