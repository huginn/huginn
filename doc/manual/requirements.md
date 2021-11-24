# Requirements

## Operating Systems

### Supported Unix distributions by this guide

- Ubuntu (18.04, 16.04 and 14.04)
- Debian (Stretch and Jessie)

### Unsupported Unix distributions

- CentOS
- Red Hat Enterprise Linux
- OS X
- Arch Linux
- Fedora
- Gentoo
- FreeBSD

On the above unsupported distributions is still possible to install Huginn, and many people do. Follow the [installation guide](./installation.md) and substitute the `apt` commands with the corresponding package manager commands of your distribution.

### Non-Unix operating systems such as Windows

Huginn is developed for Unix operating systems.
Huginn does **not** run on Windows and we have no plans of supporting it in the near future.
Please consider using a virtual machine to run Huginn on Windows.

## Ruby versions

Huginn requires Ruby (MRI) 2.2 or 2.3.
You will have to use the standard MRI implementation of Ruby.
We love [JRuby](http://jruby.org/) and [Rubinius](http://rubini.us/) but Huginn needs several Gems that have native extensions.

## Hardware requirements

### CPU

- _single core_ setups will work but depending on the amount of Huginn Agents and users it will run a bit slower since the application server and background jobs can not run simultaneously
- _dual core_ setups are the **recommended** system/vps and will work well for a decent amount of Agents
- 3+ cores can be needed when running multiple DelayedJob workers

### Memory

You need at least 0.5GB of physical and 0.5GB of addressable memory (swap) to install and use Huginn with the default configuration!
With less memory you need to manually adjust the `Gemfile` and Huginn can respond with internal server errors when accessing the web interface.

- 256MB RAM + 0.5GB of swap is the absolute minimum but we strongly **advise against** this amount of memory. See the Wiki page about running Huginn on [systems with low memory](https://github.com/huginn/huginn/wiki/Running-Huginn-on-minimal-systems-with-low-RAM-&-CPU-e.g.-Raspberry-Pi)
- 0.5GB RAM + 0.5GB swap will work relatively well with SSD drives, but can feel a bit slow due to swapping
- 1GB RAM + 1GB swap will work with two unicorn workers and the threaded background worker
- **2GB RAM** is the **recommended** memory size, it will support 2 unicorn workers and both the threaded and the old separate workers
- for each 300MB of additional RAM you can run one extra DelayedJob worker

## Unicorn Workers

It's possible to increase the amount of unicorn workers and this will usually help for to reduce the response time of the applications and increase the ability to handle parallel requests.

For most instances we recommend using: CPU cores = unicorn workers.

If you have a 512MB machine we recommend to configure only one Unicorn worker and use the threaded background worker to prevent excessive swapping.


## DelayedJob Workers

A DelayedJob worker is a separate process which runs your Huginn Agents. It fetches Websites, polls external services for updates, etc. Depending on the amount of Agents and the check frequency of those you might need to run more than one worker (like it is done in the threaded setup).

Estimating the amount of workers needed is easy. One worker can perform just one check at a time.  
If you have 60 Agents checking websites every minute which take about 1 second to respond, one worker is fine.  
If you need more Agents or are dealing with slow/unreliable websites/services, you should consider running additional workers.
