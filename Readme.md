# Intro
This stands up a regular EC2 to test with, along with an EC2 with Vault installed.

The purpose is to show how Vault can handle one-time-passwords for a fleet of servers; thus keeping away from SSH key sprawl.

# Requirements

## For Docker Execution (recommended)
* Docker
* Make system for your OS (to leverage the Makefile)

# Docker Usage
* Execute `make bootstrap`. This builds the infrastructure.
* Test servers by executing `make loginwithkey`, using the server names that you entered in the previous step. (vault-ec2 and example-ec2 are the default)
* Wait about a minute or so for Vault to stand up.
* Execute `make configurevault` to setup Vault for OTP.
Note: If you throw errors, delete the `vault.env` file, and wait a minute, then re-attempt the `configurevault` command.
* Create a user: `make adduser user="<user>" password="<password>"` (example: `make adduser user="jimmy" password="jimmy"`)
* Execute `make teardown`. This destroys the infrastructure.

