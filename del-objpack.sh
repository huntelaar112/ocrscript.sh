git checkout --orphan latest_branch
git add -A
git commit -am "commit message"
git branch -D main
git branch -m main
git push -f origin main

echo "Just delete this and Reclone this repo to recieve lightweight .git"
