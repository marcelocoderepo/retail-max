# Spark Performance Tuning

## Performance Optimization Framework

### The Optimization Process
```
1. Profile → 2. Identify Bottleneck → 3. Apply Fix → 4. Measure → 5. Repeat
```

### Performance Categories
| Category | Impact | Complexity |
|----------|--------|------------|
| Data Skew | High | Medium |
| Shuffle | High | Medium |
| Memory | High | High |
| I/O | Medium | Low |
| Serialization | Medium | Low |

## Adaptive Query Execution (AQE)

### Full AQE Configuration
```python
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.minPartitionSize", "64MB")
spark.conf.set("spark.sql.adaptive.coalescePartitions.initialPartitionNum", "400")
spark.conf.set("spark.sql.adaptive.advisoryPartitionSizeInBytes", "256MB")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256MB")
spark.conf.set("spark.sql.adaptive.localShuffleReader.enabled", "true")
```

### AQE Benefits
- **Dynamic Coalescing**: Merges small post-shuffle partitions
- **Dynamic Join Selection**: Converts to broadcast join when runtime stats show small table
- **Skew Handling**: Automatically splits skewed partitions

## Query Optimization

### Catalyst Optimizer Rules
```python
df.explain(True)
```

Key optimization rules:
- Predicate pushdown
- Column pruning
- Constant folding
- Filter ordering
- Join reordering

### Pushing Filters Down
```python
# Good: Filter before join
df1.filter(df1.date > "2024-01-01").join(df2, "key")

# Bad: Filter after join
df1.join(df2, "key").filter(df1.date > "2024-01-01")
```

### Column Pruning
```python
# Good: Select only needed columns
df.select("col1", "col2", "col3").join(other_df, "col1")

# Bad: Carry all columns through
df.join(other_df, "col1").select("col1", "col2")
```

## Partition Optimization

### Optimal Partition Count Formula
```python
total_cores = num_executors * cores_per_executor
partition_count = total_cores * 2  # to 4 for parallelism

data_size_bytes = df.rdd.map(lambda x: len(str(x))).sum()
partition_count = data_size_bytes / (128 * 1024 * 1024)  # 128MB target
```

### Partition Size Guidelines
| Data Size | Partitions | Partition Size |
|-----------|------------|----------------|
| 1GB | 8-16 | 64-128MB |
| 10GB | 80-160 | 64-128MB |
| 100GB | 400-800 | 128-256MB |
| 1TB | 4000-8000 | 128-256MB |

### Repartition vs Coalesce
```python
# Repartition: Full shuffle, can increase or decrease
df.repartition(200)                    # Random distribution
df.repartition(200, "partition_col")   # Hash partition

# Coalesce: No shuffle, decrease only
df.coalesce(100)  # Combine partitions without shuffle
```

## Shuffle Optimization

### Reducing Shuffle Data
```python
# 1. Filter early
df.filter(col("status") == "active") \
  .groupBy("category") \
  .agg(sum("amount"))

# 2. Aggregate before join
summary = df.groupBy("key").agg(sum("value").alias("total"))
result = dim_table.join(summary, "key")

# 3. Broadcast small tables
from pyspark.sql.functions import broadcast
large_df.join(broadcast(small_df), "key")
```

### Shuffle Configuration
```python
# Optimal shuffle partitions
spark.conf.set("spark.sql.shuffle.partitions", str(total_cores * 2))

# Shuffle compression
spark.conf.set("spark.shuffle.compress", "true")
spark.conf.set("spark.io.compression.codec", "lz4")

# Shuffle service (for dynamic allocation)
spark.conf.set("spark.shuffle.service.enabled", "true")
```

## Data Skew Solutions

### Detecting Skew
```python
# Check partition sizes
df.groupBy(spark_partition_id()).count().show()

# Check key distribution
df.groupBy("join_key").count().orderBy(desc("count")).show(20)
```

### Salting Technique
```python
from pyspark.sql.functions import concat, lit, rand

SALT_BUCKETS = 10

# Salt the skewed table
df_skewed_salted = df_skewed.withColumn(
    "salted_key",
    concat(col("key"), lit("_"), (rand() * SALT_BUCKETS).cast("int"))
)

# Explode the lookup table
from pyspark.sql.functions import explode, array

df_lookup_exploded = df_lookup.withColumn(
    "salt",
    explode(array([lit(i) for i in range(SALT_BUCKETS)]))
).withColumn(
    "salted_key",
    concat(col("key"), lit("_"), col("salt"))
).drop("salt")

# Join on salted key
result = df_skewed_salted.join(df_lookup_exploded, "salted_key")
```

### Broadcast for Skew
```python
# If one side is small enough, broadcast it
if df_small.count() < 10_000_000:  # 10M rows threshold
    result = df_large.join(broadcast(df_small), "key")
```

### AQE Skew Join
```python
# Enable AQE skew handling
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256MB")
```

## I/O Optimization

