# Nextcloud Notes Test Server

This is an optional convenience feature of the project to accelerate and simplify development.
This isolated subdirectory ships:

* A convenience script to launch a Netcloud Docker container as a backend for development and testing
* Example data which automatically is integrated into the server

## Requirements

* You have Docker Desktop installed

## How To Use

Just run the shell script:

```sh
./Server/Run.sh
```
This will:

- Create a new Nextcloud Docker container named `nextcloud-notes-test-server` which you can reach on `localhost:8080`. The `admin` user has `admin` as the password.
- Create test users with their languages set to `en` and their password to `password`.
    - `nonotes` with no content.
    - `manynotes` with the content of [Notes](Notes/) directory copied into the container.

Additionally, you can specify the `NEXTCLOUD_TRUSTED_DOMAINS` environment variable on script run to make Nextcloud available in the local network.
This way other physical devices can reach it, too.

```sh
NEXTCLOUD_TRUSTED_DOMAINS='192.168.178.*' ./Server/Run.sh
```

**Warning**: Do use this only in a private and trusted network!

You only need this one as long as you do not delete the container again.
Until then you can start or stop it with Docker Desktop.

### Live-server tests

The network tests come in two tiers, and both run in CI on every pull request:

- The default `iOCNotes` test plan runs against an in-process fake Notes server and needs nothing else.
- The `LiveServer` test plan additionally runs end-to-end tests against this server. CI's `live-server` job provisions a server the same way; use this container to reproduce or debug that job locally:

```sh
xcodebuild test -scheme iOCNotes -testPlan LiveServer -destination 'platform=iOS Simulator,name=iPhone 17'
```

The live tests wipe the `nonotes` account before and after each test and only read `manynotes`.
To point them at another server, change `NOTES_TEST_SERVER_URL` in `LiveServer.xctestplan`.

To quickly get rid of the container and delete all its data:

```sh
docker rm --force --volumes nextcloud-notes-test-server
```

### A Lot Of Notes

In `Notes/A Lot Of/` there is a shell script to quickly generate about a thousand random markdown files.
To avoid bloating the repository with random test data, this has been excluded intentionally and needs to be generated on demand.
