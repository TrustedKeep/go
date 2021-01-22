# Building tkgo

## Merge in changes
```
git fetch upstream dev.boringcrypto.go1.15
git merge upstream/dev.boringcrypto.go1.15
```

## Update version
```
vi build_remote.sh

# modify the "export GOZIP..." line with newly merged version

...

export GOZIP=boringgo.1.15.6.tgz
export GOPATH=/root/sandbox

...

```

## Commit all updates

```
git add .
git commit -m "updating tkgo"
git push
```

## Run the remote build

The build.sh file will launch an EC2 instance, copy your ssh key and build_remote.sh up to it, then run the build.  It will copy the final file back to the local machine and destroy the EC2 instance.

```
./build.sh
```