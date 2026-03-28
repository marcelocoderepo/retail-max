# Apache Spark Knowledge Base Overview

## What is Apache Spark?

Apache Spark is a unified analytics engine for large-scale data processing. It provides high-level APIs in Java, Scala, Python, and R, and an optimized engine that supports general computation graphs for data analysis.

## Core Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Spark Application                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────┐   │
│  │                    Driver Program                    │   │
│  │  ┌─────────────┐  ┌──────────────────────────────┐ │   │
│  │  │ SparkContext│  │  DAG Scheduler + Task Sched  │ │   │
│  │  └─────────────┘  └──────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  │
│  │   Executor    │  │   Executor    │  │   Executor    │  │
│  │ ┌───┐ ┌───┐  │  │ ┌───┐ ┌───┐  │  │ ┌───┐ ┌───┐  │  │
│  │ │T1 │ │T2 │  │  │ │T3 │ │T4 │  │  │ │T5 │ │T6 │  │  │
│  │ └───┘ └───┘  │  │ └───┘ └───┘  │  │ └───┘ └───┘  │  │
│  │   [Cache]    │  │   [Cache]    │  │   [Cache]    │  │
│  └───────────────┘  └───────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Spark Components

### Core Components
| Component | Purpose |
|-----------|---------|
| **Spark Core** | Base engine, RDD API, task scheduling |
| **Spark SQL** | Structured data processing, DataFrames |
| **Spark Streaming** | Real-time data processing |
| **MLlib** | Machine learning library |
| **GraphX** | Graph processing |

### Execution Model
1. **Driver**: Orchestrates the application, creates SparkContext
2. **Cluster Manager**: Allocates resources (YARN, Kubernetes, Standalone)
3. **Executors**: Run tasks and store data
4. **Tasks**: Smallest unit of work

## DataFrames & Datasets

### DataFrame Creation
```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("MyApp") \
    .config("spark.sql.adaptive.enabled", "true") \
    .getOrCreate()

df = spark.read.parquet("s3://bucket/data/")
df = spark.read.json("path/to/data.json")
df = spark.read.csv("data.csv", header=True, inferSchema=True)
```

### DataFrame Operations
```python
df.select("col1", "col2")
df.filter(df.col1 > 100)
df.groupBy("category").agg({"amount": "sum"})
df.join(other_df, "key")
df.orderBy("col1", ascending=False)
df.withColumn("new_col", df.col1 * 2)
```

## Execution Plan & Optimization

### Physical Plan Stages
```
Query → Parsed Plan → Analyzed Plan → Optimized Plan → Physical Plan → Execution
         (Parser)     (Analyzer)       (Catalyst)       (Planner)
```

### Viewing Execution Plans
```python
df.explain()           # Simple plan
df.explain(True)       # Extended plan
df.explain("formatted") # Formatted output
df.explain("cost")     # With cost estimates
```

## Memory Architecture

