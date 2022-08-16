#preps
qaTestBranch="qa-test"
git fetch origin hubs-cloud
git fetch origin $qaTestBranch
tag=hc.test.$(date '+%Y-%m-%d')
#point hubs-cloud branch to current qa-test
git reset HEAD --hard
git checkout origin $qaTestBranch
git pull origin $qaTestBranch
sha=$(git rev-parse --verify HEAD)
echo "$qaTestBranch branch sha: "$sha
git checkout hubs-cloud
git update-ref refs/heads/hubs-cloud $sha
git push origin hubs-cloud
#point qa-test branch to current master
git reset HEAD --hard
git checkout master
git pull origin master
sha=$(git rev-parse --verify HEAD)
echo "master branch sha: $sha"
git checkout $qaTestBranch
git update-ref refs/heads/$qaTestBranch $sha
git push origin $qaTestBranch
git tag $tag
git push origin $tag