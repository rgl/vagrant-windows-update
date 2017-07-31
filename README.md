# Vagrant Windows Update Provisioner

[![Latest version released](https://img.shields.io/gem/v/vagrant-windows-update.svg)](https://rubygems.org/gems/vagrant-windows-update)
[![Package downloads count](https://img.shields.io/gem/dt/vagrant-windows-update.svg)](https://rubygems.org/gems/vagrant-windows-update)

This is a Vagrant plugin for installing Windows updates.

**NB** This was only tested with Vagrant 1.9.2 and Windows Server 2016.

# Installation

```bash
vagrant plugin install vagrant-windows-update
```

# Usage

Add `config.vm.provision "windows-update"` to your `Vagrantfile` to update your
Windows VM during provisioning or manually run the provisioner with:

```bash
vagrant provision --provision-with windows-update
```

To troubleshoot, set the `VAGRANT_LOG` environment variable to `debug`.

## Example

In this repo there's an example [Vagrantfile](Vagrantfile). Use it to launch
an example.

First install the [Base Windows Box](https://github.com/rgl/windows-2016-vagrant).

Then install the required plugins:

```bash
vagrant plugin install vagrant-windows-update
vagrant plugin install vagrant-reload
```

Then launch the example:

```bash
vagrant up
```

**NB** On my machine this takes about 1h to complete... but YMMV!

# Development

To hack on this plugin you need to install [Bundler](http://bundler.io/)
and other dependencies. On Ubuntu:

```bash
sudo apt install bundler libxml2-dev zlib1g-dev
```

Then use it to install the dependencies:

```bash
bundle
```

Build this plugin gem:

```bash
rake
```

Then install it into your local vagrant installation:

```bash
vagrant plugin install pkg/vagrant-windows-update-*.gem
```

You can later run everything in one go:

```bash
rake && vagrant plugin uninstall vagrant-windows-update && vagrant plugin install pkg/vagrant-windows-update-*.gem
```
