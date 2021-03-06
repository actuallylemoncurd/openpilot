#!/usr/bin/bash -e

SOURCE_DIR=/data/openpilot_source
TARGET_DIR=/data/openpilot

ln -sf $TARGET_DIR /data/pythonpath

export GITHUB_REPO="jyoung8607/openpilot.git"
export GIT_COMMITTER_NAME="Jason Young"
export GIT_COMMITTER_EMAIL="jyoung8607@gmail.com"
export GIT_AUTHOR_NAME="Jason Young"
export GIT_AUTHOR_EMAIL="jyoung8607@gmail.com"
export GIT_SSH_COMMAND="ssh -i /data/gitkey"

echo "[-] Setting up repo T=$SECONDS"
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p $TARGET_DIR
  cd $TARGET_DIR
  git init
  git remote add origin git@github.com:$GITHUB_REPO
fi

echo "[-] fetching public T=$SECONDS"
cd $TARGET_DIR
git prune || true
git remote prune origin || true

echo "[-] bringing master-ci and devel in sync T=$SECONDS"
git fetch origin master
git fetch origin devel

git checkout -f --track origin/master
git reset --hard master
git checkout master
git reset --hard origin/devel
git clean -xdf

# remove everything except .git
echo "[-] erasing old openpilot T=$SECONDS"
find . -maxdepth 1 -not -path './.git' -not -name '.' -not -name '..' -exec rm -rf '{}' \;

# reset tree and get version
cd $SOURCE_DIR
git clean -xdf
git checkout -- selfdrive/common/version.h

VERSION=$(cat selfdrive/common/version.h | awk -F\" '{print $2}')
echo "#define COMMA_VERSION \"$VERSION-release\"" > selfdrive/common/version.h

# do the files copy
echo "[-] copying files T=$SECONDS"
cd $SOURCE_DIR
cp -pR --parents $(cat release/files_common) $TARGET_DIR/

# in the directory
cd $TARGET_DIR

rm -f panda/board/obj/panda.bin.signed

echo "[-] committing version $VERSION T=$SECONDS"
git add -f .
git status
git commit -a -m "openpilot v$VERSION release"

# Run build
SCONS_CACHE=1 scons -j3

echo "[-] testing panda build T=$SECONDS"
pushd panda/board/
make bin
popd

echo "[-] testing pedal build T=$SECONDS"
pushd panda/board/pedal
make obj/comma.bin
popd

if [ ! -z "$CI_PUSH" ]; then
  echo "[-] Pushing to $CI_PUSH T=$SECONDS"
  git remote set-url origin git@github.com:$GITHUB_REPO
  git push -f origin master:$CI_PUSH
fi

echo "[-] done T=$SECONDS"
