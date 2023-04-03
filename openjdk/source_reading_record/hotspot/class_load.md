## class load
- loading
- linking
	- verifiication
	- preparation
	- resolution
- initialization

## 类加载器
- `ClassLoaderDataGraph`里面是一个链表，把所有`ClassLoaderData`连起来。
- `ClassLoaderData`表示一个类加载器
  - `OopHandle  _class_loader`表示一个对应的Java中`ClassLoader`（或它的子类）的对象
  - `WeakHandle _holder`决定该类加载器生命周期的Java对象，与隐藏类有关。不使用非strong隐藏类时和`_class_loader`一样，使用非strong隐藏类时，就指向隐藏类Klass对应的java mirror对象。
  - `ClassLoaderMetaspace * _metaspace`指向该类加载器对应的元空间

- `ClassLoaderMetaspace`，有2个`MetaspaceArena`对应类和非类数据的元空间区域
  - `metaspace::MetaspaceArena* _non_class_space_arena`
  - `metaspace::MetaspaceArena* _class_space_arena`

- `MetaspaceArena`负责元空间区域与元空间交互
  - `ChunkManager* _chunk_manager`块管理器，`MetaspaceArena`就是通过它与元空间交互
  - `MetachunkList _chunks`当前有数据的块`MetaChunk`组成的链表
  - `FreeBlocks* _fbl`存储被该类加载器回收的块，注意这里的块不是`MetaChunk`，而是更小粒度的`block`。因为这些小块不能立即直接被返回给元空间，类加载器就把它存起来重用。

- `FreeBlocks`
  - `BinList32 _small_blocks`小块用链表连接起来（每种大小一个链表，这里类似`MetachunkList _freelist`），这里的`block`连接方式是内置的链表式，类似`Arena`的块。获取速度很快
  - `BlockTree _tree`大块用二叉搜索树保存起来，但是这棵树不做平衡处理，同样大小的block用一个链表连接起来。

## 类加载器与元空间交互
类加载器`ClassLoaderData`使用了`metaspace`:
- 块相关
  - `ChunkManager::get_chunk`被`ClassLoaderData`的`ClassLoaderMetaspace::MetaspaceArena::allocate_new_chunk和allocate`使用
  - `ChunkManager::return_chunk`被`MetaspaceArena::~MetaspaceArena`析构函数使用，在GC后，`delete ClassLoaderData`时被调用
  - `ChunkManager::purge`被`ClassLoaderDataGraph::purge`，最终被GC使用
- 具体空间分配相关
  - `Metaspace::allocate`被`MetaspaceObj::operator new`使用，用于分配继承`MetaspaceObj`的类的对象。

## 类加载器接口（MetadataFactory）
类加载器从元空间拿到块`MetaChunk`之后，向上层（就是下面写的内容）提供自己的接口。
- 底层接口
  - `ClassLoaderMetaspace::allocate`和`MetaspaceArena::allocate`: 分配空间
  - `ClassLoaderMetaspace::deallocate`和`MetaspaceArena::deallocate`: 回收空间
- 对外接口
  - `MetadataFactory::new_array`和各个继承`MetaspaceObj`的对象的`new`操作会调用`ClassLoaderMetaspace::allocate`方法
  - `MetadataFactory::free_array/free_metadata`会调用`ClassLoaderMetaspace::deallocate`方法

## 加载一个类的方法调用层次

- 具体操作
`ClassFileParser::parse_stream、create_instance_klass`等方法提供具体的操作

- 对外接口
`KlassFactory::create_from_stream`作为整体对外的Klass“工厂”

- 2种方式（对应启动类加载器和其他加载器）
`ClassLoader::load_class`代表 bootstrap类加载器 加载类、
`SystemDictionary::resolve_*_from_stream`等方法根据传入的加载器加载类

- 外层使用
`SystemDictionary::load_instance_class*`等方法和`resolve_or_*`等方法
根据类加载器、使用上一步2个方式加载类

