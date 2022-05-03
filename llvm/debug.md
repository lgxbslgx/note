~/source/cpp/test-llvm/build/bin/clang++ member_pointer.cpp -v
输出一系列命令

gdb --args [上面输出的命令]

cd ~/source/cpp/test

gdb --args ~/source/cpp/test-llvm/build/bin/clang -cc1 ~/source/cpp/test/member_pointer.cpp

gdb --args ~/source/cpp/test-llvm/build/bin/clang ~/source/cpp/test/member_pointer.cpp

gdb --args  /home/lgx/source/cpp/test-llvm/build/bin/clang -cc1 -triple x86_64-unknown-linux-gnu -emit-obj -mrelax-all --mrelax-relocations -disable-free -clear-ast-before-backend -main-file-name member_pointer.cpp -mrelocation-model pic -pic-level 2 -pic-is-pie -mframe-pointer=all -fmath-errno -ffp-contract=on -fno-rounding-math -mconstructor-aliases -funwind-tables=2 -target-cpu x86-64 -tune-cpu generic -mllvm -treat-scalable-fixed-error-as-warning -debugger-tuning=gdb -v -fcoverage-compilation-dir=/home/lgx/source/cpp/test -resource-dir /home/lgx/source/cpp/test-llvm/build/lib/clang/15.0.0 -internal-isystem /usr/lib/gcc/x86_64-linux-gnu/7.5.0/../../../../include/c++/7.5.0 -internal-isystem /usr/lib/gcc/x86_64-linux-gnu/7.5.0/../../../../include/x86_64-linux-gnu/c++/7.5.0 -internal-isystem /usr/lib/gcc/x86_64-linux-gnu/7.5.0/../../../../include/c++/7.5.0/backward -internal-isystem /home/lgx/source/cpp/test-llvm/build/lib/clang/15.0.0/include -internal-isystem /usr/local/include -internal-isystem /usr/lib/gcc/x86_64-linux-gnu/7.5.0/../../../../x86_64-linux-gnu/include -internal-externc-isystem /usr/include/x86_64-linux-gnu -internal-externc-isystem /include -internal-externc-isystem /usr/include -fdeprecated-macro -fdebug-compilation-dir=/home/lgx/source/cpp/test -ferror-limit 19 -fgnuc-version=4.2.1 -fcxx-exceptions -fexceptions -fcolor-diagnostics -faddrsig -D__GCC_HAVE_DWARF2_CFI_ASM=1 -o member_pointer.o -x c++ member_pointer.cpp

source /home/lgx/source/cpp/test-llvm/llvm/utils/gdb-scripts/prettyprinters.py

run



