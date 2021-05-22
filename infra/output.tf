#Put your output vars here...
output "publicIPRegular" {
   value = aws_instance.regularserver.public_ip
}
output "publicIPVault" {
   value = aws_instance.vaultserver.public_ip
}
output "SecretARN" {
    value = aws_secretsmanager_secret.instancekey.arn
}