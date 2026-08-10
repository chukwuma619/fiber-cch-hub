# Deploy the Fiber CCH Hub on a VPS

Put the hub on a server so it runs 24/7.

**Before you start:** finish a full local testnet setup in [SELF_HOSTING.md](SELF_HOSTING.md) — you should already have `data/fiber/ckb/key`, an LND wallet (and seed saved), and a working `./start.sh`.

**Who this guide is for:** someone who can SSH into Linux, edit files, and open firewall ports.

---

## What you will end up with

| Piece | Default (local / VPS) |
| --- | --- |
| Fiber node | P2P port **8428**, RPC **8427** (keep RPC private) |
| LND | Bitcoin testnet, P2P **9735**, RPC **10009** (keep private) |
| CCH | RPC **8327** (keep private) |

All services run in Docker via `./start.sh`.

---

## What you need

| Item | Notes |
| --- | --- |
| VPS | Ubuntu 22.04+ common; **2 GB+ RAM** for Docker |
| Docker + Compose | [Install Docker](https://docs.docker.com/engine/install/) |
| Same `data/` as local **or** recreate keys on the server | See §2 |

Firewall (minimum for testnet):

| Port | Why |
| --- | --- |
| **22** | SSH |
| **8428/tcp** | Fiber P2P (if you want inbound peers) |
| **9735/tcp** | Lightning P2P (optional) |

Do **not** expose Fiber RPC **8427**, CCH **8327**, or LND **10009** to the public internet. Use SSH tunnels or a VPN for admin access.

---

## 1. Prepare the VPS

```bash
# Ubuntu example
sudo apt update
sudo apt install -y ca-certificates curl make git
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
# log out and back in
```

Clone:

```bash
git clone <your-repo-url>
cd fiber-cch-hub
```

---

## 2. Bring your identity to the server

Use **one** of these — same idea as [FiberFlow DEPLOY](https://github.com/chukwuma619/fiberflow/blob/master/docs/DEPLOY.md):

### Option A — Copy your local hub (recommended)

Same keys, channels, and wallets as your laptop.

On your **laptop**:

```bash
make down
rsync -avz .env data/ user@YOUR_SERVER:~/fiber-cch-hub/
```

On the **server** (after `git clone` into `~/fiber-cch-hub`):

```bash
./start.sh
```

Use the **same** `.env` passwords as local.

**Only run one copy** of the hub with the same `data/` at a time.

### Option B — Create keys on the server

```bash
cp .env.example .env
# set passwords
make create-keys
./start.sh
```

Follow [SELF_HOSTING.md](SELF_HOSTING.md) on the VPS from scratch (new Fiber pubkey and LND wallet). Use this if local was only for learning.

You can also copy **only** `data/fiber/ckb/key` and restore LND from your saved seed if you prefer not to copy the whole `data/` tree.

---

## 3. Configure for production (optional)

- Edit `config/fiber/config.yml` → set `announced_addrs` to your VPS public IP for Fiber P2P.  
- Re-copy configs: `make bootstrap`  
- Keep CCH on **Fibt** / Bitcoin testnet until you deliberately switch networks.

```bash
curl -4 ifconfig.me   # your public IP
```

Example in `config/fiber/config.yml`:

```yaml
fiber:
  announced_addrs:
    - "/ip4/203.0.113.10/tcp/8428"
```

Then `make bootstrap && make down && ./start.sh`.

---

## 4. Start and verify

```bash
./start.sh
```

```bash
make ps
docker compose exec fiber fnn-cli --url http://172.30.0.10:8227 info
docker exec fiber-cch-hub-lnd lncli --network=testnet getinfo
```

Containers use `restart: unless-stopped` — they come back after a reboot.

---

## 5. Updates

```bash
git pull
make pull
make down
./start.sh
```

Before upgrading the Fiber image: back up `./data`, close channels if on mainnet (see Fiber docs).

---

## Security checklist

- [ ] `data/fiber/ckb/key` and `.env` are not in git  
- [ ] Strong passwords in `.env`  
- [ ] `./data` backed up regularly (including LND seed stored offline)  
- [ ] RPC ports not open to `0.0.0.0` on the public internet  
- [ ] Only one live instance per `data/` copy  

---

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `Missing CKB private key` | Run `make create-keys` — [SELF_HOSTING.md](SELF_HOSTING.md) |
| `Missing LND wallet` | `make create-keys` on the server |
| Peers cannot reach Fiber | Open **8428**, set `announced_addrs`, restart |
| Wallet corrupt after copying | Stop local hub first; never run two copies of same `data/` |

---

## Related

- Local setup: [SELF_HOSTING.md](SELF_HOSTING.md)  
- [README.md](../README.md)  
- [CCH RPC docs](https://www.fiber.world/docs/api-reference/cross-chain/cch)
