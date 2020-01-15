appget install chrome
appget install teams
appget install handbrake
appget install teamviewer
appget install spotify
appget install du-meter
appget install slack

python -m pip install --upgrade pip
pip install distribute
pip install pygments

cpan -f -i Unicode::GCString
cpan -f -i YAML::Tiny
cpan -f -i Log::Dispatch::File
cpan -f -i Log::Log4perl

# cd %userprofile%/.ssh
# ssh-keygen -t rsa -b 4096 -C "jakob@hviidnet.com"

powershell Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
