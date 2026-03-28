# Spark Join Optimization

## Join Strategies

### Overview
```
┌─────────────────────────────────────────────────────────────┐
│                    Join Strategy Selection                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Small Table (<10MB)     │  Broadcast Hash Join (BHJ)      │
│  ↓                       │  - No shuffle                    │
│  Small-Medium (<100MB)   │  - Broadcast one side           │
│  ↓                       │                                  │
│  Large + Large           │  Sort Merge Join (SMJ)          │
│  (equi-join)             │  - Shuffle both sides           │
│  ↓                       │  - Sort then merge              │
│  Large + Large           │  Shuffle Hash Join (SHJ)        │
│  (build side fits mem)   │  - Shuffle both sides           │
│  ↓                       │  - Build hash table             │
│  Non-equi join           │  Broadcast Nested Loop (BNL)    │
│  Theta join              │  - Broadcast small side         │
│                          │  - Nested iteration             │
└─────────────────────────────────────────────────────────────┘
```

## Broadcast Hash Join (BHJ)

### How It Works
```
1. Small table collected to driver
2. Driver broadcasts to all executors
3. Large table partitions joined locally
4. No shuffle required

┌─────────────────────────────────────────────────────────────┐
│                   Broadcast Hash Join                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Driver:    [Small DF] ──→ Broadcast ──→ All Executors     │
│                                                             │
│  Executor 1: [Large Part 1] + [Broadcast] → [Result 1]     │
│  Executor 2: [Large Part 2] + [Broadcast] → [Result 2]     │
│  Executor N: [Large Part N] + [Broadcast] → [Result N]     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Configuration
```python
# Auto-broadcast threshold (default 10MB)
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "10485760")  # 10MB

# Disable auto-broadcast
spark.conf.set("spark.sql.autoBroadcastJoinThreshold", "-1")
```

### Forcing Broadcast
```python
from pyspark.sql.functions import broadcast

# Method 1: Function
result = large_df.join(broadcast(small_df), "key")

# Method 2: Hint
result = large_df.join(small_df.hint("broadcast"), "key")

# SQL
spark.sql("""
    SELECT /*+ BROADCAST(small_table) */ *
    FROM large_table
    JOIN small_table ON large_table.key = small_table.key
""")
```

### When to Use
- Small table < 10MB (default) or up to 100MB with enough driver memory
- One-to-many or many-to-one joins
- Dimension table lookups

### Caveats
- Driver must have enough memory
- Broadcast happens once per query (cached)
- Don't broadcast tables that are actually large

## Sort Merge Join (SMJ)

### How It Works
```
1. Both tables shuffled by join key
2. Each partition sorted
3. Linear merge of sorted partitions

┌─────────────────────────────────────────────────────────────┐
│                    Sort Merge Join                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Table A          Shuffle by Key         Sorted Partition   │
│  ┌─────┐                                 ┌─────────────┐   │
│  │ A1  │ ────────────────────────────→  │ A1,A2 sorted│   │
│  │ A2  │                                 └──────┬──────┘   │
│  └─────┘                                        │          │
│                                                 ↓ Merge    │
│  Table B          Shuffle by Key         Sorted Partition   │
│  ┌─────┐                                 ┌─────────────┐   │
│  │ B1  │ ────────────────────────────→  │ B1,B2 sorted│   │
│  │ B2  │                                 └──────┬──────┘   │
│  └─────┘                                        │          │
│                                                 ↓          │
│                                          ┌─────────────┐   │
│                                          │   Result    │   │
│                                          └─────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Configuration
```python
# Prefer sort merge join
spark.conf.set("spark.sql.join.preferSortMergeJoin", "true")

# Sort merge join threshold
spark.conf.set("spark.sql.sortMergeJoinExec.buffer.in.memory.threshold", "10000")
```

### When to Use
- Both tables are large
- Join key is sortable
- Tables are pre-sorted or bucketed

### Optimization
```python
# Pre-sort for repeated joins
df_sorted = df.sortWithinPartitions("join_key")

# Bucketing for repeated joins
df.write.bucketBy(100, "join_key").sortBy("join_key").saveAsTable("bucketed")
```

## Shuffle Hash Join (SHJ)

### How It Works
```
1. Both tables shuffled by join key
2. Hash table built from smaller side
3. Larger side probes hash table

┌─────────────────────────────────────────────────────────────┐
│                   Shuffle Hash Join                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Build Side (smaller)                                       │
│  ┌─────┐     Shuffle     ┌─────────────┐                   │
│  │     │ ────────────→  │ Hash Table  │                   │
│  └─────┘                 └──────┬──────┘                   │
│                                 │ Probe                    │
│  Probe Side (larger)            ↓                          │
│  ┌─────┐     Shuffle     ┌─────────────┐                   │
│  │     │ ────────────→  │   Result    │                   │
│  └─────┘                 └─────────────┘                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Configuration
```python
# Disable prefer sort merge to allow SHJ
spark.conf.set("spark.sql.join.preferSortMergeJoin", "false")
```

### Hint for Shuffle Hash
```python
# Force shuffle hash join
result = df1.hint("shuffle_hash").join(df2, "key")