### Memory Regions
```
┌─────────────────────────────────────────┐
│           Executor Memory               │
├─────────────────────────────────────────┤
│  Reserved Memory (300MB)                │
├─────────────────────────────────────────┤
│  User Memory (40%)                      │
│  - User data structures                 │
│  - Internal metadata                    │
├─────────────────────────────────────────┤
│  Unified Memory (60%)                   │
│  ┌─────────────────────────────────┐   │
│  │ Storage Memory (50%)            │   │
│  │ - Cached RDDs/DataFrames        │   │
│  │ - Broadcast variables           │   │
│  ├─────────────────────────────────┤   │
│  │ Execution Memory (50%)          │   │
│  │ - Shuffle buffers               │   │
│  │ - Join/Sort/Aggregation         │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Memory Configuration
```python
spark.executor.memory = "4g"
spark.memory.fraction = 0.6
spark.memory.storageFraction = 0.5
spark.memory.offHeap.enabled = true
spark.memory.offHeap.size = "2g"
```

## Partitioning

### Partition Concepts
- **Input Partitions**: Based on source data splits
- **Shuffle Partitions**: Result of shuffles (default: 200)
- **Output Partitions**: Written file structure

### Partition Operations
```python
df.rdd.getNumPartitions()
df.repartition(100)           # Full shuffle
df.coalesce(10)               # No shuffle, reduce only
df.repartition("key_column")  # Partition by column
```

### Optimal Partition Size
```
Target: 128MB - 256MB per partition
Rule: partition_count = data_size_mb / 128
```

## Shuffle Operations

### What Causes Shuffles
- `groupBy`, `reduceByKey`, `aggregateByKey`
- `join`, `cogroup`
- `repartition`, `coalesce` (sometimes)
- `distinct`, `sortByKey`

### Shuffle Configuration
```python
spark.sql.shuffle.partitions = 200
spark.shuffle.compress = true
spark.shuffle.file.buffer = "64k"
spark.reducer.maxSizeInFlight = "48m"
```

## Adaptive Query Execution (AQE)

### Enable AQE (Spark 3.0+)
```python
spark.sql.adaptive.enabled = true
spark.sql.adaptive.coalescePartitions.enabled = true
spark.sql.adaptive.skewJoin.enabled = true
spark.sql.adaptive.localShuffleReader.enabled = true
```

### AQE Features
| Feature | Description |
|---------|-------------|
| Dynamic Partition Coalescing | Merges small partitions |
| Dynamic Join Strategy | Switches to broadcast join if small |
| Skew Join Optimization | Splits skewed partitions |

## Join Strategies

### Join Types
| Strategy | When Used | Data Movement |
|----------|-----------|---------------|
| Broadcast Hash Join | Small table < 10MB | Broadcast small side |
| Sort Merge Join | Large tables | Shuffle both sides |
| Shuffle Hash Join | Medium tables | Shuffle + hash build |
| Broadcast Nested Loop | Cartesian products | Broadcast one side |

### Force Broadcast
```python
from pyspark.sql.functions import broadcast

large_df.join(broadcast(small_df), "key")

# Or via hint
large_df.join(small_df.hint("broadcast"), "key")
```

## Caching & Persistence

### Storage Levels
| Level | Memory | Disk | Serialized | Replicated |
|-------|--------|------|------------|------------|
| MEMORY_ONLY | Yes | No | No | No |
| MEMORY_AND_DISK | Yes | Yes | No | No |
| MEMORY_ONLY_SER | Yes | No | Yes | No |
| DISK_ONLY | No | Yes | Yes | No |
| MEMORY_AND_DISK_2 | Yes | Yes | No | Yes |

### Cache Operations
```python
df.cache()                    # MEMORY_AND_DISK
df.persist(StorageLevel.MEMORY_ONLY)
df.unpersist()
spark.catalog.clearCache()
```

## Key Configuration Parameters

### Core Parameters
```python
spark.app.name = "MyApplication"
spark.master = "yarn"
spark.driver.memory = "4g"
spark.executor.memory = "8g"
spark.executor.cores = 5
spark.executor.instances = 10
```

### SQL Parameters
```python
spark.sql.shuffle.partitions = 200
spark.sql.autoBroadcastJoinThreshold = 10485760  # 10MB
spark.sql.adaptive.enabled = true
spark.sql.files.maxPartitionBytes = 134217728   # 128MB
```

## Performance Monitoring

### Spark UI Tabs
| Tab | Information |
|-----|-------------|
| Jobs | Job DAG, stages, tasks |
| Stages | Stage details, shuffle metrics |
| Storage | Cached RDDs/DataFrames |
| Environment | Configuration |
| Executors | Executor health, memory |
| SQL | Query plans, metrics |

### Key Metrics to Monitor
- **Task Duration Distribution**: Look for skew
- **Shuffle Read/Write**: Network I/O
- **GC Time**: JVM garbage collection
- **Spill (Memory → Disk)**: Memory pressure
- **Input/Output Records**: Data volume

## Related KB Files
- [01-performance-tuning.md](01-performance-tuning.md) - Optimization guide
- [02-memory-management.md](02-memory-management.md) - Memory configuration
- [03-partitioning-shuffle.md](03-partitioning-shuffle.md) - Data distribution
- [04-join-optimization.md](04-join-optimization.md) - Join strategies
- [05-best-practices.md](05-best-practices.md) - Production patterns
