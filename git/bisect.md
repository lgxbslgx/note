# bisect 二分法定位错误

开始:
git bisect start [bad-commit] [good-commit]
eg: git bisect start d74039fa8e 831636b0
或者
git bisect start
git bisect bad main
git bisect good f00ba

中间标志:
git bisect bad
git bisect good
git bisect skip

结束:
git bisect reset

运行自动化脚本:
git bisect run test.sh

脚本退出码和是否成功的关系：
skip: exit 125
good: exit 0
bad: exit 1-124
