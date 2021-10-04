### 数据流分析
- 控制流分析: （代码跳转的问题）分析代码IR，理解操作间的控制流程。获得控制流图（CFG）
- 数据流分析: （值的流动问题，使用联立方程的形式）分析值是如何流经代码，寻找改进代码的机会，和证明变换的安全性。
- 静态单赋值形式: 一种中间表示（IR），统一了控制流和数据流分析的结果
- 只关注控制流图的子集（可以表示为树），往往使得分析变得简单。
- 本章关注整个控制流图的全局分析，也会涉及程序调用图的分析。


#### 迭代数据流分析
- 支配性（dominance）计算（可以视为一种控制流分析）
    - 从开始节点到目标节点b的所有路径上，都有某个节点c，则c是b的支配者
    - 某个节点（基础块）b，集合Dom(b)包含了支配b的所有节点的名字
    - Dom(n) = {n} U ( && Dom(m,m为n的前驱节点) )，其中Dom(n0) = {n0};所有前驱路径汇总的解可以叫聚合路径解
    - 1. 构建CFG
    - 2. 初始化各个基础块的初始信息
    - 3. 根据方程式迭代计算结果，直到到达不动点。
    - 上面3步算法可以说是迭代算法。迭代算法的解，就是聚合路径解。
    - 后续遍历（PostOrder traversal，PR）: 遍历一个节点之前，先遍历所有的子节点（后继节点）
    - 逆后序遍历（Reverse Postorder traversal，RPO）: 遍历一个节点之前，先遍历所有的前驱节点
    - 某个节点的逆后续遍历序号，即是|N|减去其后续遍历序号。也就是顺序刚好相反。
    - 正向数据流问题（例如Dom），应该使用CFG的某个RPO顺序。反向数据流问题（例如LiveOut），应该使用反向CFG的某个RPO顺序。
- 活跃变量分析
    - LiveOut方程式在第8章
    - 这是一个反向数据流问题，应该使用反向CFG的逆后序遍历顺序
- 数据流分析的局限性
    - 居于某种假设，但是这种假设不准确（比如LiveOut假设每条路径都有用）
    - 语言特征导致分析不精确（指针、数组和引用导致对定义的分析不精确）
- 其他数据流问题
    - 可用表达式（本节点可以使用的表达式）
        - AvailIn(n) = &所有前驱节点m ( DEExpr(m) U (AvailIn(m) & ~ExprKill(m) ) )
        - 用于全局冗余消除（也成为全局子表达式消除）
        - 用于缓式代码移动
    - 可达定义（节点可以访问的之前定义的变量）
        - Reaches(n) = U所有前驱节点m ( DEDef(m) U (Reaches(m) & ~DefKill(m) ) )
    - 可预测表达式(后继节点可以使用的表达式)
        - AntOut(n) = &所有后继节点m ( UEExpr(m) U (AntOut(m) & ~ExprKill(m) ) )
        - 用于缓式代码移动、代码提升
    - 过程间可能修改的变量集（作用在程序调用图，不是CFG）
        - MayMod(p) = LocalMod(p) U ( 所有p到q的边 U unbind(MayMod(q) ) )


### 静态单赋值形式SSA
- 定义: 1. 每个定义都创建了唯一的名字 2. 每个使用处都引用了一个定义
- 构造SSA，依赖数据流分析
- 把代码转换成SSA，可以避免多次数据流分析
- 构造SSA的简单方法
    - 1. 为过程中每个定义或使用的名字插入选择函数
    - 2. 重命名各个变量

