8/23/
Terraform Agentics:

EC2
critique this request "generate the smallest, least expensive AWS backup-Recovery resource in terraform  that will be used to test compliance and non-compliance for the following AWS Config rules: ec2-ebs-encryption-by-default, ec2-launch-templates-ebs-volume-encrypted, ec2-spot-fleet-request-ct-encryption-at-rest.  Do not generate any tests, just the infrastructure that will satisfy this requirement"

Generate the smallest, most cost-effective EC2 infrastructure in Terraform to test compliance and non-compliance for the following AWS Config rules: ec2-ebs-encryption-by-default, ec2-launch-templates-ebs-volume-encrypted, and ec2-spot-fleet-request-ct-encryption-at-rest.Include the following parameters:An account-level aws_ebs_encryption_by_default resource with a comment explaining how to toggle it for account-wide compliance testing.Two minimal EC2 Launch Templates: one configured with an encrypted EBS block device mapping (Compliant), and one with an unencrypted mapping (Non-Compliant).Two minimal EC2 Spot Fleet Requests referencing the launch templates, using a target capacity of 0 (or a placeholder setup) to prevent actual instance billing while allowing AWS Config to evaluate the request parameters.Do not generate any AWS Config rule resources or software test wrappers, just the core infrastructure blocks. Incorporate commented introduction at the top of the terraform code that summarizes the AWS Config rule coverage in the context of storage in bullet points.

Backup
Generate the smallest, most cost-effective AWS Backup infrastructure in Terraform to test compliance for the following AWS Config rules: backup-recovery-point-encrypted, backup-plan-min-frequency-and-min-retention-check, backup-recovery-point-minimum-retention-check, and backup-recovery-point-manual-deletion-disabled.Include the following parameters:A minimal Backup Vault utilizing AWS Backup Vault Lock configured strictly in Governance mode (to allow terraform destroy).A Backup Plan using a standard cron schedule, configured for a mock 1-day backup retention period to minimize costs.A minimal mock target resource (such as a small, unattached 1 GiB EBS volume) and its corresponding Backup Selection so actual recovery points can be generated for evaluation.Do not generate any AWS Config rule testing resources, just the core backup infrastructure. Incorporate commented introduction at the top of the terraform code that summarizes the AWS Config rule coverage in the context of storage in bullet points.

S3

generate the smallest, least expensive AWS backup-Recovery resource in terraform that will be used to test compliance and non-compliance for the following AWS Config rules: s3express-dir-bucket-lifecycle-rules-check, s3-access-point-in-vpc-only, s3-bucket-policy-not-more-permissive, s3-meets-restore-time-target, s3-access-point-public-access-blocks. Do not generate any tests, just the infrastructure that will satisfy this requirement

Generate the smallest, most cost-effective S3 Standard and S3 Express Directory Bucket infrastructure in Terraform to test compliance and non-compliance pairs for the following AWS Config rules:s3express-dir-bucket-lifecycle-rules-check (Directory Bucket pair)s3-access-point-in-vpc-only & s3-access-point-public-access-blocks (Standard Bucket + Access Point pairs)s3-bucket-policy-not-more-permissive (Standard Bucket + Bucket Policy pairs)s3-meets-restore-time-target (Standard Bucket configuration)For each rule, include one compliant resource block and one non-compliant resource block. Keep all configurations empty of data to eliminate ingestion and storage costs. Do not generate the AWS Config rules themselves, only the target infrastructure. Incorporate commented introduction at the top of the terraform code that summarizes the AWS Config rule coverage in the context of storage in bullet points.


EFS 
critique this request "generate the smallest, least expensive AWS backup-Recovery resource in terraform that will be used to test compliance and non-compliance for the following AWS Config rules: efs-in-backup-plan, efs-filesystem-ct-encrypted, efs-access-point-enforce-root-directory, efs-mount-target-public-accessible, efs-resources-protected-by-backup-plan, efs-automatic-backups-enabled, efs-access-point-enforce-user-identity ans efs-encrypted-check. Do not generate any tests, just the infrastructure that will satisfy this requirement"

Generate the minimal, lowest-cost Amazon EFS and AWS Backup infrastructure in Terraform to test AWS Config rules.For each of the following rules, create two versions of the resource—one that is COMPLIANT and one that is NON_COMPLIANT:efs-in-backup-planefs-filesystem-ct-encryptedefs-access-point-enforce-root-directoryefs-mount-target-public-accessibleefs-resources-protected-by-backup-planefs-automatic-backups-enabledefs-access-point-enforce-user-identityefs-encrypted-checkDo not generate any testing code, assertions, or deployment scripts. Provide only valid Terraform code containing the EFS filesystems, access points, mount targets, networks, backup plans, and backup selections required to trigger these distinct states. Incorporate commented introduction at the top of the terraform code that summarizes the AWS Config rule coverage in the context of storage in bullet points.



  

