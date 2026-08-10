# Fiber CCH Hub

Run your own **Cross-Chain Hub (CCH)** for [Fiber Network](https://www.fiber.world/) — atomic swaps between **CKB (Fiber)** and **Bitcoin (Lightning)** without custodial trust.

Operator kit around official [`nervos/fiber`](https://hub.docker.com/r/nervos/fiber) standalone CCH: Docker Compose, configs, and scripts. **You create keys before starting** (assisted by `make create-keys`).

---

## Start here

| Step | Guide |
| --- | --- |
| **Run locally (testnet)** | **[docs/SELF_HOSTING.md](docs/SELF_HOSTING.md)** — `.env` → `make create-keys` → `./start.sh` |
| **Deploy on a VPS** | **[docs/DEPLOY.md](docs/DEPLOY.md)** — copy `data/` + `.env` or create keys on the server |

---

## Quick reference

```bash
git clone <repo-url> && cd fiber-cch-hub
cp .env.example .env          # set passwords (not change-me)
make create-keys              # Fiber key + Lightning wallet (save the seed!)
./start.sh                    # Fiber + LND + CCH
```

| Command | Purpose |
| --- | --- |
| `make create-keys` | First-time Fiber key + LND wallet |
| `./start.sh` / `make up` | Start full stack |
| `make lnd-wallet` | Lightning wallet only |
| `make down` | Stop |
| `make ps` / `make logs` | Status / logs |
| `make doctor` | Check Docker + Fiber image |

| URL (local) | Service |
| --- | --- |
| http://127.0.0.1:8227 | Fiber RPC |
| http://127.0.0.1:8327 | CCH RPC |

---

## What’s in this repo

```
fiber-cch-hub/
├── docker-compose.yml
├── config/
├── scripts/
│   ├── bootstrap.sh
│   ├── preflight.sh      # Refuse start without key + real passwords
│   ├── create-keys.sh    # Explicit first-time key setup
│   └── lnd-wallet.sh
├── start.sh
├── Makefile
└── docs/
    ├── SELF_HOSTING.md
    └── DEPLOY.md
```

Runtime state: `data/` (gitignored) — **back this up**.

---

## Architecture

```
┌─────────────┐   HTTP + WS    ┌─────────────┐
│  CCH        │ ──────────────▶│  Fiber      │
│  rpc + cch  │                │  testnet    │
└──────┬──────┘                └─────────────┘
       │ gRPC
       ▼
┌─────────────┐
│  LND        │
│  BTC testnet│
└─────────────┘
```

[CCH API](https://www.fiber.world/docs/api-reference/cross-chain/cch): `send_btc`, `receive_btc`, `get_cch_order` (currency **Fibt** on testnet).

---

## Testnet resources

- [cWBTC faucet](https://faucet-cwbtc.ckb.dev/) + [guide](https://faucet-cwbtc.ckb.dev/guide.html)
- [CKB testnet faucet](https://faucet.nervos.org)
- [Roadmap](docs/ROADMAP.md)

---

## License

[MIT](LICENSE)
