import sys
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from pyspark.sql.functions import (
    current_timestamp, lit, sha2, concat_ws, col, current_date, split
)
from pyspark.sql.types import TimestampType
from awsglue.dynamicframe import DynamicFrame
from awsglue.utils import getResolvedOptions
from awsglue.job import Job

# Get job parameters
args = getResolvedOptions(
    sys.argv,
    ["JOB_NAME", "s3_bucket", "db_name", "table_name", "glue_database", "glue_table_name"]
)


bucket     = args["s3_bucket"]   # bucket
db_name              = args["db_name"]
table_name           = args["table_name"]
glue_database        = args["glue_database"]
glue_table_name      = args["glue_table_name"]

# Initialize Glue / Spark
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args["JOB_NAME"], args)

# -------------------
# Read Bronze Data
# -------------------
customer_dyf = glueContext.create_dynamic_frame.from_catalog(
    database=glue_database,
    table_name=glue_table_name,
    transformation_ctx="bronze_customer_dyf"
)

customer_df_from_catalog = customer_dyf.toDF()

# Only proceed if data is available
if customer_df_from_catalog.count() > 0:

    # Rename columns
    renamed_customer = (
        customer_df_from_catalog
            .withColumnRenamed("customerid", "customer_id")
            .withColumnRenamed("op", "cdc_operation")
            .withColumnRenamed("phone", "cust_phone")
            .withColumnRenamed("address", "cust_address")
            .withColumnRenamed("country", "cust_country")
            .withColumnRenamed("city", "cust_city")
            .withColumnRenamed("email", "cust_email")
            .withColumnRenamed("name", "cust_name")
    )

    # Default values
    current_ts = current_timestamp()
    record_end_ts = lit("9999-12-31").cast(TimestampType())
    active_flag = lit(1)

    # Hash value for change detection
    concatenated_customer_fields = concat_ws(
        "",
        col("cust_phone"),
        col("cust_address"),
        col("cust_country"),
        col("cust_city"),
        col("cust_name")
    )

    # Final dataframe with new columns
    customer_final_df = (
        renamed_customer
            .withColumn("hash_value", sha2(concatenated_customer_fields, 256))
            .withColumn("record_start_ts", current_ts)
            .withColumn("record_end_ts", record_end_ts)
            .withColumn("ingestion_date", current_date())
            .withColumn("active_flag", active_flag)
            .withColumn("cust_first_name", split(col("cust_name"), " ").getItem(0))
            .withColumn("cust_last_name", split(col("cust_name"), " ").getItem(1))
            .drop("cust_name")
    )

    # Convert to DynamicFrame
    customer_final_dyf = DynamicFrame.fromDF(customer_final_df, glueContext, "customer_final_dyf")

    # -------------------
    # Write to Silver
    # -------------------
    glueContext.write_dynamic_frame.from_options(
        frame=customer_final_dyf,
        connection_type="s3",
        connection_options={
            "path": f"s3://{bucket}/silver-data/{db_name}/{table_name}/",
            "partitionKeys": ["ingestion_date"]
        },
        format="parquet",
        transformation_ctx="customer_dyf_to_S3"
    )

else:
    print("No new records found in the source data. Skipping processing.")

job.commit()
