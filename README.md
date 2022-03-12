# Snowflake

Pastebin, but for Neverwinter Nights characters.

![Banner Image](../blob/master/src/static/images/opengraph-logo.jpg)

## Contents

[Why?](#why)

[Self-Hosting](#self-hosting)

[Hacking](#hacking)

[License](#license)

[Contributions](#contributions)

## Why?

Because I wanted something like this, basically. I've also been curious about
[Nim](https://nim-lang.org/) and felt like a project with that language was
in order. There's an excellent Nim [library](https://github.com/niv/neverwinter.nim) for handling NWN's various
file formats, authored by Niv and contributors, that I've leveraged here.

I write software professionally, but this is my sole project in Nim. So, fair
warning: the code is probably a bit scuffy. It should at least be readable,
and most of it is written in a straight-line, procedural style. Idiomatic?
Probably not. Or at least not yet, if I circle back and clean this up.

## Self-Hosting

As [free software](https://en.wikipedia.org/wiki/Free_software), Snowflake is
yours to self-host and extend as you see fit, subject to the terms of the 
[license](https://github.com/wyrdwinter/snowflake/blob/master/LICENSE).

For your own personal use, the easiest way to do this is by following the
instructions in the [hacking](#hacking) section to run a local copy of
the application.

If you're on Linux or MacOS, the instructions there should be straightforward.
If you're a Windows user, you'll probably want to look at [WSL](https://docs.microsoft.com/en-us/windows/wsl/about), since
the build script is written in shell and the tooling should work fine on the
Linux subsystem.

If you're intending to host Snowflake for your Neverwinter Nights group,
then it's probably worth spooling up a VPS and following the provisioning
script in the `Vagrantfile` to get everything configured. I tend to like
[AlmaLinux](https://almalinux.org/), but you could easily deploy the
application on any of the major Linux distributions.

## Hacking

You'll probably want to be familiar with [Nim](https://nim-lang.org/), [React](https://reactjs.org/), and various foundational
web technologies.

You'll also need [Vagrant](https://www.vagrantup.com/), which instantiates a
virtual machine and automates the setup for requisite services.

The easiest way to get started is by cloning the repository and spooling up 
a Vagrant guest:

```sh
$ git clone https://github.com/wyrdwinter/snowflake
$ cd snowflake
$ vagrant up && vagrant ssh
```

Then, once Vagrant has provisioned everything, you can fire up the application
on the guest:

```sh
$ cd snowflake
$ ./build
$ ./snowflake
```

Guide your web browser to `http://localhost:8080` and voila.

By default, Vagrant will run two web servers: [Nginx](https://www.nginx.com/) as a reverse proxy and
cache, and Nim's [built-in web server](https://nim-lang.org/docs/asynchttpserver.html) for the Snowflake application. This can be
annoying to deal with during development, and you may want to disable [Nginx](https://www.nginx.com/).

On the guest, stop the service:

```sh
$ sudo systemctl stop nginx.service
```

On the host, change this line in the Vagrantfile:

```ruby
config.vm.network "forwarded_port", guest: 80, host: 8080
```

To this:

```ruby
config.vm.network "forwarded_port", guest: 5000, host: 8080
```

Then restart the Vagrant guest:

```sh
$ vagrant halt && vagrant up && vagrant ssh
```

Whatever changes you make to the Snowflake application will be visible on a
normal recompile and page refresh.

## License

Snowflake is licensed under the AGPLv3; see [LICENSE](https://github.com/wyrdwinter/snowflake/blob/master/LICENSE) for details.

Images are used under non-profit fair use; they, as well as the contents of
.2da and .tlk files, are copyright their respective creators.

## Contributions

Are welcomed. Submit your pull requests.
