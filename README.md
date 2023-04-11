
# aws_res_hub_poc

Author: https://www.linkedin.com/in/danut/

This set of examples will help us learn what AWS Resilience Hub can detect and how to fix the issue to deploy a Resilient Workload.

I build these examples based on this documentation.

https://aws.amazon.com/blogs/architecture/building-resilient-well-architected-workloads-using-aws-resilience-hub/

The folders starting with **cf** are for CloudFormation, and those starting with **tf** are for Terraform.

The **_1** folder is for creating resources with little or no resilience. You should see many policies broken if you run a Resilience Hub assessment.

The **_2** folder is for creating resources that provide resilience. In The Resilience Hub, everything should be green after running the assessment.
