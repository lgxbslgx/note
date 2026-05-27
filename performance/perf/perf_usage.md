# perf使用方法

## 帮助文档

- `perf help`：显示帮助信息
- `perf help <command>`：显示指定命令的帮助信息
- `perf list`：显示所有事件

## 常用命令

- `sudo perf stat <command>`：运行命令并获取计数数据
- `sudo perf top`：显示实时采样数据
- `sudo perf record <command>`：运行命令并记录采样数据
- `sudo perf script -i perf.data`：读取数据，显示采样记录（不聚合，每个采样逐条打印）
- `sudo perf report -i perf.data`：读取数据，显示采样数据的报告（按函数/指令​聚合，显示汇总信息）

## 常用参数

- `-a`：收集所有CPU数据
- `-g`：启动调用图记录
- `-e`：指定事件名称
- `-F`：指定采样频率
- `-p`：指定进程ID
- `-t`：指定线程ID

## 火焰图

注意`perf record`要加上`-g`参数记录调用栈。

### 生成火焰图

```shell
# 生成报告
sudo perf record -F 999 -a -g -- sleep 10

# 获取数据
sudo perf script -f -i perf.data > perf.unfold

# 生成折叠栈
./FlameGraph/stackcollapse-perf.pl perf.unfold > perf.folded

# 生成火焰图
./FlameGraph/flamegraph.pl perf.folded > perf.svg
```

### 查看火焰图

用浏览器打开`perf.svg`即可。比如chrome浏览器，则可以运行命令`google-chrome perf.svg`。

- X轴宽度：CPU时间占比
- Y轴高度：调用栈深度
