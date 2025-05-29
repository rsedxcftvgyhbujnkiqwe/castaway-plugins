#!/bin/sh

sed -i "s/\/\/#define GIT_COMMIT/#define GIT_COMMIT/" scripting/reverts.sp
sed -i "s/%GIT_COMMIT%/$GIT_COMMIT/" scripting/reverts.sp
