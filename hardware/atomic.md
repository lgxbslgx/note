## CPU提供的原子指令

### 一些常见原子指令名称
- `atomic exchange`
- `test-and-set`
- `compare-and-exchange`
- `fetch-and-increment`
- `load reserved (load linked) / store conditional`
- `load acquire / store release`
- `load exclusive / store exclusive`

### 原子性分类（目前看到3种，不知道有没有其他的）

`single-copy atomic`单拷贝原子性：
- 同地址的2个写操作有先后顺序（串行化`serialized`）
- 同地址的读操作读到写操作的值，则写操作的顺序一定不能在读操作后面
- 在多核处理器中，`single-copy atomic`是不够的，原因如下
  - `single-copy atomic`只能保证原子操作不能被当前核的中断、异常等事件打断
  - `single-copy atomic`不能阻止其他核对同一地址进行操作
  - 所以在多核处理器中，需要加入下文其中的一种多拷贝原子性。
- 在`x86`、`ARM`中，**基本类型（不超过64位）且数据对齐的读写操作**一般都满足**`single-copy atomic`单拷贝原子性**。

`Multi-copy atomicity`多拷贝原子性：
- 所有的写都要顺序化（串行化`serialized`），所有核见到的写顺序要一样（这一点和`Coherence`一样）
- 读操作只能读到所有核都见到的写的值（这一点比`Coherence`严格）
- 总的来说，`Multi-copy atomicity`比`coherence`严格
- 有时候也用`Multi-copy atomicity`来表示`Other-multi-copy atomicity`，注意特定的描述场景（比如RISV-V的文档）

`Other-multi-copy atomicity`其它多拷贝原子性（直译）：
- 写操作被**一个其他核**见到，即可被所有其他核见到。
- 一个读操作可以在其他核看到自己核的写操作之前看到该写操作。（比`Multi-copy atomicity`要宽松）
- `x86`、`ARM`、`RISC-V`的内存模型应该都满足`Other-multi-copy atomicity`


### X86提供的原子指令
资料：
- Intel X86文档 第3卷 8.1 LOCKED ATOMIC OPERATIONS
- AMD X86文档 第1卷 3.5.1.3 Lock Prefix
- AMD X86文档 第3卷 1.2.5 Lock Prefix

X86大部分**基本类型（不超过64位）且数据对齐的读写操作**满足原子性，准确来说应该是满足**`single-copy atomic`单拷贝原子性**。

X86只有原子交换`xchg`这一条有锁语义的原子指令。很多时候都是使用`Lock`前缀实现锁语义。

有锁语义（意味着`原子`）的指令
- **`xchg`，原子交换指令（注意这个指令没有比较操作，是直接交换）**
- **`lock`指令前缀**。加了`lock`前缀的指令，在运行的时候锁住总线。注意只有少量指令能加`lock`前缀。详细指令见`Intel-X86文档 第3卷 8.1.2.2 Software Controlled Bus Locking`。
  - Bit位测试、修改指令：BTS, BTR, and BTC
  - 交换指令：XADD, CMPXCHG, and CMPXCHG8B
  - 单操作数的算数和逻辑指令：INC, DEC, NOT, and NEG
  - 双操作数的算数和逻辑指令：ADD, ADC, SUB, SBB, AND, OR, and XOR

其他有锁语义的操作（见`Intel-X86文档 第3卷 8.1.2.1 Automatic Locking`）：
- 设置TSS描述符的`B(busy)`位
- 更新段描述符
- 更新页目录和页表项
- 确认中断，中断控制器发送中断编号给处理器时
- 其他，未仔细看


### ARM提供的原子指令
资料：
- ARM手册 B2 The AArch64 Application Level Memory Model
- ARM手册 D7 The AArch64 System Level Memory Model
- ARM手册 E2 The AArch32 Application Level Memory Model
- ARM手册 G4 The AArch32 System Level Memory Model
- [ARMv8之Atomicity](http://www.wowotech.net/armv8a_arch/atomicity.html)

ARM大部分**基本类型（不超过64位）且数据对齐的读写操作**满足原子性，准确来说应该是满足 **`single-copy atomic`单拷贝原子性**。

// TODO 未完成


### RISC-V提供的原子指令
资料：
- RISC-V规范 10 “A” Standard Extension for Atomic Instructions
- RISC-V规范 Atomic Compare-and-Swap (CAS) instructions (Zacas)

注意RISC-V和X86的不同，X86（有锁语义）的原子指令都保证了内存（`memory order`）有序性，但是RISC-V中，需要设置对应指令的`acquire`和`release`位，才能保证对应的内存顺序。**这些RISC-V指令的`aq/rl`位相当于X86的`lock`前缀吧。**

原子相关指令（这些指令都有`aq/rl`位）：
- 加载保留和条件储存`LR.W/D`、`SC.W/D`（`load-reserved`、`store-conditional`）
  - 可以使用`LR/SC`实现原子比较并交换操作`compare and exchange`，详见下文。
- `A`拓展的原子内存操作 `atomic memory operation (AMO)`
  - 原子交换操作 `AMOSWAP.W/D`
  - 原子整数加操作 `AMOADD.W/D`
  - 原子与操作 `AMOAND.W/D`
  - 原子或操作 `AMOOR.W/D`
  - 原子异或操作 `AMOXOR.W/D`
  - 原子最大操作 `AMOMAX[U].W/D`
  - 原子最小操作 `AMOMIN[U].W/D`
- `Zacas`拓展的原子内存操作
  - 原子比较并交换指令 `AMOCAS.W/D/Q`

使用`LR/SC`实现原子比较并交换操作:
```
# a0 holds address of memory location
# a1 holds expected value
# a2 holds desired value
# a0 holds return value, 0 if successful, !0 otherwise
cas:
  lr.w t0, (a0) # Load original value.
  bne t0, a1, fail # Doesn’t match, so fail.
  sc.w t0, a2, (a0) # Try to update.
  bnez t0, cas # Retry if store-conditional failed.
  li a0, 0 # Set return to success.
  jr ra # Return.
fail:
  li a0, 1 # Set return to failure.
  jr ra # Return.
```

