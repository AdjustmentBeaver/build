# OP-TEE build.git

## Contents
1. [Get and build the solution](#7-get-and-build-the-solution)
2. [FAQ](#8-faq)

# 1. Get and build the solution
Below we will describe the general way of getting the source, building the
solution and how to run xtest on the device. For device specific instructions,
see the respective `device.md` file in the [docs] folder.

## 1.1 Prerequisites
We believe that you can use any Linux distribution to build OP-TEE, but as
maintainers of OP-TEE we are mainly using Ubuntu-based distributions and to be
able to build and run OP-TEE there are a few packages that needs to be installed
to start with. Therefore install the following packages regardless of what
target you will use in the end.

```bash
$ sudo apt-get install android-tools-adb android-tools-fastboot autoconf \
	automake bc bison build-essential cscope curl device-tree-compiler flex \
	ftp-upload gdisk iasl libattr1-dev libc6:i386 libcap-dev libfdt-dev \
	libftdi-dev libglib2.0-dev libhidapi-dev libncurses5-dev \
	libpixman-1-dev libssl-dev libstdc++6:i386 libtool libz1:i386 make \
	mtools netcat python-crypto python-serial python-wand unzip uuid-dev \
	xdg-utils xterm xz-utils zlib1g-dev git repo
```

## 1.2 Get the source code
```bash
$ mkdir -p $HOME/devel/optee
$ cd $HOME/devel/optee
$ repo init -u https://github.com/AdjustmentBeaver/gateway.git -m repo/rpi3.xml
$ repo sync
```

## 1.3 Build the solution
```bash
$ cd build
$ make
```
This step will also take some time, but you can speed up subsequent builds by
enabling [ccache] (again see Tips and Tricks).

## 1.4 Flash the device
```bash
$ make img-help
```

## 1.5 Boot up the device

## 1.6 Load tee-supplicant
On some solutions tee-supplicant is already loaded (`$ ps aux | grep
tee-supplicant`) on other not. If it's not loaded, then start it by running:
```bash
$ tee-supplicant &
```

If you've built using our manifest you should not need to modprobe any
OP-TEE/TEE kernel driver since it's built into the kernel in all our setups.

## 1.7 Run xtest
The entire xtest test suite has been deployed when you we're running `$ make
run` in previous step, i.e, in general there is no need to copy any binaries
manually. Everything has been put into the root FS automatically. So, to run
xtest, you simply type:
```bash
$ xtest
```

If there are no regressions / issues found, xtest should end with something like
this:
```bash
+-----------------------------------------------------
23476 subtests of which 0 failed
67 test cases of which 0 failed
0 test case was skipped
TEE test application done!
```

## 1.8 Tips and Tricks
### 1.8.1 Reference existing project to speed up repo sync
Doing a `repo init`, `repo sync` from scratch can take a fair amount of time.
The main reason for that is simply because of the size of some of the gits we
are using, like for the Linux kernel and EDK2. With repo you can reference an
existing forest and by doing so you can speed up repo sync to taking 20 seconds
instead of an hour. The way to do this are as follows.

1. Start by setup a clean forest that you will not touch, in this example, let
   us call that `optee-ref` and put that under for `$HOME/devel/optee-ref`. This
   step will take roughly an hour.
2. Then setup a cronjob (`crontab -e`) that does a `repo sync` in this folder
   particular folder once a night (that is more than enough).
3. Now you should setup your actual tree which you are going to use as your
   working tree. The way to do this is almost the same as stated in the
   instructions above, the only difference is that you reference the other local
   forest when running `repo init`, like this
   ```
   repo init -u https://github.com/OP-TEE/manifest.git --reference /home/jbech/devel/optee-ref
   ```
4. The rest is the same above, but now it will only take a couple of seconds to
   clone a forest.

Normally step 1 and 2 above is something you will only do once. Also if you
ignore step 2, then you will still get the latest from official git trees, since
repo will also check for updates that aren't at the local reference.

### 1.8.2 Use ccache
ccache isfaqa tool that caches build object-files etc locally on the disc and can
speed up build time significantly in subsequent builds. On Debian-based systems
(Ubuntu, Mint etc) you simply install it by running:
```
$ sudo apt-get install ccache
```

The makefiles in build.git are configured to automatically find and use ccache
if ccache is installed on your system, so other than having it installed you
don't have to think about anything.

# 2. FAQ
Please have a look at out [FAQ] file for a list of questions commonly asked.

[ccache]: https://ccache.samba.org
[docs]: docs
[FAQ]: faq.md
[git submodules]: https://git-scm.com/book/en/v2/Git-Tools-Submodules
[manifest/README.md]: https://github.com/OP-TEE/manifest/blob/master/README.md
[MAINTAINERS.md]: https://github.com/OP-TEE/optee_os/blob/master/MAINTAINERS.md
[OP-TEE/README.md]: https://github.com/OP-TEE/optee_os/blob/master/README.md
[repo]: https://source.android.com/source/downloading.html
