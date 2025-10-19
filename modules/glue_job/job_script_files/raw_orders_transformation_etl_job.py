"""%%configure 
{
  "--job-bookmark-option": "job-bookmark-enable"
} """       

import sys
from pyspark.context import SparkContext
from awsglue.context import GlueContext	
from pyspark.sql.functions import current_timestamp, lit, sha2, concat_ws, col, current_date, split,to_date, round, year, month
from pyspark.sql.types import TimestampType, DateType
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
processed_folder_name = "silver-data"

#set up the spark contexts, glue contexts and initialize job
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)  
args = getResolvedOptions(sys.argv, ["JOB_NAME"])
job.init(args['JOB_NAME'], args)


#Read data from data catalog
orders_df_from_catalog = glueContext.create_data_frame_from_catalog(glue_database,\
                            glue_table_name,additional_options = {"useCatalogSchema": True, "useSparkDataSource": True, "header":True},\
                                transformation_ctx = "orders_df_from_catalog")

if orders_df_from_catalog.count() > 0 :
    
    orders_with_date = orders_df_from_catalog.withColumn("orderDate", to_date(col("orderDate").cast(DateType())))

    #Create new dataframe for renamed fields
    renamed_orders = orders_with_date.withColumnRenamed("orderid","order_id ")\
                        .withColumnRenamed("orderCustomerId","order_customer_id")\
                        .withColumnRenamed("orderDate","order_date")\
                        .withColumnRenamed("paymentMethod","payment_method")\
                        .withColumnRenamed("orderPlatform", "order_platform")\
                        .drop("op")

    #create dataframe with new columns using withColumn()
    orders_final_df = renamed_orders\
                        .withColumn("order_year", year(col("order_date")))\
                        .withColumn("order_year_pk", year(col("order_date")))\
                        .withColumn("order_month", month(col("order_date")))\
                        .withColumn("ingestion_date", current_date())\
                        .orderBy(col("order_date").desc())


    #create glue dynamicframe from the dataframe
    orders_final_dyf = DynamicFrame.fromDF(orders_final_df,glueContext,"product_final_dyf")  

    #Write rows to S3 as Parquet
    glueContext.write_dynamic_frame.from_options(
        frame = orders_final_dyf,
        connection_type = "s3",    
        connection_options = {"path": f"s3://{bucket}/{processed_folder_name}/{db_name}/{table_name}/", "partitionKeys": ["order_year_pk"]},
        format = "parquet",
        transformation_ctx = "orders_final_dyf"
    )
else:
        print("No new records found in the source data. Skipping further processing.")

job.commit()  