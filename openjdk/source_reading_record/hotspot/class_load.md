### class load
- loading
- linking
	- verifiication
	- preparation
	- resolution
- initialization


### procedure
- jvm
	jvm_define_class_common 
- systemDictionary
	parse_stream
	- KlassFactory
		create_from_stream uses ClassFileParser parse_stream
	- instanceKlass
		link_class uses verifier verify
	- instanceKlass
		eager_initialize

### 基础层次
ClassFileParser::parse_stream、create_instance_klass等方法提供具体的操作 ->
KlassFactory::create_from_stream作为整体对外的Klass“工厂” ->
ClassLoader::load_class代表 bootstrap类加载器 加载类、
SystemDictionary::resolve_*_from_stream等方法根据传入的加载器加载类 ->
SystemDictionary::load_instance_class*等方法和resolve_or_*等方法根据类加载器、使用上一步2个方式resolve（解析）、load（加载）类



