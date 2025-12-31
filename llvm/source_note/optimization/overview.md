# Clang/LLVM优化内容概述

## 优化级别

- `O0`：（默认选项）基本无优化，编译速度最快，方便调试。
- `O1`：简单优化，在调试便利性和性能之间取得平衡。
- `O2`：（建议生产环境选项）启用几乎所有不涉及空间/速度权衡的优化选项。
- `O3`：最高级别的优化，编译速度最慢。
- `Os`：优化代码体积。启用所有`O2`中​​不会显著增加代码大小​​的优化选项。
- `Oz`：更激进地优化代码体积。牺牲一些性能来换取更小的代码体积。

## 常用命令

```shell
# 查看所有优化列表（300多个）
opt --print-passes

# -E：只预处理，不编译、汇编和链接。打印出预处理后的代码。
# -S：只预处理和编译，不汇编和链接。生成汇编代码文件。
# -c：只预处理、编译和汇编，不链接。生成可重定向的目标文件。
# -emit-llvm：输出格式为LLVM IR。
# -S和-emit-llvm：只预处理和编译，不汇编和链接。输出LLVM IR文本格式（*.ll）。
# -c和-emit-llvm：只预处理、编译和汇编，不链接。输出LLVM IR二进制格式（*.bc）。

# 编译C代码到LLVM IR
clang -emit-llvm -c test.c

# 编译CPP代码到LLVM IR
clang++ -emit-llvm -S test.cpp

# 查看优化的输出信息
opt -O0 -disable-output -debug-pass-manager test.ll

# 查看某一个优化级别的优化列表
opt -O0 -disable-output -print-pipeline-passes test.ll
```

## 优化列表

下面是使用命令`opt --print-passes`的输出结果。

