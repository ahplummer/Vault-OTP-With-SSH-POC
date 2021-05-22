# Intro
This stands up a regular EC2 to test with, along with an EC2 with Vault installed.

The purpose is to show how Vault can handle one-time-passwords for a fleet of servers; thus keeping away from SSH key sprawl.

This is working [this tutorial](https://learn.hashicorp.com/tutorials/vault/ssh-otp), but with Makefile / Dockerfile automation.

This works everything (aws, vault, terraform) inside of a self contained docker, so no other tooling besides make/docker are required.

## Requirements
* Docker installed
* Make installed and usable


# Docker Usage
* Execute `make bootstrap`. This builds the infrastructure.
* Test servers by executing `make loginwithkey server=example-ec2`, using the server names that you entered in the previous step. (vault-ec2 and example-ec2 are the default)
* Wait about a minute or so for Vault to stand up.
* Execute `make configurevault` to setup Vault for OTP.
Note: If you throw errors, delete the `vault.env` file, and wait a minute, then re-attempt the `configurevault` command.
* Create a user: `make adduser user="<user>" password="<password>"` (example: `make adduser user="jimmy" password="jimmy"`)
* Login now as OTP: `make loginOTP user=jimmy password=jimmy server=example-ec2`
* Execute `make teardown`. This destroys the infrastructure.

