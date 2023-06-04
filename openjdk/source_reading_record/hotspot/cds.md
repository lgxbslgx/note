类数据共享内容

## Static CDS archive file (JDK10)
```
java -Xshare:off -XX:DumpLoadedClassList=hello.txt CDSTest
java -Xshare:dump -XX:SharedClassListFile=hello.txt -XX:SharedArchiveFile=hello.jsa # 这一步不用写主类
java -XX:SharedArchiveFile=hello.jsa CDSTest
```

## Default CDS file lib/server/classes.jsa (JDK12)
```
java CDSTest
```

## Dynamic CDS archive file (JDK13)
```
java -XX:ArchiveClassesAtExit=hi.jsa CDSTest
java -XX:SharedArchiveFile=hello.jsa:hi.jsa CDSTest
java -XX:SharedArchiveFile=hi.jsa CDSTest # 使用默认集lib/server/classes.jsa
```

## 关闭CDS
```
java -Xshare:off CDSTest
```