```shell
Module passes: Module级别的优化
  always-inline 强制函数内联
  attributor 过程间属性推断和传播框架
  annotation2metadata 将注解转换为元数据
  openmp-opt OpenMP优化
  called-value-propagation 被调用值传播优化
  canonicalize-aliases 别名规范化
  cg-profile 调用图性能分析
  check-debugify 检查调试信息
  constmerge 合并相同的常量
  cross-dso-cfi 跨DSO控制流完整性
  deadargelim 删除无用函数参数
  debugify 添加调试信息伪指令
  elim-avail-extern 消除可用的外部声明
  extract-blocks
  forceattrs 强制函数属性
  function-import
  function-specialization 函数特化（基于参数常量化）
  globaldce 全局死代码消除
  globalopt 全局优化
  globalsplit 全局变量分割优化
  hotcoldsplit 热冷代码分割
  inferattrs
  inliner-wrapper
  print<inline-advisor>
  inliner-wrapper-no-mandatory-first
  insert-gcov-profiling
  instrorderfile
  instrprof
  internalize
  invalidate<all>
  ipsccp 过程间稀疏条件常量传播
  iroutliner IR代码外联（去重）
  print-ir-similarity
  lowertypetests
  metarenamer
  mergefunc 合并相似函数
  name-anon-globals
  no-op-module
  objc-arc-apelim
  partial-inliner 部分函数内联
  pgo-icall-prom 基于PGO的间接调用优化
  pgo-instr-gen PGO（性能导向优化）插桩生成
  pgo-instr-use PGO信息使用
  print-profile-summary
  print-callgraph
  print
  print-lcg
  print-lcg-dot
  print-must-be-executed-contexts
  print-stack-safety
  print<module-debuginfo>
  rel-lookup-table-converter
  rewrite-statepoints-for-gc 为垃圾收集重写状态点
  rewrite-symbols
  rpo-function-attrs
  sample-profile 采样性能分析
  scc-oz-module-inliner
  strip
  strip-dead-debug-info
  pseudo-probe
  strip-dead-prototypes
  strip-debug-declare
  strip-nondebug
  strip-nonlinetable-debuginfo
  synthetic-counts-propagation
  verify
  wholeprogramdevirt
  dfsan 数据流Sanitizer
  msan-module MemorySanitizer模块级处理
  module-inline
  tsan-module ThreadSanitizer模块级处理
  sancov-module Sanitizer覆盖率模块
  memprof-module
  poison-checking
  pseudo-probe-update
Module passes with params:
  loop-extract<single>
  hwasan<kernel;recover> 硬件辅助的AddressSanitizer
  asan-module<kernel> AddressSanitizer模块级处理
Module analyses: Module级别的分析
  callgraph
  lcg
  module-summary
  no-op-module
  profile-summary
  stack-safety
  verify
  pass-instrumentation
  asan-globals-md
  inline-advisor
  ir-similarity
  globals-aa
Module alias analyses: Module级别的别名分析
  globals-aa
CGSCC passes: 调用图强联通分量相关的优化
  argpromotion
  invalidate<all>
  function-attrs
  attributor-cgscc
  openmp-opt-cgscc
  coro-split
  no-op-cgscc
CGSCC passes with params:
  inline<only-mandatory>
CGSCC analyses: 调用图强联通分量相关的分析
  no-op-cgscc
  fam-proxy
  pass-instrumentation
Function passes: 方法级别的优化
  aa-eval
  adce
  add-discriminators
  aggressive-instcombine
  assume-builder
  assume-simplify
  alignment-from-assumptions
  annotation-remarks
  bdce
  bounds-checking
  break-crit-edges
  callsite-splitting
  consthoist
  constraint-elimination
  chr
  coro-early
  coro-elide
  coro-cleanup
  correlated-propagation
  dce
  dfa-jump-threading
  div-rem-pairs
  dse
  dot-cfg
  dot-cfg-only
  dot-dom
  dot-dom-only
  fix-irreducible
  flattencfg
  make-guards-explicit
  gvn-hoist
  gvn-sink
  helloworld
  infer-address-spaces
  instcombine
  instcount
  instsimplify
  invalidate<all>
  irce
  float2int
  no-op-function
  libcalls-shrinkwrap
  lint
  inject-tli-mappings
  instnamer
  loweratomic
  lower-expect
  lower-guard-intrinsic
  lower-constant-intrinsics
  lower-widenable-condition
  guard-widening
  load-store-vectorizer
  loop-simplify
  loop-sink
  lowerinvoke
  lowerswitch
  mem2reg
  memcpyopt
  mergeicmps
  mergereturn
  nary-reassociate
  newgvn
  jump-threading
  partially-inline-libcalls
  lcssa
  loop-data-prefetch
  loop-load-elim
  loop-fusion
  loop-distribute
  loop-versioning
  objc-arc
  objc-arc-contract
  objc-arc-expand
  pgo-memop-opt
  print
  print<assumptions>
  print<block-freq>
  print<branch-prob>
  print<cost-model>
  print<cycles>
  print<da>
  print<divergence>
  print<domtree>
  print<postdomtree>
  print<delinearization>
  print<demanded-bits>
  print<domfrontier>
  print<func-properties>
  print<inline-cost>
  print<inliner-size-estimator>
  print<loops>
  print<memoryssa>
  print<memoryssa-walker>
  print<phi-values>
  print<regions>
  print<scalar-evolution>
  print<stack-safety-local>
  print-alias-sets
  print-predicateinfo
  print-mustexecute
  print-memderefs
  reassociate
  redundant-dbg-inst-elim
  reg2mem
  scalarize-masked-mem-intrin
  scalarizer
  separate-const-offset-from-gep
  sccp
  sink
  slp-vectorizer
  slsr
  speculative-execution
  sroa
  strip-gc-relocates
  structurizecfg
  tailcallelim
  unify-loop-exits
  vector-combine
  verify
  verify<domtree>
  verify<loops>
  verify<memoryssa>
  verify<regions>
  verify<safepoint-ir>
  verify<scalar-evolution>
  view-cfg
  view-cfg-only
  transform-warning
  tsan
  memprof
Function passes with params:
  early-cse<memssa>
  ee-instrument<post-inline>
  lower-matrix-intrinsics<minimal>
  loop-unroll<O0;O1;O2;O3;full-unroll-max=N;no-partial;partial;no-peeling;peeling;no-profile-peeling;profile-peeling;no-runtime;runtime;no-upperbound;upperbound>
  asan<kernel>
  msan<recover;kernel;eager-checks;track-origins=N>
  simplifycfg<no-forward-switch-cond;forward-switch-cond;no-switch-range-to-icmp;switch-range-to-icmp;no-switch-to-lookup;switch-to-lookup;no-keep-loops;keep-loops;no-hoist-common-insts;hoist-common-insts;no-sink-common-insts;sink-common-insts;bonus-inst-threshold=N>
  loop-vectorize<no-interleave-forced-only;interleave-forced-only;no-vectorize-forced-only;vectorize-forced-only>
  mldst-motion<no-split-footer-bb;split-footer-bb>
  gvn<no-pre;pre;no-load-pre;load-pre;no-split-backedge-load-pre;split-backedge-load-pre;no-memdep;memdep>
  print<stack-lifetime><may;must>
Function analyses: 方法级别的分析
  aa
  assumptions
  block-freq
  branch-prob
  cycles
  domtree
  postdomtree
  demanded-bits
  domfrontier
  func-properties
  loops
  lazy-value-info
  da
  inliner-size-estimator
  memdep
  memoryssa
  phi-values
  regions
  no-op-function
  opt-remark-emit
  scalar-evolution
  should-not-run-function-passes
  should-run-extra-vector-passes
  stack-safety-local
  targetlibinfo
  targetir
  verify
  pass-instrumentation
  divergence
  basic-aa
  cfl-anders-aa
  cfl-steens-aa
  objc-arc-aa
  scev-aa
  scoped-noalias-aa
  tbaa
Function alias analyses: 方法级别的别名分析
  basic-aa
  cfl-anders-aa
  cfl-steens-aa
  objc-arc-aa
  scev-aa
  scoped-noalias-aa
  tbaa
LoopNest passes: 循环嵌套相关的优化
  lnicm
  loop-flatten
  loop-interchange
  loop-unroll-and-jam
  no-op-loopnest
Loop passes: 循环相关的优化
  canon-freeze
  dot-ddg
  invalidate<all>
  licm
  loop-idiom
  loop-instsimplify
  loop-rotate
  no-op-loop
  print
  loop-deletion
  loop-simplifycfg
  loop-reduce
  indvars
  loop-unroll-full
  print-access-info
  print<ddg>
  print<iv-users>
  print<loopnest>
  print<loop-cache-cost>
  loop-predication
  guard-widening
  loop-bound-split
  loop-reroll
  loop-versioning-licm
Loop passes with params:
  simple-loop-unswitch<nontrivial;no-nontrivial;trivial;no-trivial>
Loop analyses: 循环相关的分析
  no-op-loop
  access-info
  ddg
  iv-users
  pass-instrumentation
```
