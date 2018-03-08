# Creating a new shared-scripts version:

* Find the most recent version tag.
* Increment that version number by one.
* Apply that tag '$NEW_VERSION' to the git commit you want to version.
* Force-apply the `latest` tag to the newly tagged version
* Push the changes to github.

```
git tag v1.0.12 11866e5a5e68ab4f292d0d99f2c183d086dd2a4a
git tag -f latest v1.0.12
git push --delete origin refs/tags/latest
git push --tags
```