开启类数据共享时，还有SystemDictionary::load_shared*等方法可以加载类。

## Klass-oop
```
Klass
  ArrayKlass
    ObjArrayKlass
	TypeArrayKlass
  InstanceKlass
    InstanceClassLoaderKlass
	InstanceMirrorKlass
	InstanceRefKlass
	InstanceStackChunkKlass
```
```
oopDesc
  arrayOopDesc
    objArrayOopDesc
	typeArrayOopDesc
  instanceOopDesc
    stackChunkOopDesc
```

### 两者关系
- 一个`Klass`对应多个其类型的`oopDesc`
- `Klass`有一个字段`_java_mirror`指向`Class`类的一个`oopDesc`
- `InstanceClassLoaderKlass`（ClassLoader及其子类）对应的`oopDesc`有一个隐藏字段，指向其类加载器数据`ClassLoaderData`

### Klass
- 类继承树的表示：可以正向，从父类（根节点是Object）指向子类，但是这样因为子类太多而不好存储和遍历。所以`Klass`中存储的是反向信息，从子类指向父类。每个`klass`有一个父类`Klass*      _super`、一个子类`Klass* _subklass`、下一个兄弟姐妹`Klass* _next_sibling`。但是这里表示不了它实现的接口`interface`。
- `Klass`有几个字段用于快速判断父子关系，这里存储了接口信息，也是反向的。主要有`_super_check_offset`，`_secondary_super_cache`， `_secondary_supers`，`_primary_supers`等
- `Klass`字段`ClassLoaderData* _class_loader_data`指向它的类加载器，`Klass*      _next_link`指向同属一个类加载器的下一个`Klass`

如果是`ArrayKlass`，则有数组维度`_dimension`，高维数组`Klass* _higher_dimension`，低维数组`Klass* _lower_dimension`等。

如果是`InstanceKlass`，有很多信息:
- 注解信息、包信息、常量池、嵌套成员/内部类/外部类、permmitted类（封闭类有的信息）、record components（记录类有的信息）、方法信息、等等

- 最后附加的信息为：
```
  // embedded Java vtable follows here 虚函数表 klassVtable、vtableEntry
  // embedded Java itables follows here 接口函数表 klassItable、itableMethodEntry
  // embedded nonstatic oop-map blocks follows here 非静态字段的oop偏移量对应关系 (offset, length)
  // embedded implementor of this interface follows here 实现这个接口的类的指针
```

### oop
内存布局
```
  volatile markWord _mark; // 对象头
  union _metadata {
    Klass*      _klass;
    narrowKlass _compressed_klass;
  } _metadata;  // 指向klass
  // 数组长度，如果是arrayOopDesc及子类，这里就是数组长度
  // 对象具体字段（先存父类，再存子类）
  // 对象隐藏字段（虚拟机自己加的）
```
注意: 对象隐藏字段在文件`javaClasses.hpp`中全部列出了（列出了偏移量）。

## 类加载操作
也就是`ClassFileParser::parse_stream、create_instance_klass`等方法的具体步骤。

### 方法`ClassFileParser::parse_stream`
一个`LL parser`，只是里面加了很多与parser无关的操作，这种加操作的行为类似于`syntax directed`。
按照class文件格式来解析，class文件内容主要存放在类`ClassFileParser`中，
下文没特别说明的话，`获取`到的内容都默认放在`ClassFileParser`中。

