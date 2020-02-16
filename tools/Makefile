
install_awscliv2:
		curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "/tmp/AWSCLIV2.pkg"
		sudo installer -pkg /tmp/AWSCLIV2.pkg -target /
		rm /tmp/AWSCLIV2.pkg

upgrade_awscliv2: install_awscliv2

uninstall_awscliv2:
	sudo rm /usr/local/bin/aws
	sudo rm /usr/local/bin/aws_completer
	sudo rm -rf /usr/local/aws-cli

install_all: install_awscliv2

