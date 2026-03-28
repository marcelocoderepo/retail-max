# Spark Best Practices

## Code Quality Patterns

### DataFrame vs RDD
```python
# Always prefer DataFrames over RDDs
# Good: DataFrame API
df.filter(col("age") > 21).select("name", "age")

# Avoid: RDD API
rdd.filter(lambda x: x["age"] > 21).map(lambda x: (x["name"], x["age"]))
```

### Built-in Functions vs UDFs
```python
# Good: Built-in functions (Catalyst optimized)
from pyspark.sql.functions import upper, trim, when, coalesce

df.withColumn("name_upper", upper(trim(col("name"))))

# Avoid: Python UDFs (serialization overhead)
from pyspark.sql.functions import udf

@udf("string")
def my_upper(s):
    return s.upper().strip() if s else None

df.withColumn("name_upper", my_upper(col("name")))
```

### Pandas UDFs for Complex Logic
```python
from pyspark.sql.functions import pandas_udf
import pandas as pd

@pandas_udf("double")
def complex_calculation(s: pd.Series) -> pd.Series:
    return s.apply(lambda x: some_complex_math(x))

df.withColumn("result", complex_calculation("value"))
```

## Data Loading Patterns

### Optimized File Reading
```python
# Good: Specify schema explicitly
from pyspark.sql.types import StructType, StructField, StringType, IntegerType

schema = StructType([
    StructField("id", IntegerType(), False),
    StructField("name", StringType(), True),
    StructField("value", IntegerType(), True)
])

df = spark.read.schema(schema).parquet("data/")

# Avoid: Schema inference (reads data twice)
df = spark.read.parquet("data/")  # Infers schema first
```

### Partition Pruning
```python
# Good: Filter on partition columns
df = spark.read.parquet("data/") \
    .filter(col("year") == 2024) \
    .filter(col("month") == 1)

# Avoid: Reading all then filtering
df = spark.read.parquet("data/").filter(col("date").startswith("2024-01"))
```

### File Format Best Practices
```python
# Writing optimized Parquet
df.write \
    .mode("overwrite") \
    .option("compression", "snappy") \
    .partitionBy("year", "month") \
    .parquet("output/")

# Z-ordering for Delta Lake
df.write \
    .format("delta") \
    .option("overwriteSchema", "true") \
    .mode("overwrite") \
    .save("delta/path")

# Optimize with Z-ORDER
spark.sql("OPTIMIZE delta.`/path` ZORDER BY (frequently_filtered_column)")
```

## Transformation Patterns

### Filter Early
```python
# Good: Filter as early as possible
df.filter(col("status") == "active") \
    .filter(col("amount") > 0) \
    .groupBy("category") \
    .agg(sum("amount"))

# Avoid: Filtering after aggregation
df.groupBy("category", "status") \
    .agg(sum("amount")) \
    .filter(col("status") == "active")
```

### Column Selection
```python
# Good: Select only needed columns early
df.select("id", "name", "value") \
    .filter(col("value") > 100) \
    .groupBy("name") \
    .agg(sum("value"))

# Avoid: Carrying unnecessary columns
df.filter(col("value") > 100) \
    .groupBy("name") \
    .agg(sum("value"))  # May still carry extra columns
```

### Null Handling
```python
# Good: Explicit null handling
from pyspark.sql.functions import coalesce, when, isnan, isnull

df.withColumn("value", coalesce(col("value"), lit(0)))
df.filter(col("value").isNotNull())
df.na.fill({"value": 0, "name": "unknown"})

# Avoid: Implicit null comparisons
df.filter(col("value") != None)  # Doesn't work as expected
```

### Join Best Practices
```python
# Good: Filter before join
df1.filter(col("status") == "active") \
    .join(df2.filter(col("valid") == True), "key")

# Good: Select columns before join
df1.select("key", "value1") \
    .join(df2.select("key", "value2"), "key")

# Good: Use broadcast for small tables
df1.join(broadcast(small_df), "key")

# Avoid: Joining then filtering
df1.join(df2, "key").filter(col("status") == "active")
```

## Caching Patterns

### Strategic Caching
```python
# Good: Cache after expensive transformations
df_processed = df \
    .filter(col("status") == "active") \
    .groupBy("category") \
    .agg(
        sum("amount").alias("total"),
        count("*").alias("count")
    ) \
    .cache()

# Force cache materialization
df_processed.count()

# Use cached DataFrame
result1 = df_processed.filter(col("total") > 1000)
result2 = df_processed.orderBy("count", ascending=False)

# Clean up
df_processed.unpersist()
```

### Cache vs Persist
```python
from pyspark.storagelevel import StorageLevel

# Memory only (fast but may fail)
df.cache()  # Equivalent to MEMORY_AND_DISK

# Memory + Disk (safer)
df.persist(StorageLevel.MEMORY_AND_DISK)

# Serialized (less memory, slower)
df.persist(StorageLevel.MEMORY_AND_DISK_SER)

# Disk only (for very large DataFrames)
df.persist(StorageLevel.DISK_ONLY)
```

