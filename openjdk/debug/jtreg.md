- build jtreg

```
cd /home/lgx/source/java/jtreg
bash make/build.sh --jdk /usr/lib/jvm/java-1.11.0-openjdk-amd64/ --skip-download
```

- run test

```
cd /home/lgx/source/java/jdk
/home/lgx/source/java/jtreg/build/images/jtreg/bin/jtreg -jdk:/home/lgx/source/java/jdk/build/linux-x86_64-server-release/images/jdk/ -w /home/lgx/source/java/jdk/build/linux-x86_64-server-release/JTwork -r /home/lgx/source/java/jdk/build/linux-x86_64-server-release/JTreport test/langtools/tools/javac/Verify.java
```

