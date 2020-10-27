# compiler 编译过程

## invoke
### way 1: com.sun.tools.javac.main.Main and com.sun.tools.javac.Main
- A legacy programmatic interface.
- com.sun.tools.javac.Main.compile()
- com.sun.tools.javac.main.Main.compile()
- com.sun.tools.javac.main.JavaCompiler.compile()  the main method to compile

### way 2: com.sun.tools.javac.launcher.Main and JavacTaskImpl
- Compiles a source file, and executes the main method it contains.
- com.sun.tools.javac.launcher.Main.run() 
- com.sun.tools.javac.launcher.Main.compile()  JavacTool get JavacTaskImpl
- com.sun.tools.javac.api.JavacTaskImpl.call()
- com.sun.tools.javac.api.JavacTaskImpl.doCall()
- com.sun.tools.javac.main.JavaCompiler.compile()  the main method to compile

### way 3: com.sun.tools.javac.main.JavacToolProvider or javax.tools.ToolProvider
- JavaCompiler javac = ToolProvider.getSystemJavaCompiler(); 
- Note:All other classes and methods found in a package with names that start with com.sun.tools.javac (subpackages of com.sun.tools.javac) are strictly internal and subject to change at any time.

## compile procedure
### Scanner(lexer, use tokenizer and UnicodeReader) and Parser. 
- Goal: Generate AST(abstract syntax trees, A CompilationUnit means a source file)
- Input: source file
- Output: AST.
- procedure
	- com.sun.tools.javac.main.JavaCompiler.parseFiles() and parse()
	- Create Scanner(Lexer) and  Parser parser
	- parser.parseCompilationUnit()

### Semantics. Enter. 
- Goal: Scan trees for class and member class declarations, and initialize symbols and validates annotations. Enter symbol for all encountered definintions into the symbol table. Get all types of the corresponding classes.
- Input: AST
- Output: A *todo* list and symbols.
	- The todo list contains 'Env<AttrContext<>>' that need to be analyzed and be used to generate class files later. An entry of todo list means a class or interface.
- procecdure
	- com.sun.tools.javac.main.JavaCompiler.enterTrees()
	- classEnter: Enter all classes, and construct uncompleted list. Return the types of the classes. All the class symbol are entered into enclosing scope. Generate uncompleted classes list.
	- typeEnter(memberEnter): complete all uncompleted classes and the members of the class. Generate todo list.
		- ImportPhase
		- HierarchyPhase: Add default superclass Object.
		- PermitsPhase
		- HeaderPhase
		- RecordPhase
		- MembersPhase: Add default constructor. Add `this` and `super` to symbol table. MemberEnter.

### Annotation processing. JavacProcessingEnvironment.
- Goal: Process annotation.
- Input: AST
- Output: Maybe some new source files along with new AST and todo list.
- procedure
	- com.sun.tools.javac.main.JavaCompiler.processAnnotations()
	- If this process generates new files, the compilation(scanner and parser)will restarted.

### Semantics. Code Analysis. Attr(check, Infer, Resolve) and Flow.
- Goal: Analyse the syntax trees
- Input: todo list, AST
- Output: AST(Attributed tree), Env list
- procedure
	- Attr(check, Infer, Resolve) analyzes names and expressions.
		- Attr and Enter cooperate and call each other.
	- Flow performs static program flow analysis. It checks reachability, definite assignment, definite unassignment.

### Code Simplification. Desugar. Lower, TransTypes, TreeTranslator.
- Goal: Analyse the syntax trees
- Input: AST(Attributed tree), Env list
- Output: pair(Env, classDesc) list
- procedure
	- Lower converts “syntactic sugar” constructions into simpler code. This includes inner classes, class literals, assertions, foreach loops, strings in switch, etc.
	- TransTypes eliminates (erases) generics from the program.

### Code generation. Gen, Code, Pool, CRTable, ClassWriter.
- Goal: Code generation. Generate class files.
- Input: pair(Env, classDesc) list
- Output: class files


## Where to use module 'java.compiler' in 'jdk.compiler'
- AnnotatedConstruct(java.compiler) --> Element(java.compiler)  and TypeMirror(java.compiler) 
	- Element(java.compiler) --> extended by Symbol(jdk.compiler) --> used by some JCTree(jdk.compiler)
	- TypeMirror(java.compiler) --> Type(jdk.compiler) --> use by Symbol(jdk.compiler) --> used by some JCTree(jdk.compiler)


## Old documentation
- 解析命令行参数  CommandLine、Arguments、Options、cmdLineHelper
- 初始化Log，初始化fileManager，初始化依赖 未仔细看
- 初始化插件 BasicJavacTask 未仔细看 
- 初始化多个release jar处理 Target 未仔细看
- 初始化java编译器 JavaCompiler
- 初始化docLink  BasicJavacTask
- 获取文件对象，获取类名 JavaFileObject、JavacFileManager
- 编译文件列表 JavaCompiler.compile
	- 词法分析，生成Token流，然后语法分析生成语法树(CompilationUnit)。
		Scanner Parser Enter TaskEvent.Kind.COMPILATION 
	- 初始化注解处理，然后注解处理
		可能产生新的代码和class文件，如果产生，则要重新语法分析。
		JavacProcessingEnvironment
	- 语义分析和字节码生成
		- 变量和引用等变量或符号标注 attribute
		- 数据和控制流分析 flow
		- 泛型解析 TransTypes
		- 解析语法糖 desugar Lower
		- 生成字节码 generate Gen

