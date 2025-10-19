import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue import DynamicFrame
import boto3
import json

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
SLIVER_DATABASE = args['silver_database']
SILVER_TABLE = args.get('silver_table_name', 'Product')
REDSHIFT_CONNECTION = args.get('redshift_connection_name', 'redshift-connection')
REDSHIFT_TEMP_DIR = args.get('redshift_temp_dir', f's3://{S3_BUCKET}/redshift-temp/')
TARGET_SCHEMA = args.get('target_schema', 'sales')
TARGET_TABLE = args.get('target_table', 'stage_dim_customer')

print(f"Starting job to load customer data from {SLIVER_DATABASE}.{SILVER_TABLE} to Redshift {TARGET_SCHEMA}.{TARGET_TABLE}")

try:
    # Read silver layer customer data from Glue Catalog
    print(f"Reading data from Glue table: {SLIVER_DATABASE}.{SILVER_TABLE}")
    
    silver_customer_df = glueContext.create_dynamic_frame.from_options(
        connection_type="s3",
        format="parquet",  # or "csv"
        connection_options={"paths": [f"s3://{S3_BUCKET}/silver-data/salesdb/Customer/"]},
        transformation_ctx="read_silver_customer"
    )
    
    print(f"Records read from silver layer: {silver_customer_df.count()}")
    
    # Print schema for debugging
    print("Silver layer schema:")
    silver_customer_df.printSchema()
    
    
    # Define the pre-actions to create the table if it doesn't exist
    create_table_sql = f"""
    CREATE TABLE IF NOT EXISTS {TARGET_SCHEMA}.{TARGET_TABLE} (
        cdc_operation VARCHAR(1),
        customer_id VARCHAR(50),
        cust_email VARCHAR(255),
        cust_phone VARCHAR(50),
        cust_address VARCHAR(500),
        cust_country VARCHAR(100),
        cust_city VARCHAR(100),
        hash_value VARCHAR(64),
        record_start_ts TIMESTAMP,
        record_end_ts TIMESTAMP,
        active_flag INTEGER,
        cust_first_name VARCHAR(255),
        cust_last_name VARCHAR(255)
    );
    """
    
    # Truncate table before loading (optional - remove if you want to append)
    truncate_sql = f"TRUNCATE TABLE {TARGET_SCHEMA}.{TARGET_TABLE};"
    
    # Combine pre-actions
    pre_actions = f"{create_table_sql} {truncate_sql}"
    
    print(f"Writing data to Redshift table: {TARGET_SCHEMA}.{TARGET_TABLE}")
    
    # Write to Redshift
    glueContext.write_dynamic_frame.from_options(
        frame=silver_customer_df,
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
    
    print(f"Successfully loaded {silver_customer_df.count()} records to Redshift")

except Exception as e:
    print(f"Error occurred: {str(e)}")
    raise e

finally:
    job.commit()