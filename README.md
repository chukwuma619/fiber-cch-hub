# Fiber CCH Hub

Run your own **Cross-Chain Hub (CCH)** for [Fiber Network](https://www.fiber.world/) — swaps between **CKB (Fiber)** and **Bitcoin (Lightning)** without custodial trust.

This repo is an **operator kit**: Docker Compose + configs + a few scripts so you can clone, configure passwords, and start the stack. CCH itself comes from the official [`nervos/fiber`](https://hub.docker.com/r/nervos/fiber) image (standalone mode).

---

## New here?

**Start with the step-by-step guide:** [GETTING-STARTED.md](GETTING-STARTED.md)

It covers installing Docker, cloning, setting passwords, running locally, deploying on a server, and fixing common errors — written for people who are not developers.

---

## Quick start (if you already use Docker)

```bash
git clone <this-repo-url>
cd fiber-cch-hub
cp .env.example .env          # edit FIBER_SECRET_KEY_PASSWORD and LND_WALLET_PASSWORD
make up
make ps                       # fiber, lnd, cch should be Up
```

| URL (local) | Service |
| --- | --- |
| http://127.0.0.1:8227 | Fiber RPC |
| http://127.0.0.1:8327 | CCH RPC |

Stop: `make down` · Logs: `make logs` · Health check: `make doctor`

**Note:** LND syncs Bitcoin testnet in the background (`synced_to_chain` may be false for a while). The stack uses **Fibt** (Fiber testnet) + **Bitcoin testnet** Lightning so invoice networks match.

---

## What’s in this repo

```
fiber-cch-hub/
├── docker-compose.yml    # Fiber + LND + CCH containers
├── config/
│   ├── fiber/config.yml  # Fiber node (testnet, cWBTC whitelist)
│   └── cch/config.yml    # Standalone CCH (Fibt, LND wiring)
├── scripts/
│   ├── bootstrap.sh      # .env, data dirs, copy configs
│   ├── init-lnd.sh       # LND wallet + credentials for CCH
│   └── doctor.sh         # Docker / image checks
├── Makefile              # make up | down | logs | ps
└── GETTING-STARTED.md
```

Runtime data (wallets, chain state) lives in `data/` (gitignored).

---

## Architecture

```
┌─────────────────┐     HTTP + WebSocket      ┌─────────────────┐
│  CCH (hub)      │ ─────────────────────────▶│  Fiber node     │
│  rpc + cch      │                           │  fiber + rpc    │
└────────┬────────┘                           └────────┬────────┘
         │ gRPC                                        │ CKB testnet
         ▼                                             ▼
┌─────────────────┐                           ┌─────────────────┐
│  LND            │                           │  Channels /     │
│  Bitcoin        │                           │  cWBTC swaps    │
│  testnet        │                           └─────────────────┘
└─────────────────┘
```

Standalone CCH does not embed Fiber; it calls `fiber_rpc_url` and subscribes to store changes over WebSocket. See [Fiber standalone docs](https://www.fiber.world/docs/res/cross-chain-htlc#standalone-mode).

---

## Configuration

Tracked configs are copied into `data/` on `make bootstrap` / `make up`. Edit files under `config/` and restart:

```bash
make bootstrap
make down && make up
```

| File | Purpose |
| --- | --- |
| `config/fiber/config.yml` | Fiber P2P, CKB RPC, cWBTC UDT whitelist |
| `config/cch/config.yml` | CCH fees, `fiber_rpc_url`, LND paths, wrapped BTC script |
| `.env` | Passwords and host ports (from `.env.example`) |

To use an **external LND** instead of the bundled one, point `lnd_rpc_url`, `lnd_cert_path`, and `lnd_macaroon_path` in `config/cch/config.yml` at your node and remove the `lnd` service from `docker-compose.yml`.

---

## CCH RPC (summary)

Full API: [Module `Cch`](https://www.fiber.world/docs/api-reference/cross-chain/cch)

| Method | Direction |
| --- | --- |
| `send_btc` | Pay a Lightning invoice using CKB (Fiber) |
| `receive_btc` | Receive on Lightning, settle a Fiber invoice |
| `get_cch_order` | Check swap status by payment hash |

Example (testnet currency **Fibt**):

```bash
curl -s http://127.0.0.1:8327 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"get_cch_order","params":[{"payment_hash":"0x..."}]}'
```

---

## Testnet resources

- **cWBTC faucet:** [faucet-cwbtc.ckb.dev](https://faucet-cwbtc.ckb.dev/)
- **Fiber + cWBTC setup:** [guide](https://faucet-cwbtc.ckb.dev/guide.html)
- **Roadmap:** [docs/ROADMAP.md](docs/ROADMAP.md)

---

## License

[MIT](LICENSE)
