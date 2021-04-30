### Build
mvn clean install -Djavac.benchmark.openjdk.zip.download.url=file:///home/lgx/source/java/jmh-jdk-microbenchmarks/micros-javac/openjdk-11+28_windows-x64_bin.zip 

### Run
java --add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED  --add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED -jar micros-javac/target/micros-javac-1.0-SNAPSHOT.jar .+GroupJavacBenchmark.+ | tee JDK-8260053.log
