# Get the Fiber CCH Hub running

Follow these steps **in order**. When you finish, you will have Fiber (CKB testnet), Bitcoin testnet Lightning (LND), and standalone CCH running on your machine.

**What you will have**

1. A Fiber node with **your** CKB key  
2. A Lightning wallet with **your** seed phrase  
3. CCH wired to both — ready for testnet swaps once funded and channeled  

**Who this guide is for**

You should be comfortable opening a terminal and pasting commands. You do **not** need to be a blockchain expert.

On a laptop you do **not** need a public IP for a first test. For a VPS, see [DEPLOY.md](DEPLOY.md).

---

## Plain-language background

| Term | Meaning |
| --- | --- |
| **CKB** | The base coin on Nervos. You need testnet CKB to open Fiber channels. |
| **Fiber** | Fast payments on CKB (like Lightning on Bitcoin). |
| **CCH** | Cross-Chain Hub — swaps between Fiber (wrapped BTC) and Lightning BTC. |
| **LND** | Lightning Network Daemon — your Bitcoin Lightning node. |
| **Fibt** | Fiber testnet currency (matches Bitcoin testnet invoices). |

Start on **testnet**. Use mainnet only after backups and a full test swap work.

---

## 0. Clone the project

```bash
git clone <your-repo-url>
cd fiber-cch-hub
```

All later commands assume you are in this folder.

---

## What you need

| Item | Why | How to get it |
| --- | --- | --- |
| [Docker](https://docs.docker.com/get-docker/) | Runs Fiber, LND, and CCH | Docker Desktop (Mac/Windows) or Docker Engine (Linux) |
| [Git](https://git-scm.com/downloads) | Clone this repo | Installer or `xcode-select --install` (Mac) |
| `jq` (optional) | Pretty JSON in script output | `brew install jq` or `apt install jq` |
| [ckb-cli](https://github.com/nervosnetwork/ckb-cli/releases) (optional) | Print your faucet address after key creation | Download release, put on PATH |

---

## 1. Configure `.env`

```bash
cp .env.example .env
```

Open `.env` and set **both** passwords (not `change-me`):

```bash
FIBER_SECRET_KEY_PASSWORD=choose-a-strong-password
LND_WALLET_PASSWORD=choose-another-strong-password
```

`./start.sh` and `make create-keys` refuse to continue until these are set.

---

## 2. Create your keys (recommended)

One command creates the Fiber CKB key and the Lightning wallet:

```bash
make create-keys
```

What it does:

1. Checks `.env` passwords  
2. Creates `data/fiber/ckb/key` if missing (64 hex chars, mode 600)  
3. Prints your CKB address if `ckb-cli` is installed  
4. Starts LND and creates a Lightning wallet if missing  

**Write down the 24-word LND seed** when it appears. You need it to recover Lightning funds.

If keys already exist, `make create-keys` leaves the Fiber key alone and only unlocks / syncs LND.

### Manual Fiber key (optional)

Prefer `ckb-cli` yourself? See [§ Manual Fiber key with ckb-cli](#manual-fiber-key-with-ckb-cli) at the bottom. Then run `make lnd-wallet` for Lightning only.

---

## 3. Start the hub

```bash
./start.sh
```

Or:

```bash
make up
```

The first run downloads Docker images and may take several minutes.

Check:

```bash
make ps
docker compose exec fiber fnn-cli --url http://172.30.0.10:8227 info
docker exec fiber-cch-hub-lnd lncli --network=testnet getinfo
```

| Port (local) | Service |
| --- | --- |
| **8227** | Fiber RPC |
| **8327** | CCH RPC |
| **8228** | Fiber P2P |
| **10009** | LND RPC |

**LND sync:** `"synced_to_chain": true` may take 30+ minutes on first run. The hub can start before sync finishes; Lightning payments need sync.

Stop:

```bash
make down
```

---

## 4. Fund Fiber and open a channel

Invoices alone are not enough — your Fiber node needs CKB and an open channel for swaps.

1. Get your address: `ckb-cli util key-info --privkey-path data/fiber/ckb/key` (or from `make create-keys` output).  
2. Send **testnet CKB** from [faucet.nervos.org](https://faucet.nervos.org).  
3. Connect to a public Fiber testnet peer (see [Fiber network resources](https://www.fiber.world/docs/quick-start/network-resources)).  
4. Open a channel with enough capacity for the swaps you want to test.

For **cWBTC** swaps, follow the [cWBTC faucet guide](https://faucet-cwbtc.ckb.dev/guide.html).

---

## 5. Try a CCH RPC call

```bash
curl -s http://127.0.0.1:8327 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"get_cch_order","params":[{"payment_hash":"0x0000000000000000000000000000000000000000000000000000000000000000"}]}'
```

A “key not found” style response means CCH RPC is live. Full swap API: [Module `Cch`](https://www.fiber.world/docs/api-reference/cross-chain/cch).

---

## You’re ready when…

- [ ] `.env` passwords are set (not `change-me`)  
- [ ] `make create-keys` completed  
- [ ] You saved the **LND seed** and backed up `data/`  
- [ ] `./start.sh` succeeds; `make ps` shows fiber, lnd, cch **Up**  
- [ ] Fiber `fnn-cli info` works  
- [ ] LND `getinfo` works (sync can still be in progress)  

**Next:** deploy on a VPS → [DEPLOY.md](DEPLOY.md).

---

## If something goes wrong

| Problem | Fix |
| --- | --- |
| `Missing CKB private key` / `Missing LND wallet` | Run `make create-keys` |
| `Set FIBER_SECRET_KEY_PASSWORD` / `change-me` | Edit `.env` with real passwords, then `make create-keys` |
| Docker not running | Start Docker Desktop; wait until running |
| Orphan / address in use | `make down && make up` |
| Old regtest LND data | `make down && rm -rf data/lnd && make create-keys` |
| `make: command not found` | Mac: `xcode-select --install`; Linux: `apt install make` |

---

## Manual Fiber key with ckb-cli

Use this instead of the Fiber half of `make create-keys` if you prefer a keystore-based key.

1. Install [ckb-cli](https://github.com/nervosnetwork/ckb-cli/releases).  
2. `ckb-cli account new` — copy `lock_arg`.  
3. Export:

```bash
ckb-cli account export --lock-arg <YOUR_LOCK_ARG> --extended-privkey-path ./exported-key
mkdir -p data/fiber/ckb
head -n 1 ./exported-key > data/fiber/ckb/key
chmod 600 data/fiber/ckb/key
rm ./exported-key
```

4. Then: `make lnd-wallet` (or `make create-keys` — it will skip the existing Fiber key).

`data/fiber/ckb/key` must be **one line**, **64 hex characters**, **no** `0x` prefix.

---

## Related

- Overview + RPC summary: [README.md](../README.md)  
- VPS deploy: [DEPLOY.md](DEPLOY.md)  
- Roadmap: [ROADMAP.md](ROADMAP.md)
