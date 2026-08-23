8/23/
Terraform Agentics:

"Generate the smallest, most cost-effective AWS Backup infrastructure in Terraform to test compliance for the following AWS Config rules: backup-recovery-point-encrypted, backup-plan-min-frequency-and-min-retention-check, backup-recovery-point-minimum-retention-check, and backup-recovery-point-manual-deletion-disabled.Include the following parameters:A minimal Backup Vault utilizing AWS Backup Vault Lock configured strictly in Governance mode (to allow terraform destroy).A Backup Plan using a standard cron schedule, configured for a mock 1-day backup retention period to minimize costs.A minimal mock target resource (such as a small, unattached 1 GiB EBS volume) and its corresponding Backup Selection so actual recovery points can be generated for evaluation.Do not generate any AWS Config rule testing resources, just the core backup infrastructure."

#rstats.py dump forensics from SID


efs-access-point-enforce-root-directory

fsx-windows-deployment-type-check
backup-recovery-point-encrypted
fsx-lustre-copy-tags-to-backups



Your terminal output proves you are logged into a Member Account (or an account that has not been designated as the delegated administrator for AWS Config).
aws configservice describe-config-rules \
  --query "ConfigRules[?contains(ConfigRuleName, 'efs')].ConfigRuleName"
  [
    "efs-access-point-enforce-root-directory-conformance-pack-hbmlt5imw",
    "efs-access-point-enforce-user-identity-conformance-pack-hbmlt5imw",
    "efs-automatic-backups-enabled-conformance-pack-hbmlt5imw",
    "efs-encrypted-check-conformance-pack-hbmlt5imw",
    "efs-filesystem-ct-encrypted-conformance-pack-hbmlt5imw",
    "efs-in-backup-plan-conformance-pack-hbmlt5imw",
    "efs-mount-target-public-accessible-conformance-pack-hbmlt5imw",
    "efs-resources-protected-by-backup-plan-conformance-pack-hbmlt5imw"
]


aws configservice start-config-rules-evaluation --config-rule-names "efs-access-point-enforce-root-directory-conformance-pack-hbmlt5imw"

ubuntu@ip-10-0-1-190:~/repos/awsresources$ aws configservice start-config-rules-evaluation --config-rule-names "efs-access-point-enforce-root-directory-conformance-pack-hbmlt5imw"
ubuntu@ip-10-0-1-190:~/repos/awsresources$ aws configservice get-compliance-details-by-resource \
  --resource-type AWS::EFS::AccessPoint \
  --resource-id fsap-02ef604c893428543
{
    "EvaluationResults": []
}
ubuntu@ip-10-0-1-190:~/repos/awsresources$ aws configservice get-compliance-details-by-resource \
  --resource-type AWS::EFS::AccessPoint \
  --resource-id fsap-0d3ce11d0b4bf2590
{
    "EvaluationResults": []
}

1. Trigger an Account-Wide Discovery ScanInstead of calling the rule, tell the local recorder to immediately analyze all untracked infrastructure changes in your account:bash

aws configservice start-configuration-recorder --configuration-recorder-name default

# Check Non-Compliant configuration parameters
aws efs describe-access-points --access-point-id fsap-02ef604c893428543 --query "AccessPoints[*].RootDirectory.Path"

# Check Compliant configuration parameters
aws efs describe-access-points --access-point-id fsap-0d3ce11d0b4bf2590 --query "AccessPoints[*].RootDirectory.Path"

------------------
Local redux
Force Instant Evaluation:Because this rule is owned entirely by your account, it will respond to your manual CLI triggers:



  