# SQL
spark.sql("""
    SELECT /*+ SHUFFLE_HASH(t1) */ *
    FROM t1 JOIN t2 ON t1.key = t2.key
""")
```

### When to Use
- One table fits in memory after shuffle
- Keys have high cardinality (many distinct values)
- No pre-existing sort order to leverage

## Join Hints

### Available Hints
| Hint | Strategy | When to Use |
|------|----------|-------------|
| `BROADCAST` | Broadcast Hash | Small table fits in memory |
| `MERGE` | Sort Merge | Both tables large, sortable |
| `SHUFFLE_HASH` | Shuffle Hash | Build side fits in memory |
| `SHUFFLE_REPLICATE_NL` | Nested Loop | Non-equi joins |

### Hint Syntax
```python
# DataFrame API
df1.hint("broadcast").join(df2, "key")

# SQL
SELECT /*+ BROADCAST(t1) */ * FROM t1 JOIN t2
SELECT /*+ MERGE(t1, t2) */ * FROM t1 JOIN t2
SELECT /*+ SHUFFLE_HASH(t1) */ * FROM t1 JOIN t2
```

## Join Types

### Supported Join Types
```python
# Inner join (default)
df1.join(df2, "key")
df1.join(df2, "key", "inner")

# Left outer join
df1.join(df2, "key", "left")
df1.join(df2, "key", "left_outer")

# Right outer join
df1.join(df2, "key", "right")

# Full outer join
df1.join(df2, "key", "full")
df1.join(df2, "key", "full_outer")

# Left semi join (exists)
df1.join(df2, "key", "left_semi")

# Left anti join (not exists)
df1.join(df2, "key", "left_anti")

# Cross join (cartesian)
df1.crossJoin(df2)
```

### Join Conditions
```python
# Single column
df1.join(df2, "key")

# Multiple columns
df1.join(df2, ["key1", "key2"])

# Complex condition
df1.join(df2, (df1.key == df2.key) & (df1.date == df2.date))

# Non-equi join
df1.join(df2, df1.value > df2.threshold)
```

## Handling Skewed Joins

### Detecting Skew
```python
# Check key distribution
df.groupBy("join_key") \
    .count() \
    .orderBy("count", ascending=False) \
    .show(20)

# Statistics
df.groupBy("join_key").count().describe().show()
```

### AQE Skew Join
```python
# Enable AQE with skew handling
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionFactor", "5")
spark.conf.set("spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes", "256MB")
```

### Manual Salting
```python
from pyspark.sql.functions import concat, lit, rand, explode, array

SALT_BUCKETS = 10

# Salt skewed table
df_skewed = df_skewed.withColumn(
    "salted_key",
    concat(col("key"), lit("_"), (rand() * SALT_BUCKETS).cast("int"))
)

# Explode lookup table
df_lookup = df_lookup.withColumn(
    "salt",
    explode(array([lit(i) for i in range(SALT_BUCKETS)]))
).withColumn(
    "salted_key",
    concat(col("key"), lit("_"), col("salt"))
).drop("salt")

# Join on salted key
result = df_skewed.join(df_lookup, "salted_key") \
    .drop("salted_key")
```

### Broadcast for Skew
```python
# If the lookup table is small enough
result = df_skewed.join(broadcast(df_lookup), "key")
```

## Join Optimization Best Practices

### 1. Filter Before Join
```python
# Good
df1.filter(col("status") == "active") \
    .join(df2.filter(col("valid") == True), "key")

# Bad
df1.join(df2, "key") \
    .filter((col("status") == "active") & (col("valid") == True))
```

### 2. Select Only Needed Columns
```python
# Good
df1.select("key", "value1") \
    .join(df2.select("key", "value2"), "key")

# Bad
df1.join(df2, "key").select("key", "value1", "value2")
```

### 3. Use Broadcast for Small Tables
```python
# Dimension table lookups
fact_df.join(broadcast(dim_df), "dim_key")
```

### 4. Pre-partition for Repeated Joins
```python
# Bucket tables that are joined frequently
df.write.bucketBy(100, "key").saveAsTable("bucketed_table")
```

### 5. Avoid Cartesian Products
```python
# Always have a join condition
# Bad: df1.crossJoin(df2)
# Good: df1.join(df2, df1.key == df2.key)
```

## Join Troubleshooting

### Slow Join Diagnosis
```python
# Check execution plan
df1.join(df2, "key").explain(True)

# Look for:
# - BroadcastHashJoin (good for small tables)
# - SortMergeJoin (expected for large tables)
# - BroadcastNestedLoopJoin (expensive)
# - CartesianProduct (very expensive)
```

### Common Issues

| Problem | Symptom | Solution |
|---------|---------|----------|
| Broadcast too large | Driver OOM | Reduce threshold, disable broadcast |
| Skewed join | Long-running tasks | AQE, salting, broadcast |
| Too many shuffles | Slow stages | Bucketing, pre-partition |
| Wrong join strategy | Suboptimal plan | Use hints |
| Cartesian product | Massive data explosion | Add join condition |

### Verifying Join Strategy
```python
# Before running
df1.join(df2, "key").explain("formatted")

# Look for physical plan operator:
# - BroadcastHashJoin
# - SortMergeJoin
# - ShuffledHashJoin
```
