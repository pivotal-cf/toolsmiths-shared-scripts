# Creating a new shared-scripts version:

* Find the most recent version tag.
* Increment that version number by one.
* Apply that tag '$NEW_VERSION' to the git commit you want to version.
* Push the changes to github.

```
git tag v1.0.12 11866e5a5e68ab4f292d0d99f2c183d086dd2a4a
git push --tags
```

* Then we should update the versions used in our app

```
update pcf_versions
set script_version = 'v1.0.12'
where script_version = 'v1.0.11'
```
