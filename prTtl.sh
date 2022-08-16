
# get org and repo
IFS=$'|' read -r org repo \
    <<< $(git remote -v  | grep "(fetch)" | sed -e 's~.*github.com\/\([a-z]*\)\/\([a-z]*\).git (fetch)~\1|\2~g')
echo "org: $org, repo: $repo"


# get and verify hc.test tags
tagPrev=$(git tag --sort=committerdate | grep "hc.test" | tail -2 | head -1)
tagCurr=$(git tag --sort=committerdate | grep "hc.test" | tail -1)
! [[ "$tagPrev" =~ ^hc.test.[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && echo "bad tagPrev($tagPrev): exit" && exit 1
! [[ "$tagCurr" =~ ^hc.test.[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && echo "bad tagCurr($tagCurr): exit" %% exit 1
! [[ $tagCurr > $tagPrev ]] && echo "unexpected curr($tagCurr) and prev($tagPrev) tag order: exit" && exit 1
echo "tagPrev: $tagPrev, tagCurr: $tagCurr"
# make changelog
git log --oneline $tagPrev...$tagCurr | grep "Merge pull request" > prs.raw
echo "prs.raw:"
cat prs.raw
echo "" > changelog
while read line; do
    echo "[debug] ...processing <$line>"
    sha_pr=$(echo $line | sed -e 's/\(.*\) Merge.*#\([0-9]\+\).*/\1|\2/g')
    IFS='|' read -ra ARR <<< "$sha_pr"
    sha=${ARR[0]}
    prNum=${ARR[1]}
    sha_rawMsg=$(echo $line | sed -e 's/\(.*\) \(Merge pull request #.*\)/\2/g')
    prTitle=$(curl https://api.github.com/repos/$org/$repo/pulls/${prNum} 2>/dev/null | jq '.title')
    echo "[debug] sha: $sha, prNum: $prNum, sha_rawMsg: $sha_rawMsg, prTitle: $prTitle"
    prTitle="${prTitle%\"}";prTitle="${prTitle#\"}";
    echo "$sha $prTitle" >> changelog
done < prs.raw
cat changelog