- 获取魔数并检验魔数
- 获取minor和major版本并校检(注意: JDK12及以后`minor`只能是0或65535)（注意: minor版本号在前面）
- 获取常量池条数并校检（它实际是`常量池条数+1`，一定要>=1，第0项保留）
- 新建常量池`ConstantPool`对象，初始化了tags（一个和条数相同的数组）。注意: `ConstantPool`对象最后面还有一个和条数相同的表示常量池具体内容的数组。
- 处理常量池`ClassFileParser::parse_constant_pool`
  - 不断获取常量池内容，根据tag类型（**17种**，没有编号2、13、14），初始化`ConstantPool`对象的tags和具体内容，一般都是一些index和基本数据类型的值。特殊: utf8的数据`JVM_CONSTANT_Utf8`要存到符号表`SymbolTable`中，所以utf8条目存的是一个符号指针`Symbol*`。
  - 验证常量池内容是否正确（各种index是否指向正确的条目等）、类条目内容变成数组`Array<Klass*>*       _resolved_klasses`的下标、字符串条目内容变成符号指针`Symbol*`
  - 验证各种字符串是否符合规定
- 获取和验证flags
- 获取并验证类名，验证index是否有效和名称是否一致
- 获取父类，验证index是否有效，和获取常量池对应的Klass，注意这里的Klass可能为空
- 获取父接口，验证index是否有效，和获取常量池对应的Klass，这里的Klass一定不为空
- 获取字段`ClassFileParser::parse_fields`
  - 获取class文件中原有的字段数量
  - 获取虚拟机添加的字段数量（注入（`injected`）字段所有信息在`javaClasses`）
  - 创建字段数组，用于存取字段信息
  - 获取class文件中原有的字段
    - 获取字段flags并验证
    - 获取字段名字并验证
    - 获取字段描述符（字段类型的规范化表示，`BCSIJFDZVL;[`）并验证
    - 获取字段属性（6种：常量值、是否是合成的、是否弃用、泛型类型信息Signature、注解、类型注解），大部分信息在`ClassFileParser::GrowableArray<FieldInfo>* _temp_field_info`，注解放在`ClassFileParser::Array<AnnotationArray*>* _fields_annotations，* _fields_type_annotations;`。
  - 处理注入（injected）字段信息
- 获取方法`ClassFileParser::parse_methods`，信息放在`ClassFileParser::Array<Method*>* _methods`
  - 获取方法数量
  - 获取各个方法
    - 获取方法flags
    - 获取方法名字并验证
    - 获取方法描述符（方法类型的规范化表示，`BCSIJFDZVL;[()`）并验证
    - 获取方法属性（10种）
- 获取属性`ClassFileParser::parse_classfile_attributes`(一共30种属性，其中类属性14种)，信息放在`ClassFileParser`

### 方法`post_process_parsed_stream`
- 确保父类已加载（父类在上面可能未加载，和上面解析父类的逻辑相对应）
- 获取所有实现的接口（接口在上面已经加载了）
- 对方法进行排序（排序指针？为了方便之后搜索？）
- 计算vtable大小（父类的vtable+自己新加的方法，注意静态调配dispatch的方法、重写override的方法、miranda方法（即接口有的未实现的方法））
- 计算itable大小
- 计算静态、非静态字段的存储信息，`FieldLayoutInfo* _field_info`、`Array<u1>* _fieldinfo_stream`等
  - 获取父类所有非静态字段，放到`FieldLayout* _layout`中
    - 获取所有父类的非静态字段（每次都获取所有祖先的字段，很奇怪，应该只需要获取直接父类的？）
    - 进行offset排序
    - 获取中间空的位置（注意empty和padding的区别）
  - 获取当前类的静态、非静态（包括自定义组）字段
    - 静态字段，放到组`FieldLayoutBuilder::FieldGroup* _static_fields`
    - 非静态字段，放到组`FieldLayoutBuilder::FieldGroup* _root_group`
    - 自定义的`Contented`组，放到`FieldLayoutBuilder::GrowableArray<FieldGroup*> _contended_groups`
  - 对当前类的静态、非静态（包括自定义组）字段进行排序
    - 只对primitive原子类型的字段进行排序
    - 分组排序（`_static_fields`、`_root_group`、`_contended_groups`的很多组）
    - 按占用空间的大小排序，**大的排前面**
  - 把当前类的字段信息加到`FieldLayout* _layout`（这里之前已有父类信息）和`FieldLayout* _static_layout`中
    - 加的位置: 每次都找前面的位置，有空位就加进去(而且是找最合适的块，不是最近的块)
    - 有`Contented`注解的类，加padding到`FieldLayout* _layout`
    - 把`_root_group`的`primitive`原子字段加到`FieldLayout* _layout`
    - 把`_root_group`的`oop`引用字段加到`FieldLayout* _layout`（注意引用字段是最后才加，这样整个对象数据就是对齐的了）
    - 循环操作，把`_contended_groups`的各个组的内容添加到`FieldLayout* _layout`
      - `Contented`的padding
      - `primitive`原子字段加到`FieldLayout* _layout`
      - `oop`引用字段加到`FieldLayout* _layout`（注意引用字段是最后才加，这样整个对象数据就是对齐的了）
    - 如果需要（就是前面加了，这里也要加），再加一个`Contented`的padding
    - 把`_static_fields`的`oop`引用字段加到`FieldLayout* _static_layout`
    - 把`_static_fields`的`primitive`原子字段加到`FieldLayout* _static_layout`（注意这里的oop和primitive的顺序和前面的相反，因为这里的内容是放在`Klass`里面的，不用对齐，后面直接加内容就行了）
  - 计算nonstatic-oop-map(这里就只有字段信息了，没有padding、empty信息)
  - 最后设置`FieldLayoutInfo* _field_info`的信息
