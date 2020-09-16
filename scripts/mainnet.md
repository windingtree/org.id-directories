# MainNet deployment notes

## Repository

- It is recommended to create a repository clone in separate folder for making mainnet deployments

```bash
$ git clone git@github.com:windingtree/org.id-directories.git ./org-id-directories-mainnet
```

## Install dependencies

```bash
$ npm i
$ npm link
```

## Create keys file

Create file with name `keys.json` in the root of the cloned repository folder with following content:

```json
{
    "mnemonic": "<wallet_mnemonic>",
    "infura_projectid": "<infura_project_id>"
}
```

## Run deployment

```bash
$ orgid-tools --network main cmd=deploy name=DirectoryIndex from=<owner_address> initMethod=initialize initArgs=<owner_address>
```

## Deployment information

After the deployment is finished a file with name `main-DirectoryIndex.json` will be created in the `./openzeppelin` directory. Do not remove this file (!!!). In case of this file gets lost then it will be not possible to upgrade deployed OrgId instance in future.