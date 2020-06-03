#!/bin/bash

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

brew install cask
brew cask install mactex
brew cask install dotnet-sdk
brew cask install java

