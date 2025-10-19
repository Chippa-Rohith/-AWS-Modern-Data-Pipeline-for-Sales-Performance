output "rds_endpoint" {
  value = aws_db_instance.mysql.address
}

output "rds_secret_arn" {
  value = aws_secretsmanager_secret.rds.arn
}


output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "ssh_tunnel_command" {
  value = "ssh -i /path/to/your/key.pem -L 3306:${aws_db_instance.mysql.address}:3306 ec2-user@${aws_instance.bastion.public_ip}"
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "secret_arn" {
  value = aws_secretsmanager_secret.rds.arn
}
