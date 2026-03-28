# Spark Memory Management

## Memory Architecture Deep Dive

### Executor Memory Layout
```
┌─────────────────────────────────────────────────────────────┐
│                    Executor JVM Heap                        │
│                  (spark.executor.memory)                    │
├─────────────────────────────────────────────────────────────┤
│  Reserved Memory: 300MB (fixed)                             │
│  - Spark internal objects                                   │
├─────────────────────────────────────────────────────────────┤
│  User Memory: (heap - 300MB) * (1 - spark.memory.fraction)  │
│  - User data structures                                     │
│  - UDF allocations                                          │
│  - Internal metadata                                        │
├─────────────────────────────────────────────────────────────┤
│  Unified Memory: (heap - 300MB) * spark.memory.fraction     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Storage Memory                                       │   │
│  │ - Cached DataFrames/RDDs                            │   │
│  │ - Broadcast variables                                │   │
│  │ - Unroll memory (deserialization)                   │   │
│  ├─────────────────────────────────────────────────────┤   │
│  │ Execution Memory                                     │   │
│  │ - Shuffle buffers                                    │   │
│  │ - Sort buffers                                       │   │
│  │ - Hash tables (joins, aggregations)                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      Off-Heap Memory                        │
│               (spark.memory.offHeap.size)                   │
│  - Direct memory allocations                                │
│  - Tungsten optimized structures                            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Memory Overhead                          │
│             (spark.executor.memoryOverhead)                 │
│  - Container overhead                                       │
│  - PySpark interop                                          │
│  - Network buffers                                          │
└─────────────────────────────────────────────────────────────┘
```

## Memory Calculation

### Formula
```python
# Total container memory
container_memory = executor_memory + memoryOverhead + offHeap

# Usable heap
usable_memory = executor_memory - 300MB  # Reserved

# Unified memory pool
unified_memory = usable_memory * spark.memory.fraction  # Default 0.6

# Storage memory (soft boundary)
storage_memory = unified_memory * spark.memory.storageFraction  # Default 0.5

# Execution memory (soft boundary)
execution_memory = unified_memory * (1 - spark.memory.storageFraction)

# User memory
user_memory = usable_memory * (1 - spark.memory.fraction)  # Default 0.4
```

### Example Calculation
```
executor_memory = 8GB
memoryOverhead = 2GB (max(384MB, 0.1 * 8GB))

usable_memory = 8GB - 300MB = 7.7GB
unified_memory = 7.7GB * 0.6 = 4.62GB
  - storage_memory = 4.62GB * 0.5 = 2.31GB
  - execution_memory = 4.62GB * 0.5 = 2.31GB
user_memory = 7.7GB * 0.4 = 3.08GB

Total container = 8GB + 2GB = 10GB
```

## Memory Configuration

### Basic Configuration
```python
# Executor memory
spark.conf.set("spark.executor.memory", "8g")
spark.conf.set("spark.executor.memoryOverhead", "2g")

# Driver memory
spark.conf.set("spark.driver.memory", "4g")
spark.conf.set("spark.driver.memoryOverhead", "1g")

# Memory fractions
spark.conf.set("spark.memory.fraction", "0.6")
spark.conf.set("spark.memory.storageFraction", "0.5")
```

### Off-Heap Memory
```python
# Enable off-heap
spark.conf.set("spark.memory.offHeap.enabled", "true")
spark.conf.set("spark.memory.offHeap.size", "2g")
```

Benefits:
- Reduced GC pressure
- Better memory utilization for large operations
- Required for some columnar operations

### Memory Overhead
```python
# YARN container overhead
spark.conf.set("spark.executor.memoryOverhead", "2g")  # or 10% of executor memory

# For PySpark with pandas
spark.conf.set("spark.executor.pyspark.memory", "1g")  # Python process memory
```

## Unified Memory Management

### Memory Eviction
```
Execution needs more memory:
1. If execution < storage pool → use storage space
2. If storage has cached data → evict LRU cached blocks
3. If still not enough → spill to disk

Storage needs more memory:
1. If storage < execution pool → use execution space
2. Cannot evict execution memory (currently running tasks)
3. If not enough → spill cache to disk
```

### Configuring for Workload Types

#### Batch Processing (More Execution)
```python
spark.conf.set("spark.memory.fraction", "0.7")
spark.conf.set("spark.memory.storageFraction", "0.3")
```

#### Iterative/ML (More Storage)
```python
spark.conf.set("spark.memory.fraction", "0.6")
spark.conf.set("spark.memory.storageFraction", "0.6")
```

#### Streaming (Balanced)
```python
spark.conf.set("spark.memory.fraction", "0.6")
spark.conf.set("spark.memory.storageFraction", "0.5")
```

## Spill Management

### Understanding Spill
Spill occurs when:
- Shuffle data exceeds execution memory
- Cached data exceeds storage memory
- Sort/aggregation buffers overflow

### Spill Configuration
```python
# Spill threshold (per task)
spark.conf.set("spark.shuffle.spill.numElementsForceSpillThreshold", "1000000")

# Disk I/O for spills
spark.conf.set("spark.local.dir", "/mnt/disk1,/mnt/disk2")  # Multiple disks

# Compression for spills
spark.conf.set("spark.shuffle.spill.compress", "true")
spark.conf.set("spark.io.compression.codec", "lz4")
```

