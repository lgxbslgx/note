# perf代码

## 数据结构

### 进程（task_struct）

每个进程（task）有一个事件上下文（perf_event_context）。

```c
struct task_struct {
    ...
    struct perf_event_context *perf_event_ctxp;
    ...
};
```

### 事件上下文（perf_event_context）

每个事件上下文（perf_event_context）包含多个事件（perf_event）。

```c
struct perf_event_context {
    ...
    struct list_head            event_list; // 连接所有属于当前上下文的事件的列表
    int                         nr_events;  // 属于当前上下文的所有事件的总数
    ...
    struct task_struct          *task;      // 当前上下文属于的进程
    ...
};
```

### 事件（perf_event）

每个事件（perf_event）有触发次数、属性、pmu等内容。

```c
struct perf_event {
    ...
    struct list_head                event_entry;
    const struct pmu                *pmu;   // 事件所属的PMU
    enum perf_event_active_state    state;
    atomic64_t                      count;  // 事件被触发的次数
    ...
    struct perf_event_attr          attr;   // 事件的属性（由用户提供）
    struct hw_perf_event            hw;     // 对应的perf硬件事件
    struct perf_event_context       *ctx;   // 事件所属的上下文
    ...
};
```

### pmu（Performance Monitoring Unit）

不同类型的事件有不同的pmu类型，每个pmu类型都有自己的实现函数（启用、禁用、运行）。
比如CPU时钟事件对应的PMU为perf_ops_cpu_clock。

- 当要启用一个 CPU 时钟事件时，内核将会调用 cpu_clock_perf_event_enable() 函数来启用这个事件。
- 当要禁用一个 CPU 时钟事件时，内核将会调用 cpu_clock_perf_event_disable() 函数来禁用这个事件。
- 当事件被触发时，内核将会调用 cpu_clock_perf_event_read() 函数来进行特定的动作。

进程被调度运行的时候，启用对应的事件。进程被调度出去（停止运行）的时候，禁用对应事件。

```c
struct pmu {
    int (*enable)   (struct perf_event *event); // 启用事件
    void (*disable) (struct perf_event *event); // 禁用事件
    void (*read)    (struct perf_event *event); // 运行事件
    ...
};

static const struct pmu perf_ops_cpu_clock = { // CPU时钟事件对应的PMU
    .enable  = cpu_clock_perf_event_enable,
    .disable = cpu_clock_perf_event_disable,
    .read    = cpu_clock_perf_event_read,
};
```

## 代码运行

### 启用事件

进程被调度运行的时候，启用对应的事件，流程如下所示。

```c
schedule()
  context_switch()
    finish_task_switch()
      perf_event_task_sched_in()
        __perf_event_sched_in()
          group_sched_in()
            event_sched_in()
              event->pmu->enable()
                cpu_clock_perf_event_enable() // CPU时钟事件对应的启动函数
```

启用函数cpu_clock_perf_event_enable的具体实现如下：

```c
static int
cpu_clock_perf_event_enable(struct perf_event *event)
{
    ...
    perf_swevent_start_hrtimer(event);

    return 0;
}

static void
perf_swevent_start_hrtimer(struct perf_event *event)
{
    struct hw_perf_event *hwc = &event->hw;

    // 初始化一个定时器，定时器的回调函数为：perf_swevent_hrtimer()
    hrtimer_init(&hwc->hrtimer, CLOCK_MONOTONIC, HRTIMER_MODE_REL);
    hwc->hrtimer.function = perf_swevent_hrtimer;

    if (hwc->sample_period) {
        ...

        // 启动定时器
        __hrtimer_start_range_ns(&hwc->hrtimer, ns_to_ktime(period), 0,
                                 HRTIMER_MODE_REL, 0);
    }
}
```

### 禁用事件

进程被调度出去（停止运行）的时候，禁用对应事件。和启用类似，这里不详细介绍。

### 运行事件

启用事件后，当事件被触发时，会调用事件对应的read函数来特定的动作。
以CPU时钟事件为例，定时器的回调函数为perf_swevent_hrtimer()，最终会调用cpu_clock_perf_event_read()函数，具体调用流程如下：

```c
static enum hrtimer_restart 
perf_swevent_hrtimer(struct hrtimer *hrtimer)
{
    enum hrtimer_restart ret = HRTIMER_RESTART;
    struct perf_sample_data data;
    struct pt_regs *regs;
    struct perf_event *event;
    u64 period;

    // 获取当前定时器所属的事件对象
    event = container_of(hrtimer, struct perf_event, hw.hrtimer);

    // 前面说过，如果是CPU时钟事件，将会调用 cpu_clock_perf_event_read() 函数
    event->pmu->read(event);

    data.addr = 0;
    // 获取定时器被触发时所有寄存器的值
    regs = get_irq_regs();

    ...
    if (regs) {
        if (!(event->attr.exclude_idle && current->pid == 0)) {
            // 最重要的地方：对数据进行采样
            if (perf_event_overflow(event, 0, &data, regs))
                ret = HRTIMER_NORESTART;
        }
    }
    ...
    return ret;
}
```

采样逻辑调用链接为`perf_event_overflow -> __perf_event_overflow -> perf_event_output`

```c
static void
perf_event_output(struct perf_event *event, int nmi,
                  struct perf_sample_data *data,
                  struct pt_regs *regs)
{
    struct perf_output_handle handle;
    struct perf_event_header header;

    // 进行数据采样，并且把采样到的数据保存到data变量中
    perf_prepare_sample(&header, data, event, regs);
    ...

    // 把采样到的数据保存到环形缓冲区中
    perf_output_sample(&handle, &header, data, event);
    ...
}

void
perf_output_sample(struct perf_output_handle *handle,
                   struct perf_event_header *header,
                   struct perf_sample_data *data,
                   struct perf_event *event)
{
    u64 sample_type = data->type;
    ...

    // 1. 保存当前IP寄存器地址(用于获取正在执行的函数)
    if (sample_type & PERF_SAMPLE_IP)
        perf_output_put(handle, data->ip);

    // 2. 保存当前进程ID
    if (sample_type & PERF_SAMPLE_TID)
        perf_output_put(handle, data->tid_entry);

    // 3. 保存当前时间
    if (sample_type & PERF_SAMPLE_TIME)
        perf_output_put(handle, data->time);
    ...

    // n. 保存函数的调用链
    if (sample_type & PERF_SAMPLE_CALLCHAIN) {
        if (data->callchain) {
            int size = 1;

            if (data->callchain)
                size += data->callchain->nr;

            size *= sizeof(u64);

            perf_output_copy(handle, data->callchain, size);
        } else {
            u64 nr = 0;
            perf_output_put(handle, nr);
        }
    }
    ...
}
```

## 参考内容

- [一文看懂 Linux 性能分析｜perf 源码实现（超详细~）](https://zhuanlan.zhihu.com/p/573703139)