- 构造SSA的半剪枝方法
    - 计算基本块n的支配边界DF(n)。
        - DF的元素块m满足1.n支配m的一个前驱 2.n不严格支配m
        - 通俗来说，就是离开n的每条CFG路径中，从n可达但不支配的第一个节点
        - IDOM(n): n的直接支配节点，严格支配n的节点集Dom(n)-n中与n最接近的节点
        - 支配者树: 包含支配性信息（DOM、IDOM）的树
        - 1. 构建控制流图，构建Dom和IDom和支配者树
        - 2. 遍历所有节点，如果某个节点n有多个前驱（即汇合点），则进行下面的操作
        - 2.1. 判断某个前驱节点p是不是n的直接支配者（IDom），如果不是，把n加到DF(p)中
        - 2.2. 循环获取p的直接支配者p2，使用p2继续进行2.1的操作。直到某个节点是n的直接支配者
        - 3. 遍历完所有节点，算法即结束

    - 放置SSA选择函数
        - 基础: 所有汇合点都加上所有变量的选择函数
        - 优化: 块b的变量只在它的支配边界DF(b)上加选择函数;块内变量(和UEVar、LiveOut集合有关)不需要加选择函数;
        - 1. 找到所有全局变量，放在集合globals（各个块的UEVar的并集），同时记录各个变量定义所在的块。（这一步其实就是活跃性分析,但是不计算LiveOut集）
        - 1.1 对于块中一条语句代码，其使用的变量如果没有在该块中定义（没有在该块的KillVar集合中），则该变量是该块使用其他块的，即在这个块的UEVar集中。把该使用的变量放到globals集合中。
        - 1.2 该条语句必定定义了一个变量，记录该变量定义x在KillVar中，把该模块放在变量x对应的定义列表Blocks(x)中
        - 2 遍历globals集合，遍历globals集合里面的每个变量x的blocks集合的块b（用到了DOM、IDOM、DF）
        - 2.1 如果b的依赖边界DF(b)没有x的选择函数，则加上。然后把依赖边界块加入遍历循环中（因为在块里面加上选择函数，等于说加上了x的定义）
        - 剪枝: 需要计算LiveOut集;半剪枝: 不需要计算LiveOut，但是要使用UEVar，类似于计算LiveOut; 不剪枝: 汇合点插入有不同定义的变量的选择函数。

    - 重命名
        - a = b + c; a则是定义名，b、c是使用名。
        - 1. 先序遍历所有模块
        - 2. 遍历模块b，重写选择函数的定义名、语句的使用名和定义名，把名字对应的标号压入栈中
        - 3. 填充模块b所有后继模块的选择函数的参数
        - 4. 对模块b在支配树（DOM、IDOM）的后继模块重复2-5的操作
        - 5. 弹出之前压入栈的各个名字，使得前面模块的处理可以继续进行

- SSA到其他形式的转换
    - 1. 把SSA选择函数变成前驱块的赋值语句
    - 2. 把关键边（critical edge）相应的赋值语句放到一个单独的块中
    - 关键边: 边的源节点有多个后继节点，边的目标节点有多个前驱节点

- 使用静态单赋值格式
    - 全局常量传播（算法: 稀疏简单常量传播SSCP）
    - 半格（semilattice）: 一个值集L和一个meet运算符，且meet运算符满足幂等、交换、结合律。
    - 半格有顶元素、底元素;任何元素与定元素进行meet运算，都返回任何元素;任何元素和底元素进行meet运算，都返回底元素。
    - 对于常量的半格表示: 顶元素表示值不可知，对应选择函数;底元素对应可变量;中间元素对应常量值;
    - 1. 初始化阶段: 初始化所有定义名的值，分别为顶元素、底元素、常量值;把非顶元素（即已经确定知道的量）的名字放到工作列表worklist中
    - 2. 传播阶段: 从worklist中不断移除名字n，逐个考察使用了n的定义m，其中操作为op。直到worklist为空结束循环。
    - 2.1 如果Value(m)为底元素，则不用进一步求值
    - 2.2 如果不是，则模拟操作op进行求值，如果结果在格中低于Value(m)，则下调Value(m)，并将m加入worklist中。
    - 算法将未知值初始化为顶元素的叫做乐观算法。将未知值初始化为底元素的是否叫做悲观算法。

#### 过程间分析
- 构建调用图
    - 各个方法作为节点，有call相关语句就加一条边

- 过程间常量传播
    - 发现常量的初始集合、围绕调用图传播已知的常量值、对值穿越过程的传输进行建模
    - TODO 对于跳跃函数还是不太懂


#### 高级主题
- 结构性数据流算法和可归约性
    - T1变换: 删除自环。T2变换: 将只有一个前驱节点块a的b块合并到a中。
    - 可归约图: 可以通过变换T1和T2将控制流图归约成一个结点，则该CFG是可归约的。
    - 一般来说，CFG是多入口环，则图不可归约
    - 对于不可归约的图，只能使用之前的迭代算法（作用在归约到一半的图也行），不能使用结构性数据流算法
    - 不可归约的图可以通过拆分（复制）节点，来重构图，使得新图可以归约。
    - 这节没写具体的结构性数据流算法

- 迭代框架支配性算法
    - 之前是使用Dom的迭代算法计算Dom，再根据Dom计算IDom
    - 现在是根据IDom的定义，使用交集来计算公共后缀（此时的树已经是支配者树），公共后缀节点即是IDom，根据IDom即可知道支配者树，即可得出Dom
