# Spark Partitioning & Shuffle

## Understanding Partitioning

### What is a Partition?
A partition is a logical chunk of data that can be processed independently. Partitions enable parallel processing across cluster nodes.

```
┌─────────────────────────────────────────────────────────────┐
│                    DataFrame (1TB)                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │ Part 0  │ │ Part 1  │ │ Part 2  │ │ Part N  │   ...    │
│  │ (128MB) │ │ (128MB) │ │ (128MB) │ │ (128MB) │          │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘          │
│       ↓           ↓           ↓           ↓                │
│   Executor 1  Executor 2  Executor 1  Executor 3          │
└─────────────────────────────────────────────────────────────┘
```

### Partition Types

| Type | When Created | Characteristics |
|------|--------------|-----------------|
| Input | Reading data | Based on file splits |
| Shuffle | After shuffle ops | Configurable count |
| Output | Writing data | Based on partition columns |

## Partition Configuration

### Input Partitions
```python
# Max partition size for file reads
spark.conf.set("spark.sql.files.maxPartitionBytes", "134217728")  # 128MB

# Min partition size
spark.conf.set("spark.sql.files.minPartitionNum", "1")

# Open cost in bytes (treats small files as larger)
spark.conf.set("spark.sql.files.openCostInBytes", "4194304")  # 4MB
```

### Shuffle Partitions
```python
# Default shuffle partitions
spark.conf.set("spark.sql.shuffle.partitions", "200")

# With AQE (adaptive)
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.minPartitionNum", "1")
spark.conf.set("spark.sql.adaptive.advisoryPartitionSizeInBytes", "268435456")  # 256MB
```

## Partition Operations

### Checking Partitions
```python
# Number of partitions
df.rdd.getNumPartitions()

# Partition distribution
from pyspark.sql.functions import spark_partition_id, count

df.groupBy(spark_partition_id().alias("partition_id")) \
    .agg(count("*").alias("record_count")) \
    .orderBy("record_count", ascending=False) \
    .show()
```

### Repartition
Full shuffle - can increase or decrease partitions.

```python
# By number
df.repartition(100)

# By column (hash partitioning)
df.repartition("customer_id")

# By both
df.repartition(100, "customer_id")

# Range partitioning
df.repartitionByRange(100, "date")
```

### Coalesce
No shuffle - can only decrease partitions.

```python
# Reduce partitions without shuffle
df.coalesce(10)

# Common pattern: filter then coalesce
df.filter(col("status") == "active") \
    .coalesce(10)  # Reduce after filtering
```

### When to Use Each

| Operation | Use When |
|-----------|----------|
| `repartition(n)` | Need specific partition count, increase partitions |
| `repartition(cols)` | Need data co-located by key |
| `coalesce(n)` | Reduce partitions after filter |
| `repartitionByRange` | Need sorted partitions |

## Shuffle Deep Dive

### What Triggers Shuffle?
```
Wide Transformations (require shuffle):
- groupBy, groupByKey
- reduceByKey, aggregateByKey
- join, cogroup
- sortBy, orderBy
- repartition
- distinct

Narrow Transformations (no shuffle):
- map, filter, flatMap
- select, withColumn
- union (if same partitioner)
- coalesce (decrease only)
```

### Shuffle Process
```
┌─────────────────────────────────────────────────────────────┐
│                      Shuffle Process                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Map Side                           Reduce Side             │
│  ┌─────────────┐                   ┌─────────────┐         │
│  │  Partition  │                   │  Partition  │         │
│  │  (Task 1)   │ ──────────────→  │  (Task A)   │         │
│  └─────────────┘    Shuffle        └─────────────┘         │
│  ┌─────────────┐    Write/Read     ┌─────────────┐         │
│  │  Partition  │ ──────────────→  │  Partition  │         │
│  │  (Task 2)   │                   │  (Task B)   │         │
│  └─────────────┘                   └─────────────┘         │
│                                                             │
│  1. Map tasks partition output data                        │
│  2. Data written to local disk (shuffle write)             │
│  3. Reduce tasks fetch data from all mappers               │
│  4. Data read into memory (shuffle read)                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Shuffle Configuration
```python
# Shuffle partitions
spark.conf.set("spark.sql.shuffle.partitions", "200")

# Shuffle compression
spark.conf.set("spark.shuffle.compress", "true")
spark.conf.set("spark.io.compression.codec", "lz4")  # or snappy, zstd

# Shuffle file consolidation
spark.conf.set("spark.shuffle.consolidateFiles", "true")

# Shuffle spill
spark.conf.set("spark.shuffle.spill", "true")
spark.conf.set("spark.shuffle.spill.compress", "true")

# Shuffle memory buffer
spark.conf.set("spark.shuffle.file.buffer", "64k")
spark.conf.set("spark.reducer.maxSizeInFlight", "96m")

