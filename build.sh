#!/bin/bash

dirname="$(cd "$(dirname "$1")"; pwd -P)/$(basename "$1")"
ignores="build.sh modportal/ .DS_Store README.md .git/ .gitignore data/"
version=$(grep '"version"' info.json| cut -d ":" -f2 | sed 's/[", ]//g')
modname=$(grep '"name"' info.json| cut -d ":" -f2 | sed 's/[", ]//g')
release="${modname}_${version}"

# git=`which git`
# count=$($git status -su . | wc -l)
# if [ $count -gt 1 ]
# then
#     echo "Found uncommited files stopping"
#     exit 1;
# fi

# echo "Commiting version ${version} to tag"
# $(git commit -m "Updated mod to version ${version} for ${modname}" -- "${dirname}info.json")
# echo "Pushing version ${version} to origin"
# $(git tag -a "${modname}_${version}" -m "Build version ${modname} ${version}")
# gitres=$(git push origin "${modname}_${version}" 2>&1)
# gitres=gitres/$'\n'/' '
# #
# if [[ $gitres == *"tag already exists"* ]]
# then
#     echo "Tag for ${version} already exists, stopping now"
#     exit 1;
# fi

cmd="rsync -a \"${dirname}\" \"${dirname}/../${release}/\""
for ignore in $ignores
do
    cmd+=" --exclude ${ignore}"
done

$(eval $cmd)
cd "${dirname}../"
zip -r "${release}.zip" "${release}/"
rm -rf "${release}/"
cd "${dirname}"
