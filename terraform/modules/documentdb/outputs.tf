output "cluster_endpoint"       { value = aws_docdb_cluster.main.endpoint }
output "reader_endpoint"        { value = aws_docdb_cluster.main.reader_endpoint }
output "secret_arn"             { value = aws_secretsmanager_secret.docdb_master.arn }
output "security_group_id"      { value = aws_security_group.docdb.id }
output "kms_key_arn"            { value = aws_kms_key.docdb.arn }