### When Not to Cache
```python
# Don't cache if used only once
df.filter(col("x") > 100).write.parquet("output/")  # No cache needed

# Don't cache before filter (cache after)
df.cache().filter(col("status") == "active")  # Bad
df.filter(col("status") == "active").cache()   # Good
```

## Error Handling

### Safe Data Processing
```python
from pyspark.sql.functions import when, col, lit

# Handle division by zero
df.withColumn("ratio",
    when(col("denominator") == 0, lit(None))
    .otherwise(col("numerator") / col("denominator"))
)

# Handle parse errors
df.withColumn("parsed_date",
    to_date(col("date_str"), "yyyy-MM-dd")
)  # Returns null on parse failure
```

### Debugging Techniques
```python
# Check schema
df.printSchema()

# Sample data
df.show(5, truncate=False)

# Check execution plan
df.explain(True)

# Count at checkpoints
print(f"After filter: {df.count()}")

# Check partition distribution
df.groupBy(spark_partition_id()).count().show()
```

## Production Patterns

### Configuration Template
```python
from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("ProductionJob") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.sql.adaptive.coalescePartitions.enabled", "true") \
    .config("spark.sql.adaptive.skewJoin.enabled", "true") \
    .config("spark.sql.shuffle.partitions", "200") \
    .config("spark.sql.autoBroadcastJoinThreshold", "10485760") \
    .config("spark.serializer", "org.apache.spark.serializer.KryoSerializer") \
    .config("spark.sql.parquet.compression.codec", "snappy") \
    .getOrCreate()
```

### Idempotent Writes
```python
# Overwrite with partition management
df.write \
    .mode("overwrite") \
    .partitionBy("date") \
    .option("partitionOverwriteMode", "dynamic") \
    .parquet("output/")

# Delta Lake for ACID writes
df.write \
    .format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .save("delta/path")
```

### Monitoring and Logging
```python
import logging

logger = logging.getLogger(__name__)

def process_data(df):
    logger.info(f"Input rows: {df.count()}")

    df_filtered = df.filter(col("status") == "active")
    logger.info(f"After filter: {df_filtered.count()}")

    result = df_filtered.groupBy("category").agg(sum("amount"))
    logger.info(f"Output rows: {result.count()}")

    return result
```

## Anti-Patterns to Avoid

### Collection Anti-Patterns
```python
# Bad: Collecting large data to driver
all_data = df.collect()  # OOM risk

# Good: Use take() or show()
sample = df.take(100)
df.show(20)

# Good: Write to storage
df.write.parquet("output/")
```

### Loop Anti-Patterns
```python
# Bad: Loop with multiple writes
for date in dates:
    df.filter(col("date") == date).write.parquet(f"output/{date}")

# Good: Single partitioned write
df.write.partitionBy("date").parquet("output/")
```

### Count Anti-Patterns
```python
# Bad: Multiple counts
if df.count() > 0:
    if df.count() > 1000:
        process_large(df)

# Good: Cache and count once
df_cached = df.cache()
count = df_cached.count()
if count > 0:
    if count > 1000:
        process_large(df_cached)
df_cached.unpersist()
```

### GroupBy Anti-Patterns
```python
# Bad: groupByKey() for aggregation
rdd.groupByKey().mapValues(sum)

# Good: reduceByKey() or DataFrame aggregation
rdd.reduceByKey(lambda a, b: a + b)
df.groupBy("key").agg(sum("value"))
```

## Testing Patterns

### Unit Testing
```python
from pyspark.sql import SparkSession
import pytest

@pytest.fixture(scope="session")
def spark():
    return SparkSession.builder \
        .master("local[2]") \
        .appName("Test") \
        .getOrCreate()

def test_transformation(spark):
    input_data = [("a", 1), ("b", 2)]
    df = spark.createDataFrame(input_data, ["key", "value"])

    result = df.filter(col("value") > 1)

    assert result.count() == 1
    assert result.first()["key"] == "b"
```

### Integration Testing
```python
def test_end_to_end(spark, tmp_path):
    input_path = str(tmp_path / "input")
    output_path = str(tmp_path / "output")

    # Create test data
    test_df = spark.createDataFrame([...])
    test_df.write.parquet(input_path)

    # Run job
    result = process_data(spark.read.parquet(input_path))
    result.write.parquet(output_path)

    # Verify
    output_df = spark.read.parquet(output_path)
    assert output_df.count() > 0
```

## Checklist

### Before Deployment
- [ ] Schema explicitly defined
- [ ] Partition columns identified
- [ ] Broadcast thresholds tuned
- [ ] AQE enabled
- [ ] Memory configurations set
- [ ] Serializer configured
- [ ] Error handling implemented
- [ ] Logging added
- [ ] Tests written

### Code Review
- [ ] No collect() on large data
- [ ] Filters applied early
- [ ] Columns selected explicitly
- [ ] Joins optimized (broadcast hints)
- [ ] Cache used strategically
- [ ] Built-in functions over UDFs
- [ ] Idempotent writes
- [ ] Proper null handling
