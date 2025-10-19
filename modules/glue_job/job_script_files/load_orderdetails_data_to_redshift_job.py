import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue import DynamicFrame

# Get job arguments
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    's3_bucket',
    'silver_database',
    'silver_table_name',
    'redshift_connection_name',
    'redshift_temp_dir',
    'target_schema',
    'target_table'
])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Configuration
S3_BUCKET = args['s3_bucket']
SILVER_DATABASE = args['silver_database']
SILVER_TABLE = args.get('silver_table_name', 'orderDetails')
REDSHIFT_CONNECTION = args.get('redshift_connection_name', 'redshift-connection')
REDSHIFT_TEMP_DIR = args.get('redshift_temp_dir', f's3://{S3_BUCKET}/redshift-temp/')
TARGET_SCHEMA = args.get('target_schema', 'sales')
TARGET_TABLE = args.get('target_table', 'fact_order_details')

print(f"Starting job to load order details data from {SILVER_DATABASE}.{SILVER_TABLE} "
      f"to Redshift {TARGET_SCHEMA}.{TARGET_TABLE}")

try:
    # Read silver layer order details data directly from S3
    print(f"Reading data from S3 path: s3://{S3_BUCKET}/silver-data/salesdb/orderDetails/")

    silver_orderdetails_df = glueContext.create_dynamic_frame.from_options(
        connection_type="s3",
        format="parquet",
        connection_options={"paths": [f"s3://{S3_BUCKET}/silver-data/salesdb/orderDetails/"]},
        transformation_ctx="read_silver_orderdetails"
    )

    print(f"Records read from silver layer: {silver_orderdetails_df.count()}")

    # Print schema for debugging
    print("Silver layer schema:")
    silver_orderdetails_df.printSchema()

    # Define the pre-actions to create the fact table if it doesn't exist
    create_table_sql = f"""
    CREATE TABLE IF NOT EXISTS {TARGET_SCHEMA}.{TARGET_TABLE} (
        order_details_id VARCHAR(50),
        order_id VARCHAR(50),
        product_id VARCHAR(50),
        product_quantity VARCHAR(50),
        ingestion_date DATE
    );
    """

    # Truncate table before loading (optional, remove if you want to append)
    truncate_sql = f"TRUNCATE TABLE {TARGET_SCHEMA}.{TARGET_TABLE};"

    # Combine pre-actions
    pre_actions = f"{create_table_sql} {truncate_sql}"

    print(f"Writing data to Redshift table: {TARGET_SCHEMA}.{TARGET_TABLE}")

    # Write to Redshift
    glueContext.write_dynamic_frame.from_options(
        frame=silver_orderdetails_df,
        connection_type="redshift",
        connection_options={
            "redshiftTmpDir": REDSHIFT_TEMP_DIR,
            "useConnectionProperties": "true",
            "database": "production",
            "dbtable": f"{TARGET_SCHEMA}.{TARGET_TABLE}",
            "connectionName": REDSHIFT_CONNECTION,
            "preactions": pre_actions,
            "postactions": f"ANALYZE {TARGET_SCHEMA}.{TARGET_TABLE};"
        },
        transformation_ctx="write_to_redshift"
    )

    print(f"Successfully loaded {silver_orderdetails_df.count()} records to Redshift")

except Exception as e:
    print(f"Error occurred: {str(e)}")
    raise e

finally:
    job.commit()
