https://github.com/rtrivgreg/awsresources.git
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

efs-access-point-enforce-root-directory

fsx-windows-deployment-type-check
backup-recovery-point-encrypted
fsx-lustre-copy-tags-to-backups

export AWS_ACCESS_KEY_ID="AKIAWCZC53GAX34VIJMZ"
export AWS_SECRET_ACCESS_KEY="3Zo2/udDylewyVcPBVnW1c6PXwJACFXfQdMoOZkz"
export AWS_DEFAULT_REGION="us-east-1"

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


  

