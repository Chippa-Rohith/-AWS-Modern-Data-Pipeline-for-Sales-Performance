"""%%configure 
{
  "--job-bookmark-option": "job-bookmark-enable"
} """   

#import all libraries
import sys
from pyspark.context import SparkContext
from awsglue.context import GlueContext	
from pyspark.sql.functions import sha2, concat_ws, col, current_timestamp, lit, current_date, round
from pyspark.sql.types import DateType, TimestampType
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


#Create a dataframe from the catalog
products_df_from_catalog = glueContext.create_data_frame_from_catalog(glue_database, glue_table_name,additional_options = {"useCatalogSchema": True}, transformation_ctx = "products_df_from_catalog" )

# Check if the DataFrame has records before processing
if products_df_from_catalog.count() > 0:
    
    
    #Create a new dataframe and rename the existing columns to use snake-case
    renamed_products = products_df_from_catalog.withColumnRenamed("productid","product_id")\
                        .withColumnRenamed("op", "cdc_operation")\
                        .withColumnRenamed("productname","product_name")\
                        .withColumnRenamed("brandname","brand_name")\
                        .withColumnRenamed("productdescription","product_description")\
                        .withColumnRenamed("price","product_price")\
                        .withColumnRenamed("productcategory","product_category")

    #Create a function to generate hash value from all variable columns in the product dimension
    concatenated_product_fields = concat_ws(''\
                                        , col("product_name")\
                                        , col("brand_name")\
                                        , col("product_description")\
                                        , col("product_price")\
                                        , col("product_category"))

    #Create default values and timestamp for the new columns

    current_ts = current_timestamp()
    current_date = current_date()

    record_end_ts = lit('9999-12-31').cast(TimestampType())
    active_flag = lit(1)

    # Create new dataframw with new columns using withColumn() and round the price to 2 decimal places
    product_final_df = renamed_products.withColumn("hash_value",sha2(concatenated_product_fields, 256))\
                        .withColumn("record_start_ts",current_ts)\
                        .withColumn("record_end_ts",record_end_ts)\
                        .withColumn("ingestion_date",current_date)\
                        .withColumn("active_flag",active_flag)\
                        .withColumn("product_price",round(col("product_price"),2))


    #Convert to dataframe to glue Dynamic Frame
    product_final_dyf = DynamicFrame.fromDF(product_final_df,glueContext,"product_final_dyf")  	

    #Write transformed data back to Amazon S3 in parquet format
    glueContext.write_dynamic_frame.from_options(
        frame = product_final_dyf,
        connection_type = "s3",    
        connection_options = {"path": "s3://" + bucket +"/"+processed_folder_name+"/"+db_name+"/"+table_name+"/", "partitionKeys": ["ingestion_date"]},
       format = "parquet",transformation_ctx = "products_dyf_to_S3")


else:
    print("No records found in the source data. Skipping further processing.")
    

#Commit the job
job.commit()