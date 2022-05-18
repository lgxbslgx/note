### bisect 二分法

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

脚本:
git bisect run test.sh
skip: exit 125
good: exit 0
bad: exit 1-124

