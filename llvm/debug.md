build/bin/clang -S -emit-llvm source.c -v
输出一系列命令

gdb --args [上面输出的命令]

cd ~/source/cpp/test
gdb --args ~/source/cpp/test-llvm/build/bin/clang-15 -cc1 member_pointer.cpp
source /home/lgx/source/cpp/test-llvm/llvm/utils/gdb-scripts/prettyprinters.py

