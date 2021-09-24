## Introduction to optimization

### Considerations
- Safety
- Profitability and performance

### Scope of optimization(granularity)
- Local(a basic block)
- Regional(multiple block, extended basic block EBB)
- Global(intraprocedural, a full procedure)
- Interprocedura(whole-program, universal)

#### Local optimization
- Local value numbering(LVN): find and eliminate redundancies.
	- hash table: key->hashcode of operand and operator, value->number and indentifiers(names).
	- Initially, the hashtable is empty. Later, add or update entry in hashtable according to the operands and oprators. It is no deletion.
	- extend: Commutative operations. Use value number to order operands.
	- extend: Constant folding.
	- extend: Algebraic identities.
	- extend: static single-assignment form.

- Tree-height balancing
	- Find candidate tree. commutative, associative, used more than once. create a priority queue of operator precedence.
	- Create balanced tree.（类似于huffman树）
		- Flatten the tree, create a priority queue of operand rank.
		- Rebuild the tree, create a balanced tree.

#### Region Optimization
- Superlocal Value Numbering
	- 获取根基础块（有多个前趋的基础块）
    - 根据根基础块构建拓展基本块（EBB)
    - 得到拓展基本块的各个路径
    - 遍历各个拓展基础块，从根基础块开始进行值编号，其后续块使用前面的块的值编号表

- Loop Unrolling
    - 循环展开。使得 循环变量每次递增一个大的数量，而且循环内部的代码成复制性增加。

#### Gobal Optimization
- 全局数据流分析（查找未初始化的变量）
    - 先求每个模块的LiveOut集合，该集合表示在后继的模块中活跃的变量（被使用的变量）。
        - LiveOut(n) = U (UEVar(m) | (LiveOut(m) && ~VarKill(m)) )
        - UEVar: upward-explosed variable 前面（上层）模块定义的变量，该模块使用;
        - VarKill: 定义在该模块的变量
        - 1. 构建控制流图CFG
        - 2. 计算各个模块的UEvar和VarKill
        - 3. 根据公式迭代计算LiveOut，直到各个集合到达不动点（一次迭代后没变化）
    - 寻找未初始化的变量
        - liveout里面都是潜在的未初始化变量
        - 但是这个是不确定的内容，所以好像问题没解决。。
    - 数据流分析其他应用: 全局寄存器分配、构建SSA时需要数据流信息、发现无用的store操作

- 全局代码置放
    - 分支跳转时，有一条分支是可以紧接着执行的（落空分支，fall-through branch），另一条分支是跳转的（采纳分支，taken branch）
    - 如果两个部分的代码执行频率相差很多，把执行频率高的代码放在落空分支，将会使得效率可以提高
    - 执行频率的几种统计方法（装有测量机制的可执行文件、定时器中断、性能计数器），好像都离不开运行时，貌似静态编译器没法分析？
    - 1. 获取控制流图的各个跳转边的频率。
    - 2. 构建热路径（贪心算法，每次都找最大的那条边，把一副图变成若干条链）
    - 3. 进行代码布局（从入口代码块对应的链开始，进行代码布局）

#### Interprocedural Optimization
- 内联替换
    - 优点: 减少了连接的代码，提高了其他优化的可能性和有效性
    - 缺点: 加大了方法的规模（代码长度和命名空间），可能使其他优化方法运行效率变低和优化效果不佳
    - 选择内联位置
        - 被调用者代码长度（规模）很小，少于连接的代码
        - 内联后，调用者代码长度也不能太大
        - 动态调用计数，内联频繁调用的方法
        - 实际参数是参数
        - 静态调用计数，调用的位置过多，代码量会激增，也不好
        - 参数个数计数
        - “叶过程（不调用其他方法的方法）”是很好的内联对象
        - 循环内部的调用执行频繁，一般更适合内联
        - 占时间比例较大的更适合内联
    - 内联具体操作
        - 对调用连接代码进行改写，模拟参数绑定和返回值
        - 对被调用方法的变量进行重新命名，避免名字冲突

- 过程置放
    - 在可执行映像中重排各个过程，类似“全局代码置放”
    - 1. 获取各个调用的执行频率（也就是调用图的边的权重），并使用各个边来构造一个优先权队列
    - 2. 从优先权队列里面获取权限最高的边<x,y>, 把x和y两个方法整合在一起
    - 3. 优先权队列中，关于y相关的边，都使用x来代替
    - 4. 从调用图中删除y和其对应的边
    - 5. 重复2-4直到图中只剩一个节点