### File Format Selection
| Format | Compression | Schema Evolution | Best For |
|--------|-------------|------------------|----------|
| Parquet | Excellent | Limited | Analytics |
| Delta | Excellent | Full | Data Lakes |
| ORC | Excellent | Limited | Hive |
| Avro | Good | Full | Streaming |
| JSON | Poor | Flexible | Interchange |

### Parquet Optimization
```python
# Writing optimized Parquet
df.write \
    .mode("overwrite") \
    .option("compression", "snappy") \
    .option("parquet.block.size", 134217728)  # 128MB \
    .parquet("output/path")

# Reading with predicate pushdown
df = spark.read.parquet("data/") \
    .filter(col("date") == "2024-01-01")  # Pushed to file level
```

### Partition Pruning
```python
# Write partitioned data
df.write \
    .partitionBy("year", "month", "day") \
    .parquet("output/")

# Read with partition filter (skips irrelevant partitions)
spark.read.parquet("output/") \
    .filter(col("year") == 2024)
```

### S3 Optimization
```python
# S3 multipart upload
spark.conf.set("spark.hadoop.fs.s3a.multipart.size", "104857600")  # 100MB
spark.conf.set("spark.hadoop.fs.s3a.multipart.threshold", "104857600")
spark.conf.set("spark.hadoop.fs.s3a.threads.max", "64")

# S3 committer for consistent writes
spark.conf.set("spark.sql.sources.commitProtocolClass",
    "org.apache.spark.internal.io.cloud.PathOutputCommitProtocol")
spark.conf.set("spark.hadoop.mapreduce.outputcommitter.factory.scheme.s3a",
    "org.apache.hadoop.fs.s3a.commit.S3ACommitterFactory")
```

## Caching Strategy

### When to Cache
- Iterative algorithms (ML)
- Multiple actions on same DataFrame
- After expensive transformations
- Interactive analysis

### When NOT to Cache
- One-time use DataFrames
- Very large datasets (won't fit in memory)
- Before filters (cache after filtering)

### Cache Best Practices
```python
# Cache after filtering and selecting
df_processed = df \
    .filter(col("status") == "active") \
    .select("id", "name", "value") \
    .cache()

# Force evaluation
df_processed.count()  # Triggers caching

# Use when needed
result1 = df_processed.groupBy("name").agg(sum("value"))
result2 = df_processed.filter(col("value") > 100)

# Clean up
df_processed.unpersist()
```

## Serialization

### Kryo Serialization
```python
spark.conf.set("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
spark.conf.set("spark.kryo.registrationRequired", "false")
spark.conf.set("spark.kryo.unsafe", "true")
```

### Register Custom Classes
```python
spark.conf.set("spark.kryo.classesToRegister",
    "com.myapp.MyClass,com.myapp.AnotherClass")
```

## UDF Optimization

### Avoid UDFs When Possible
```python
# Bad: Python UDF
from pyspark.sql.functions import udf

@udf("string")
def my_udf(x):
    return x.upper()

df.select(my_udf("name"))

# Good: Built-in function
from pyspark.sql.functions import upper

df.select(upper("name"))
```

### Use Pandas UDFs (Vectorized)
```python
from pyspark.sql.functions import pandas_udf
import pandas as pd

@pandas_udf("double")
def vectorized_udf(s: pd.Series) -> pd.Series:
    return s * 2.0

df.select(vectorized_udf("value"))
```

## Configuration Checklist

### Production Configuration
```python
# Memory
spark.executor.memory = "8g"
spark.executor.memoryOverhead = "2g"
spark.driver.memory = "4g"
spark.memory.fraction = 0.6
spark.memory.storageFraction = 0.3

# Parallelism
spark.executor.cores = 5
spark.default.parallelism = 200
spark.sql.shuffle.partitions = 200

# AQE
spark.sql.adaptive.enabled = true
spark.sql.adaptive.coalescePartitions.enabled = true
spark.sql.adaptive.skewJoin.enabled = true

# Serialization
spark.serializer = org.apache.spark.serializer.KryoSerializer

# I/O
spark.sql.files.maxPartitionBytes = 134217728
spark.sql.parquet.compression.codec = snappy

# Dynamic Allocation
spark.dynamicAllocation.enabled = true
spark.dynamicAllocation.minExecutors = 2
spark.dynamicAllocation.maxExecutors = 100
spark.shuffle.service.enabled = true
```

## Performance Monitoring Queries

### Check Data Skew
```python
from pyspark.sql.functions import spark_partition_id, count

df.groupBy(spark_partition_id().alias("partition")) \
    .agg(count("*").alias("count")) \
    .orderBy("count", ascending=False) \
    .show()
```

### Monitor Shuffle
```python
spark.sparkContext.statusTracker().getExecutorInfos()

# In Spark UI: Stages tab → Shuffle Read/Write columns
```

### Explain Plan Analysis
```python
df.explain("cost")  # Shows estimated costs
df.explain("formatted")  # Readable format
```
