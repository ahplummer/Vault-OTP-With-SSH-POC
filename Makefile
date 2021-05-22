.PHONY: help build run bootstrap teardown login
default: help

help:
	@echo '>make help 				/ this screen'
	@echo '>make build				/ Docker build command'
	@echo '>make bootstrap 			/ runs the docker container, builds infra'
	@echo '>make loginwithkey			/ runs the docker container, logs in, leveraging AWS SecretsManager'
	@echo '>make configurevault			/ runs the docker container, configuresvault environment'
	@echo '>make adduser				/ runs the docker container, adds a user'
	@echo '>make teardown 				/ runs the docker container, tears down things'
	@echo '>make cli				/ runs plain ole zsh'

bootstrap: build
	docker run -v $(CURDIR):/host -v ~/.aws:/root/.aws -it sshpoc:latest /bin/sh -c 'cd /host/dockerscripts; /host/dockerscripts/bootstrap.sh'

loginwithkey: 
	docker run -v $(CURDIR):/host -v ~/.aws:/root/.aws -it sshpoc:latest /bin/sh -c 'cd /host/infra; /host/infra/loginwithkey.sh $(server)'

loginOTP: 
	docker run -v $(CURDIR):/host -v ~/.aws:/root/.aws -it sshpoc:latest /bin/sh -c 'cd /host/dockerscripts; /host/dockerscripts/vault.sh loginOTP $(user) $(password) $(server)'

configurevault: 
	docker run -v $(CURDIR):/host -v ~/.aws:/root/.aws -it sshpoc:latest /bin/sh -c 'cd /host/dockerscripts; /host/dockerscripts/vault.sh init'

adduser: 
	docker run -v $(CURDIR):/host -v ~/.aws:/root/.aws -it sshpoc:latest /bin/sh -c 'cd /host/dockerscripts; /host/dockerscripts/vault.sh addUser $(user) $(password)'

teardown:
	docker run -v $(CURDIR):/host -v ~/.aws:/root/.aws -it sshpoc:latest /bin/sh -c 'cd /host/dockerscripts; /host/dockerscripts/teardown.sh'

build:
	docker build -t sshpoc:latest .

cli: 
	docker run -v $(CURDIR):/host -v ~/.aws:/root/.aws -it sshpoc:latest /bin/zsh