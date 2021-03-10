---
author: hsw
tags: Autonomy-System, API, MVA
---

# **Autonomy Architecture v1.0**

**Release Date: 5-MAR 2021**
- App
    - iOS (iPhone only)
- Server (partially isolated user processes)
    - Basic transaction coordinator
    - Recovery
    - Contact list

---

:::spoiler {state=open} CONTENTS
[TOC]
:::


## Keys

### Overview

* bitcoin keypairs
    * platform cosigner keypair
        * device keeps private key
    * recovery cosigner keypair
        * private key is sharded across at least
            * platform store
            * Bitmark store
            * contact store
    * gordian cosigner keypair
        * generated and kept in the container
* auth keypair
    * created on device
    * sharded like recovery key
    * [encoding](#Appendix-Identification-Encoding)

### Reconstruction

* APP - reload from:
    * platform store
* Container - rebuild from:
    * encrypted store containing:
        * gordian co-signer keypair
        * wallet file(s) (rebuild this from keypair+account maps if `wallet.dat` damaged)
        * list of account maps
        * backup of contact list

### Recovery

* only necessary if:
    * platform store lost
    * container store lost
    * recovery key lost (i.e., less than m shards available)
    * reason to suspect a key was leaked (e.g., stolen device)
* need to get back two shards to rebuild recovery keypair
* then use the remaining key platform or gordian to sweeep the funds to a new wallet
* extra second protection is to add an additional key wit on year time lock
    * if recovery key is used then the case of bot platform and container store lost is covered if sufficient shards are recovered
    * transaction byte code allows UTXO spend for one of:
        * 2of3 multisig
        * single sig of extra key AND blockheight > limit
    * the _limit_ values will be set as the expected blockheight one year later


## Connections to other services

* spotbit - current price information
* coinbase API - fee estimation
* coingecko - historical price
* OneSignal - generic push notications
* Apple App Store: check subscription info

## Postman Documentation

[Autonomy API](<https://documenter.getpostman.com/view/59304/TVYGbxbg> "API on Postman")

## BACKLOG

* Order of XPUBs for multisig (choose 1)
    1. original fixed order: `multi(platform,recovery,gordian)`
    2. use: `sortedmulti` - this may simplify recovery

* Network Switching
    * provisioning: one keypair file and both networks derived from it
    * figure out startup sequence: 2× CreatePersonalAccount for test/main
    * wallet files multiple per network
    * API for APP to reboot to other network
    * Will the APP use same contact list for both networks?
    * RESEARCH: Need to add to gordian server and all-bitcoin-core 21+ to regtest and signet, signet schnorr ($10K changes to server, $5K changes to wallet to support 3+ networks, and $20K for initial schnorr)

* Reconstruct
    * get old keys back: platform and container still usable
    * assumes no compromise

* Add Contact:
    * Do simplified flow at the moment.


### Help needed from Blockchain Commons:
* Authentication keypair
    * how to derive various identifiers?
    * where are the shards of the auth keypair stored?
* TorGap
    * drop-in solution
    * can this replace the message server?
    * will whisper over Tor be used?
* check the recovery sequence
    * also relates to recovering auth key to reconnect to container
    * are all conditions covered


## Block Diagrams

### System Architecture Overview
![SystemArchitecture](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/block/server/SystemAchitecture.png> "SystemArchitecture")

**Description**

* overview of the system structure
* shows additional services as individual messaging clients
* shows client side storage as repliacted to its platform provider's cloud

### Container Architecture
![ContainerArchitecture](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/block/server/ContainerArchitecture.png> "ContainerArchitecture")

**Description**

The system consists of the following components:
* API handler - this handles the HTTPS interface from the APP and has a number of functions
    * Handle some functions directly such as calls to external APIs (e.g., transaction cost)
    * Proxy connections to user's container
    * E2EE messaging between applications
* Container manager this performs:
    * Initial container instantiation
    * Container update - new program version
    * Container compaction - compact the local blockchain files (possibly this can be an in-container process instead)
    * Reboot container to switch networks (possibly this can be an in-container process instead)
* Messaging
    * uses whisper protocol to perform end-to-end encrypted messaging between client APPs
    * server store E2EE messages in a queue for later retieval (so continuous connections are not necessary)
    * client must keep a key store and a session store
* Notification Relay to forward push notifications
* Container
    * bitcoind either testnet or mainnet, but *not* both
    * wallet changes trigger notifier
    * encrypted image mount for wallet files (key from etcd)
    * union blockchain mount to share large blockchain datafiles
    * (deduplication either on container reboot or internal union deduplication) (not sure when this would trigger)

---


## Sequence Diagrams

### Overview
![Overview](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/Overview.png> "Overview")

---

### Registration
![Registration](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/Registration.png> "Registration")

**Description**

Register account involves the following
* Creation of account in DB
* Container instantiation (on boot actions)
    * start internal process to gather entropy (does this need APP?)
    * derive xpriv (accumulated entropy)
    * indicate status: initialised
    * mount wallets and blockchain
    * start bitcoind connected to selected network (test/main)
    * indicate status: running (need to detect bitcoind is in sync)
* APP can contact the container to request actions

:::warning
Future Feature - registration with five decks

![RegistrationFiveDecks](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/RegistrationFiveDecks.png> "RegistrationFiveDecks")
:::

---

### CreatePersonalAccount
![CreatePersonalAccount](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/CreatePersonalAccount.png> "CreatePersonalAccount")

**Description**

* Create initial account to receive funds
* derives multisig addresses using `wsh(sortedmulti(2,P,R,G))`
* external path: `m/84h/0h/0h/0/*`
* internal path: `m/84h/0h/0h/1/*`
* see [BIP 84](<https://github.com/bitcoin/bips/blob/master/bip-0084.mediawiki>)
* relies on saved accountmap to recover xpubs

### NewAddress
![NewAddress](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/NewAddress.png> "NewAddress")

**Description**

* obtain a new address to receive funds
* should not be called unless the previous addresses are already have funds
* for privacy an address should only be used once
* for compatibility no more than 20 addresses can be outstanding, waiting for funds
* bitcoind 0.21 can handle 1000  outstanding addresses, but using this feature would break compatibility
---

### Payment
![Payment](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/Payment.png> "Payment")

---

### ReceiveFunds
![ReceiveFunds](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/ReceiveFunds.png> "ReceiveFunds")

---

### CheckRecoveryIntegrity
![CheckRecoveryIntegrity](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/CheckRecoveryIntegrity.png> "CheckRecoveryIntegrity")

**Description**

* periodically preform recovery integrity check
    * Bitmark Deck exists
    * Contact Deck exists
    * Platform Deck exists
* if sufficient items exist just update backup timestamps
* if no redundancy send alert message
    * _read back recovery key and reshard might be an option_
* if recovery impossible request immediate action
    * sweep wallet _can existing platform/gordian be used with new recovery?_

### RecoverAndSweepToNew
![RecoverAndSweepToNew](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/RecoverAndSweepToNew.png> "RecoverAndSweepToNew")

**Description**

* obtain recovery keypair and recover the old account map from 2 Decks
* setup APP/container with one keypair each
* have container iterate over UTXOs
* group resulting UTXOs into transactions and ask APP to sign them
* container countersign, finalise and broadcast

:::warning
Future Feature - recovery from five decks

![RecoverFiveDecks](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/RecoverFiveDecks.png> "ReecoverFiveDecks")

:::

---

### AutonomyContact
:::info
Current Simplified Feature

![AutonomyContact](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/AutonomyContact.png> "AutonomyContact")
:::

### AddContact

:::warning
Future Feature

![AddContact](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/AddContact.png> "AddContact")
:::

---

### BackupToContact
![BackupToContact](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/BackupToContact.png> "BackupToContact")

---

### CreateSharedAccount

:::warning
Future Feature

![CreateSharedAccount](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/CreateSharedAccount.png> "CreateSharedAccount")
:::

---

## Classes

### SystemClasses
![SystemClasses](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/class/server/SystemClasses.png> "SystemClasses")


---

## still to be updated

:::warning
Under Construction
:::

---


## Application architecture

### 1. Block diagrams

![ApplicationArchitecture](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/block/application/ApplicationArchitecture.png> "ApplicationArchitecture")

### 2. Account/Keys management (in keys storage)
* Use parts of [latest module from Gordian Cosigner](https://github.com/BlockchainCommons/GordianCosigner-Catalyst/tree/master/GordianSigner/Helpers) to generate seed and required keys to ensure compabilities with Gordian System.
* Recovery and platform cosigner keypairs are generated independently from Application's process.
    * Recovery cosigner keypair will be sharded immediately after generated, and its key storage will just store shards.
    * Platform cosigner keypair keeps its privatekey separated from Application, only receive PSBTs and sign them.
* Auth keypair are generated in Application process and used for Signal protocol messaging's identity.
    * After generated, its 3 shards will be stored along with Recovery cosigner keypair's shards.

### 3. Application database (in file storage)
Uses [Core data](https://developer.apple.com/documentation/coredata) to store application business data, includes:
* `Contacts`: Contact lists and their vCards
* `Activities`: User activities: set up and recover account, deposits, payments,...
* `Settings`: User's application settings and prefererences.
* `Personal vCard`: Users' contact information.

The application stores latest snapshot of current database to Cloud storage as files.

TODO: 
- Send another copy of snapshot to the Container.
- Encrypt the snapshots.

## Metadata
* Application database:
    * Contacts
    * Activities (payment notes, tx price, ...)
    * Personal vCard
    * Setting
* Wallet information:
    * Account maps -- For recovery verification
    * Birthdate -- For sweeping

## Future Work (post-MVA)

* Android Java libwally @moskovich
    * some of the values end up going through strings
    * make sure that the strings are zeroed out
    * strings are variable size and need careful consideration
    * what for string copies
    * maybe 2 mandays of high-level Java expert
* Recover
    * RECOVERY - compromise of one key is assumed, thus use remaining keys to sweep to new Account Map multisig.
    * recover from loss of application or loss of container
    * recover old funds to new account (forma)
    * retain old wallet files for bitcoind monitoring
    * _future:_ "crontab" to periodically sweep any new funds to old wallet
    * _option:_ display remaining two keys as QR for external recovery
* Messaging
    * currently - Bitmark-run central whisper message queue
    * Signal messaging is currenly only sihgle-sig, with all its disadvantages.
    * messaging uses a key as an identifier. How do we restore or recover or revoke without real decentralized identifier rotation features.
* [Key bootstrapping](https://docs.google.com/document/d/1n9zuL5KwlvrEGUz6Vy4gbigE0p9B0VRHyPrTT2h8Gy4/edit)
    * BTC 2of3 +1(timelock: one year) so the fund is single sig after one year. TRADEOFF: make recovery key as the +1(timelock)
    
* Ed25519
    * lots of compatibility problems
    * different encodings of priv/pub
    * different privatekey e.d. random, hash()
    * different signature encodings
    * [https://gist.github.com/gorazdko/5fbe819b80e780a1894086b5731bb32d](<https://gist.github.com/gorazdko/5fbe819b80e780a1894086b5731bb32d>)
    * [Ristretto](<https://ristretto.group/ristretto.html>) solves the multisig problem (solves bitmarkd 2 sig transfer). Can use Schnorr with this
* Price information where is it from, how to validate
    * spotbit service
    * fee estimation service
* Transitions to higher-level Bitmark or self-soverign services.
    * signal versus onion
    * minimum necessary understanding of Tor for container communication
    * what problems might Tor cause
* Collaborative custodial key services held by Others (including Bitmark)
    * Open registration
    * How to choose between multiple vendors of these.
* Policy coordinator
    * (need new name for this other than coordinator as it is confusing)
    * Helps you choose from different approaches
* Multisig transaction coordinator
    * need more understanding
    * client support?
    * Schnorr sig (0.22? Q3 perhaps) (0.21 regtest testnet?)
    * will this increase message sizes too much
* Invoicing and purchase orders
* Sweep to new addresses under my own control
    * not necessarily close the wallet
* Fiat work on UX
* iOS app's SwiftUI
* Fees
    * fees e.g., one dollar tx with N! dollar fee
    * whathefee.io  fee estimator, but confusing, maybe 3x3 matrix. Better than fast/slow-low/high
    * fee replacement, could UX have *add more fee button*
* Child pays for parent (cpfp)
    * unconfirmed balance
    * how to handle balance=0 e.g. unconfirmed balance in *change*


## Appendix: Identification Encoding

 use did:key but only secp256k1 and get help to add required signature function to iOS wrapper for a secp256k1 C library. This would be the preferred method (as this curve seems to be more secure)

**Example:**

The secp256k1 compressed forms showiung the 33 byte public key with 02/03 prefix:
~~~
% openssl ecparam -name secp256k1 -genkey -out tk.pem ; openssl ec -in tk.pem -conv_form compressed -noout -text
read EC key
Private-Key: (256 bit)
priv:
    17:0a:4b:c1:c5:4e:52:86:f0:4f:57:51:6f:03:b4:
    61:76:da:38:23:00:41:1d:84:3d:e9:7e:5b:5d:0a:
    63:1a
pub:
    02:5c:d8:12:dd:75:55:28:91:18:1f:a1:68:f3:94:
    ea:20:fb:c0:47:ee:31:f9:fd:bf:8f:27:e1:a9:e0:
    2c:a3:d8
ASN1 OID: secp256k1

% openssl ecparam -name secp256k1 -genkey -out tk.pem ; openssl ec -in tk.pem -conv_form compressed -noout -text
read EC key
Private-Key: (256 bit)
priv:
    0b:ae:48:1d:a3:dc:88:50:81:30:26:4a:88:bc:f0:
    34:a4:1b:2e:8a:a0:92:01:ad:7c:37:e1:7e:99:20:
    f7:e7
pub:
    03:a2:6e:c8:7a:0b:ee:99:04:5a:3c:01:c3:d1:93:
    c7:e2:8c:4f:ba:7a:92:0f:23:91:63:1b:46:c2:e5:
    29:12:0a
ASN1 OID: secp256k1
~~~

Test cases: https://github.com/BlockchainCommons/musig-cli/blob/master/tests/cli.rs

### ContainerKeyProvisioning
![ContainerKeyProvisioning](<https://raw.githubusercontent.com/bitmark-inc/autonomy-docs/main/images/sequence/server/ContainerKeyProvisioning.png> "ContainerKeyProvisioning")

**Description**

* current provisioning for container
* shows encryption key fo NAS storage of wallet files

**Reference**
- https://hackmd.io/Imu_ROdNQx-JL_W73R4JvQ

## Questions (Probably old and needs refactoring)

* Where are the keys?
    * shard 1: user's device + cloud
    * shard 1: user's device + cloud
    * shard 2: contact's device + cloud
    * shard 3: Bitmark shard server (and its backups)
    * User xprv on user's device (internal secure store)
    * Container xprv in container storage (etcd key for at rest encryption of file store)
    * also note shards and decks (array of shards + *some data*)
    * 3 BTC keypair only recovery is sharded
    * identity keypair also sharded
* How does recovery vs. compromised work?
    * Contact shard needs contact to open APP and accept
    * Bitmark shard uses emailed code
    * Wallet sweep and reseed not available yet (second device and create new account?)
    * reconstruction e.g. device failure, but nothing lost
    * recovery - security risk so reconstruct may be harmful. This gets bak two of the 3 keys so a wallet sweep would be required
* What are the endpoints?
    * iOS APP devices locked to some type of platform. subject to *recovery* dependent on the platform supplier
    * Bitmark cluster initialion management, container provisioning etc.
    * User services
        * in app, in container, global bitmark provided services
        * connections to external entities (e.g., price feed)
        * container/app are updated by Bitmark network
        * cosigner signer services e.g. may require multiple human signers to approve
    * messaging protocol handles (versus pointers)
* What are the communication protocol between endpoints?
    * HTTPS only for API
    * E2EE (whisper protocol) over HTTPS for APP→APP messaging
    * HTTPS for APP→Container
        * future Tor with certificate authentication
        * would like distributed whisper over Tor

---
---