# Shuffle retries
spark.conf.set("spark.shuffle.io.maxRetries", "3")
spark.conf.set("spark.shuffle.io.retryWait", "5s")
```

### External Shuffle Service
```python
# Enable for dynamic allocation
spark.conf.set("spark.shuffle.service.enabled", "true")
spark.conf.set("spark.shuffle.service.port", "7337")

# Benefits:
# - Allows executor decommissioning
# - Shuffle files survive executor loss
# - Required for dynamic allocation
```

## Optimizing Partitions

### Optimal Partition Size
```python
# Target: 128MB - 256MB per partition

# Formula
data_size_gb = 100
target_size_mb = 128
optimal_partitions = (data_size_gb * 1024) / target_size_mb  # 800

# Alternative: based on cores
total_cores = executors * cores_per_executor
optimal_partitions = total_cores * 2  # to 4
```

### Partition Count Guidelines

| Data Size | Recommended Partitions |
|-----------|------------------------|
| < 1GB | 2-8 |
| 1-10GB | 8-100 |
| 10-100GB | 100-1000 |
| 100GB-1TB | 1000-4000 |
| > 1TB | 4000+ |

### Avoiding Partition Skew
```python
# Check for skew
df.groupBy(spark_partition_id()) \
    .count() \
    .describe() \
    .show()

# If max >> mean, you have skew

# Solutions:
# 1. Salting (see performance-tuning.md)
# 2. Repartition with more partitions
# 3. Use AQE skew handling
```

## Partition Pruning

### Partition Elimination
```python
# Partitioned table
df.write.partitionBy("year", "month").parquet("data/")

# Reading with partition filter (pruning)
spark.read.parquet("data/") \
    .filter(col("year") == 2024)  # Only reads year=2024/ folders

# Verify pruning in explain
spark.read.parquet("data/") \
    .filter(col("year") == 2024) \
    .explain()
# Look for: PartitionFilters: [year#0 = 2024]
```

### Dynamic Partition Pruning
```python
# Enable DPP
spark.conf.set("spark.sql.optimizer.dynamicPartitionPruning.enabled", "true")
spark.conf.set("spark.sql.optimizer.dynamicPartitionPruning.reuseBroadcastOnly", "true")

# DPP example
fact_table.join(broadcast(dim_table.filter(col("region") == "US")), "key")
# Spark will push the region filter to fact_table partitions
```

## Co-Partitioning for Joins

### Why Co-Partition?
When two DataFrames are partitioned by the same key with the same number of partitions, joins can happen locally without shuffle.

```python
# Co-partition both DataFrames
df1 = df1.repartition(100, "customer_id")
df2 = df2.repartition(100, "customer_id")

# Join without shuffle (same partitioner)
result = df1.join(df2, "customer_id")
```

### Bucketing for Repeated Joins
```python
# Write bucketed table
df.write \
    .bucketBy(100, "customer_id") \
    .sortBy("customer_id") \
    .saveAsTable("bucketed_table")

# Subsequent reads maintain bucketing
df1 = spark.table("bucketed_table_1")
df2 = spark.table("bucketed_table_2")
df1.join(df2, "customer_id")  # No shuffle if same bucket count
```

## Monitoring Shuffle

### Spark UI Metrics
```
Stages Tab:
- Shuffle Read: Data pulled from other executors
- Shuffle Write: Data written for other stages
- Shuffle Read Blocked Time: Wait time for data

Tasks Tab:
- Shuffle Read Size/Records
- Shuffle Write Size/Records
- Spill (Memory/Disk)
```

### Key Metrics to Watch
| Metric | Healthy Range | Action if High |
|--------|---------------|----------------|
| Shuffle Write | < 1GB/task | More partitions |
| Shuffle Read | < 500MB/task | More partitions |
| Spill | 0 (ideal) | More memory or partitions |
| GC Time | < 10% task time | Tune GC, reduce memory |

## Common Patterns

### Filter-Early Pattern
```python
# Good: Filter before shuffle
df.filter(col("status") == "active") \
    .groupBy("category") \
    .agg(sum("amount"))

# Bad: Filter after shuffle
df.groupBy("category") \
    .agg(sum("amount")) \
    .filter(col("status") == "active")  # Status not available here anyway
```

### Aggregate-Then-Join Pattern
```python
# Good: Reduce data before join
summary = large_df.groupBy("key").agg(sum("value").alias("total"))
result = small_df.join(summary, "key")

# Bad: Join then aggregate
result = small_df.join(large_df, "key").groupBy("key").agg(sum("value"))
```

### Repartition-After-Filter Pattern
```python
# Maintain parallelism after filter
df.filter(col("region") == "US") \  # Filters to 10% of data
    .repartition(50) \               # Maintain parallelism
    .groupBy("state") \
    .agg(sum("sales"))
```
