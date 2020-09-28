## Thoery
- JPDA(Java Platform Debugger Architecture)
	- VMTI(JVM Tool Interface)
	- JDWP(Java Debug Wire Protocol)
	- JDI(Java Debug Interface)

## Implement
-Server options
	'''
	java -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=*:5005 -m jdk.compiler/com.sun.tools.javac.launcher.Main  Hello.java
	'''

-Client options
	'''
	java -agentlib:jdwp=transport=dt_socket,server=n,address=127.0.0.1:5005,suspend=y -m jdk.compiler/com.sun.tools.javac.launcher.Main  Hello.java
	'''

	'''
	Use 'java -h' to see more usages.
	'''