### Detecting Spill
```
Spark UI → Stages → Click on stage → Task Metrics

Look for:
- Spill (Memory): Data spilled from memory
- Spill (Disk): Data written to disk

High spill indicates:
- Need more executor memory
- Need more partitions (smaller tasks)
- Data skew
```

## Garbage Collection

### GC Tuning
```python
# Use G1GC for large heaps
spark.conf.set("spark.executor.extraJavaOptions",
    "-XX:+UseG1GC "
    "-XX:InitiatingHeapOccupancyPercent=35 "
    "-XX:ConcGCThreads=4 "
    "-XX:ParallelGCThreads=8 "
    "-XX:G1HeapRegionSize=16m "
    "-XX:+UnlockDiagnosticVMOptions "
    "-XX:G1SummarizeRSetStatsPeriod=1"
)
```

### GC Monitoring
```
Spark UI → Executors → GC Time

Target: GC Time < 10% of Task Time

High GC indicates:
- Too much data in memory
- Large user objects
- String/object heavy operations
```

### Reducing GC Pressure
```python
# Use off-heap memory
spark.conf.set("spark.memory.offHeap.enabled", "true")

# Use columnar format (Tungsten)
# DataFrames automatically use this

# Avoid Python UDFs (use Pandas UDFs)
# Use built-in functions
```

## Memory Errors

### OutOfMemoryError

#### Executor OOM
```
Symptoms:
- java.lang.OutOfMemoryError: Java heap space
- Executor lost
- Task failures

Solutions:
1. Increase spark.executor.memory
2. Increase spark.executor.memoryOverhead
3. Increase partition count (smaller tasks)
4. Reduce spark.memory.storageFraction
```

#### Driver OOM
```
Symptoms:
- Driver out of memory
- collect() fails
- Broadcast too large

Solutions:
1. Increase spark.driver.memory
2. Avoid collect() on large datasets
3. Use df.take(n) or df.show()
4. Reduce broadcast threshold
```

### Container Killed by YARN
```
Symptoms:
- "Container killed by YARN for exceeding memory limits"
- Executor frequently lost

Solutions:
1. Increase spark.executor.memoryOverhead
2. If using PySpark: increase spark.executor.pyspark.memory
3. Reduce off-heap operations
```

### MetadataFetchFailedException
```
Symptoms:
- Shuffle files missing
- Tasks failing with metadata errors

Solutions:
1. Enable shuffle service
2. Increase spark.reducer.maxBlocksInFlightPerAddress
3. Increase spark.shuffle.io.maxRetries
4. Check disk space on workers
```

## Memory Profiling

### JVM Profiling
```python
# Enable JVM profiling
spark.conf.set("spark.executor.extraJavaOptions",
    "-XX:+HeapDumpOnOutOfMemoryError "
    "-XX:HeapDumpPath=/tmp/heapdump"
)
```

### Memory Metrics
```python
# Get storage memory usage
spark.sparkContext._jsc.sc().getExecutorMemoryStatus()

# Cache metrics
spark.catalog.isCached("table_name")
df.storageLevel
```

### Monitoring Queries
```python
# Check cached tables
spark.sql("SHOW TABLES").show()
spark.catalog.listTables()

# Clear specific cache
spark.catalog.uncacheTable("table_name")

# Clear all cache
spark.catalog.clearCache()
```

## Memory Best Practices

### Do's
1. **Right-size executors**: 4-8 cores, 4-8GB memory per executor
2. **Enable off-heap** for large shuffle/aggregation workloads
3. **Monitor GC time** and tune if > 10% of task time
4. **Use DataFrames** over RDDs for better memory efficiency
5. **Cache strategically** after expensive operations
6. **Unpersist** when cache is no longer needed

### Don'ts
1. **Don't collect** large datasets to driver
2. **Don't broadcast** tables larger than 100MB
3. **Don't use Python UDFs** for heavy operations
4. **Don't cache before filtering**
5. **Don't ignore spill metrics**
6. **Don't over-provision** memory (waste resources)

### Configuration Template
```python
# Executor sizing (per executor)
num_cores = 5
memory_per_core = 2  # GB
executor_memory = num_cores * memory_per_core  # 10GB

spark.conf.set("spark.executor.cores", str(num_cores))
spark.conf.set("spark.executor.memory", f"{executor_memory}g")
spark.conf.set("spark.executor.memoryOverhead", f"{max(384, executor_memory * 0.1 * 1024)}m")

# Memory fractions
spark.conf.set("spark.memory.fraction", "0.6")
spark.conf.set("spark.memory.storageFraction", "0.5")

# Off-heap
spark.conf.set("spark.memory.offHeap.enabled", "true")
spark.conf.set("spark.memory.offHeap.size", "2g")

# GC tuning
spark.conf.set("spark.executor.extraJavaOptions",
    "-XX:+UseG1GC -XX:InitiatingHeapOccupancyPercent=35")
```