- 把上一步得到的信息写进`_fieldinfo_stream`

### 方法`ClassFileParser::create_instance_klass`
- 根据Klass类型创建`InstanceKlass`，方法`InstanceKlass::allocate_instance_klass`
- 设置`InstanceKlass`里面的内容，方法`ClassFileParser::fill_instance_klass`（很多内容）

## 类链接`InstanceKlass::link_class_impl`
- 链接父类
- 链接父接口
- 验证`InstanceKlass::verify_code`、`Verifier::verify`
- 重写`InstanceKlass::rewrite_class`
  - **建立方法index的map（constant pool cache <--> constant pool entries）**
  - 重写Object类的构造函数的`_return`为`_return_register_finalizer`，为了之后初始化`finalize`方法
  - 重写一些字节码`Rewriter::scan_method`
    - `_lookupswitch`改成`_fast_binaryswitch`或`_fast_linearswitch`
    - **修改方法index为constant pool cache index**，修改一些调用方法（`_invoke*`）为`_invokehandle`
    - 检查`_putstatic`、`_putfield`是否修改了final方法
    - 一些`_ldc`、`_ldc_w`改成`_fast_aldc`、`_fast_aldc_w`
  - **分配常量池cache`constant pool cache`**
  - `jsr`相关（不懂//TODO）
- 链接`InstanceKlass::link_method(s)`
   - 设置`从解释`入口（就是调用这个方法的代码是解释器代码）`_from_interpreted_entry`和`_i2i_entry`
   - 设置`从编译`入口（就是调用这个方法的代码是编译后的代码）`_from_compiled_entry`
- 初始化vtable
  - 把父类的vtable复制过来
  - 遍历自己的所有方法（过滤掉静态dispatch的方法等），找到vtable中名字和方法类型（signature）相同的条目，替换它（override）。如果没找到，则把条目放到后面新的位置。
  - 同样的方式遍历“默认方法”`default methods`，设置vtable的条目
  - 同样的方式遍历`mirandas`方法，不过其指向的方法`Method`是没有代码的
- 初始化itable
  - 遍历各个接口，设置itable条目

## 类初始化`InstanceKlass::initialize/initialize_impl`
- 确保类已链接（link）
- 各种判断
- 确保父类已初始化
- 确保父接口已经初始化
- 执行类初始化器，就是调用`<clint>`方法。（`JavaCalls::call`）


