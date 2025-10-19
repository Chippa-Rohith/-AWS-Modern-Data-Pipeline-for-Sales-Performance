{
  "Comment": "A description of my state machine",
  "StartAt": "Parallel",
  "States": {
    "Parallel": {
      "Type": "Parallel",
      "Next": "wait_5_seconds",
      "Branches": [
        {
          "StartAt": "Glue StartJobRun",
          "States": {
            "Glue StartJobRun": {
              "Type": "Task",
              "Resource": "arn:aws:states:::glue:startJobRun.sync",
              "Arguments": {
                "JobName": "sales-pipeline-customer-etl-job"
              },
              "End": true
            }
          }
        },
        {
          "StartAt": "Glue StartJobRun (1)",
          "States": {
            "Glue StartJobRun (1)": {
              "Type": "Task",
              "Resource": "arn:aws:states:::glue:startJobRun.sync",
              "Arguments": {
                "JobName": "sales-pipeline-product-etl-job"
              },
              "End": true
            }
          }
        },
        {
          "StartAt": "Glue StartJobRun (3)",
          "States": {
            "Glue StartJobRun (3)": {
              "Type": "Task",
              "Resource": "arn:aws:states:::glue:startJobRun.sync",
              "Arguments": {
                "JobName": "sales-pipeline-orders-etl-job"
              },
              "End": true
            }
          }
        },
        {
          "StartAt": "Glue StartJobRun (2)",
          "States": {
            "Glue StartJobRun (2)": {
              "Type": "Task",
              "Resource": "arn:aws:states:::glue:startJobRun.sync",
              "Arguments": {
                "JobName": "sales-pipeline-orderdetails-etl-job"
              },
              "End": true
            }
          }
        }
      ]
    },
    "wait_5_seconds": {
      "Type": "Wait",
      "Seconds": 5,
      "Next": "parallel_load_dimensions"
    },
    "parallel_load_dimensions": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "glue_product_load_job",
          "States": {
            "glue_product_load_job": {
              "Type": "Task",
              "Resource": "arn:aws:states:::glue:startJobRun.sync",
              "Arguments": {
                "JobName": "sales-pipeline-product-to-redshift-job"
              },
              "Next": "sp_merge_dim_product"
            },
            "sp_merge_dim_product": {
              "Type": "Task",
              "Arguments": {
                "Sql": "CALL sales.sp_merge_dim_product();",
                "Database": "production",
                "SecretArn": "${redshift_secret_arn}",
                "WorkgroupName": "${workgroup_name}"
              },
              "Resource": "arn:aws:states:::aws-sdk:redshiftdata:executeStatement",
              "Next": "wait_on_sp_merge_dim_product",
              "Assign": {
                "statementId1": "{% $states.result.Id %}"
              }
            },
            "wait_on_sp_merge_dim_product": {
              "Type": "Wait",
              "Seconds": 5,
              "Next": "sp_merge_dim_product_status_check"
            },
            "sp_merge_dim_product_status_check": {
              "Type": "Task",
              "Arguments": {
                "Id": "{% $statementId1  %}"
              },
              "Resource": "arn:aws:states:::aws-sdk:redshiftdata:describeStatement",
              "Next": "product_dim_pass_to_next",
              "Assign": {
                "statementStatus1": "{% $states.result.Status %}"
              }
            },
            "product_dim_pass_to_next": {
              "Type": "Choice",
              "Choices": [
                {
                  "Next": "Pass",
                  "Condition": "{% ($statementStatus1) = (\"FINISHED\") %}"
                },
                {
                  "Next": "Fail",
                  "Condition": "{% ($statementStatus1) = (\"FAILED\") %}"
                }
              ],
              "Default": "wait_on_sp_merge_dim_product"
            },
            "Pass": {
              "Type": "Pass",
              "End": true
            },
            "Fail": {
              "Type": "Fail"
            }
          }
        },
        {
          "StartAt": "glue_customer_load_job",
          "States": {
            "glue_customer_load_job": {
              "Type": "Task",
              "Resource": "arn:aws:states:::glue:startJobRun.sync",
              "Arguments": {
                "JobName": "sales-pipeline-customer-to-redshift-job"
              },
              "Next": "sp_merge_dim_customer"
            },
            "sp_merge_dim_customer": {
              "Type": "Task",
              "Resource": "arn:aws:states:::aws-sdk:redshiftdata:executeStatement",
              "Arguments": {
                "Sql": "CALL sales.sp_merge_dim_customer();",
                "Database": "production",
                "SecretArn": "${redshift_secret_arn}",
                "WorkgroupName": "${workgroup_name}"
              },
              "Next": "wait_on_sp_merge_dim_customer",
              "Assign": {
                "statementId2": "{% $states.result.Id %}"
              }
            },
            "wait_on_sp_merge_dim_customer": {
              "Type": "Wait",
              "Seconds": 5,
              "Next": "sp_merge_dim_customer_status_check"
            },
            "sp_merge_dim_customer_status_check": {
              "Type": "Task",
              "Resource": "arn:aws:states:::aws-sdk:redshiftdata:describeStatement",
              "Arguments": {
                "Id": "{% $statementId2  %}"
              },
              "Next": "customer_dim_pass_to_next",
              "Assign": {
                "statementStatus2": "{% $states.result.Status %}"
              }
            },
            "customer_dim_pass_to_next": {
              "Type": "Choice",
              "Choices": [
                {
                  "Next": "Pass (1)",
                  "Condition": "{% ($statementStatus2) = (\"FINISHED\") %}"
                },
                {
                  "Next": "Fail (1)",
                  "Condition": "{% ($statementStatus2) = (\"FAILED\") %}"
                }
              ],
              "Default": "wait_on_sp_merge_dim_customer"
            },
            "Pass (1)": {
              "Type": "Pass",
              "End": true
            },
            "Fail (1)": {
              "Type": "Fail"
            }
          }
        }
      ],
      "Next": "parallel_load_facts"
    },
    "parallel_load_facts": {
      "Type": "Parallel",
      "Branches": [
        {
          "StartAt": "glue_order_load_job",
          "States": {
            "glue_order_load_job": {
              "Type": "Task",
              "Resource": "arn:aws:states:::glue:startJobRun.sync",
              "Arguments": {
                "JobName": "sales-pipeline-orders-to-redshift-job"
              },
              "End": true
            }
          }
        },
        {
          "StartAt": "glue_orderdetails_load_job",
          "States": {
            "glue_orderdetails_load_job": {
              "Type": "Task",
              "Resource": "arn:aws:states:::glue:startJobRun.sync",
              "Arguments": {
                "JobName": "sales-pipeline-orderdetails-to-redshift-job"
              },
              "End": true
            }
          }
        }
      ],
      "Next": "Success"
    },
    "Success": {
      "Type": "Succeed"
    }
  },
  "QueryLanguage": "JSONata"
}