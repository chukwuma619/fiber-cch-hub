# Fiber CCH Hub (Standalone Mode)

A **standalone Cross-Chain Hub (CCH)** for [Fiber Network](https://www.fiber.world/) — atomic swaps between **CKB (Fiber)** and **Bitcoin (Lightning)** using Hash Time-Locked Contracts (HTLCs).

This project targets Fiber’s **standalone CCH mode**: the hub runs as its own process and talks to a Fiber Network Node (FNN) over HTTP JSON-RPC and WebSocket, instead of embedding CCH inside the same binary as Fiber.



**Runtime:** official Docker image [`nervos/fiber:0.9.0`](https://hub.docker.com/r/nervos/fiber) (see `.env.example`).

### Quick start

```bash
cp .env.example .env   # set FIBER_SECRET_KEY_PASSWORD / LND_WALLET_PASSWORD
make doctor            # optional host check
make up                # bitcoind + LND + Fiber + standalone CCH
```

Useful targets: `make logs`, `make ps`, `make down`, `make pull`.

Default Compose brings up a **local regtest LND** so the hub can start without an external Lightning node. Fiber/CCH are configured for **CKB testnet (Fibt)**. For real swaps, point `config/cch/config.yml` at a Bitcoin testnet (or mainnet) LND whose network matches your Fiber currency, fund cWBTC ([faucet](https://faucet-cwbtc.ckb.dev/)), and open channels.

---

## What is CCH?

**CCH (Cross-Chain Hub)** bridges Fiber and Lightning so users can swap wrapped BTC on CKB for native BTC on Lightning (and the reverse) **without custodial trust**.

Atomicity is enforced by HTLCs on both sides:

- Both legs share the same **SHA-256 payment hash**
- When the outgoing payment settles, the hub learns the **preimage** and settles the incoming invoice
- Either both legs succeed, or neither does — the operator (“Ingrid” in the protocol literature) cannot steal funds by withholding one side

Protocol background:

- [Cross-Chain HTLC](https://www.fiber.world/docs/res/cross-chain-htlc) (standalone mode)
- [Module `Cch` RPC](https://www.fiber.world/docs/api-reference/cross-chain/cch)
- [Payment Channel Cross-Chain Protocol with HTLC](https://github.com/nervosnetwork/fiber/blob/develop/docs/specs/cross-chain-htlc.md) (Fiber repo)

---

## Why standalone mode?

Fiber can run CCH **in-process** (same process as Fiber + CKB services) or as a **separate process**.

| Mode | How CCH reaches Fiber | When to use |
| --- | --- | --- |
| **In-process** | Direct actor calls to `NetworkActor`; store changes via in-process ports | Simple single-node operator setups |
| **Standalone** | HTTP RPC + WebSocket `subscribe_store_changes` via `fiber_rpc_url` | Scale or isolate the swap service from the routing node |

Standalone mode (shipped in Fiber **v0.8.0**, [PR #1165](https://github.com/nervosnetwork/fiber/pull/1165)):

- `fiber_rpc_url` points at a running Fiber node’s HTTP RPC
- `wrapped_btc_type_script` must be the **full JSON Script** (contracts context is not initialized without Fiber/CKB services)
- CCH subscribes to Fiber store changes over WebSocket and **auto-reconnects** on failure

```
┌────────────────────┐         HTTP JSON-RPC          ┌────────────────────┐
│  Standalone CCH    │────────────────────────────────▶│  Fiber Node (FNN)  │
│  services:         │                                 │  services:         │
│    - rpc           │◀──── WebSocket ─────────────────│    - fiber         │
│    - cch           │   subscribe_store_changes       │    - rpc           │
└─────────┬──────────┘                                 │    - ckb           │
          │                                            └────────────────────┘
          │ LND gRPC
          ▼
┌────────────────────┐
│  Lightning (LND)   │
└────────────────────┘
```

---

## Swap directions

### Send BTC — CKB → Lightning

1. Bob creates a Lightning invoice
2. Alice calls `send_btc` with Bob’s `btc_pay_req`
3. CCH creates a Fiber invoice for `amount + fee` (same `payment_hash`, wrapped BTC UDT)
4. Alice pays the Fiber invoice
5. CCH pays Bob on Lightning, then settles the Fiber invoice with the preimage

### Receive BTC — Lightning → CKB

1. Alice creates a Fiber invoice (wrapped BTC UDT, `hash_algorithm = sha256`)
2. Alice calls `receive_btc` with her `fiber_pay_req`
3. CCH creates an LND **hold** invoice for `(amount + fee) * 1000` millisats
4. Bob pays on Lightning
5. CCH pays Alice on Fiber, then settles the Lightning hold invoice with the preimage

Fee formula (from Fiber docs / config):

```text
fee = base_fee_sats + amount * fee_rate_per_million_sats / 1_000_000
```

---

## Prerequisites

| Component | Role |
| --- | --- |
| [Fiber Network Node](https://github.com/nervosnetwork/fiber) (`fnn`) | Channels, invoices, payments on CKB Fiber |
| Trusted [CKB](https://github.com/nervosnetwork/ckb) RPC | On-chain settlement for the Fiber node |
| [LND](https://github.com/lightningnetwork/lnd) | Lightning invoices / payments (gRPC + macaroon) |
| Wrapped BTC UDT on CKB | Testnet **cWBTC** (8 decimals; demo: 1 raw unit = 1 satoshi) |

**Testnet cWBTC**

- Faucet: [faucet-cwbtc.ckb.dev](https://faucet-cwbtc.ckb.dev/)
- Token + Fiber setup: [cWBTC developer guide](https://faucet-cwbtc.ckb.dev/guide.html)
- Faucet source: [RetricSu/cwbtc-faucet](https://github.com/RetricSu/cwbtc-faucet)
- Also mentioned on the [Module `Cch` RPC](https://www.fiber.world/docs/api-reference/cross-chain/cch) page

---

## Configuration

Standalone CCH runs with **`rpc` + `cch` only** (no co-located `fiber` / `ckb` services). Point `fiber_rpc_url` at the Fiber node that holds liquidity and channels.

Example `config.yml` (shape matches Fiber’s standalone validation and separate-service tests):

```yaml
rpc:
  listening_addr: "127.0.0.1:8227"
  enabled_modules:
    - cch

cch:
  # Fiber node HTTP RPC (WebSocket derived: http → ws, https → wss)
  fiber_rpc_url: "http://127.0.0.1:8227"

  # LND
  lnd_rpc_url: "https://127.0.0.1:10009"
  lnd_cert_path: "/path/to/tls.cert"
  lnd_macaroon_path: "/path/to/admin.macaroon"

  # Required in standalone mode — full Script JSON (not just args)
  wrapped_btc_type_script: '{"code_hash":"0x...","hash_type":"type","args":"0x..."}'

  # Optional fee / expiry tuning
  base_fee_sats: 100
  fee_rate_per_million_sats: 3000
  order_expiry_delta_seconds: 129600          # 36h
  btc_final_tlc_expiry_delta_blocks: 360      # ~60h
  ckb_final_tlc_expiry_delta_seconds: 216000  # 60h
  min_outgoing_invoice_expiry_delta_seconds: 21600  # 6h

services:
  - rpc
  - cch
```

### Standalone requirements

From Fiber’s `CchConfig` ([`crates/fiber-lib/src/cch/config.rs`](https://github.com/nervosnetwork/fiber/blob/develop/crates/fiber-lib/src/cch/config.rs)):

1. **`fiber_rpc_url`** — required when Fiber is not co-located  
2. **`wrapped_btc_type_script`** — full Script JSON; validated at startup via `validate_standalone()`  
3. Fiber peer must expose RPC modules the hub needs (invoices, payments, pubsub for store changes)

CLI / env equivalents use the `cch-` / `CCH_` prefixes (e.g. `--cch-fiber-rpc-url`, `CCH_FIBER_RPC_URL`).

The Fiber node that CCH connects to typically runs:

```yaml
services:
  - fiber
  - rpc
  - ckb
```

---

## RPC API

Official schema: [Module `Cch`](https://www.fiber.world/docs/api-reference/cross-chain/cch) (`send_btc`, `receive_btc`, `get_cch_order`).

### `send_btc`

Pay a Lightning invoice from CKB (Fiber).

```json
{
  "jsonrpc": "2.0",
  "method": "send_btc",
  "params": {
    "btc_pay_req": "lnbc100u1p...",
    "currency": "Fibb"
  },
  "id": 1
}
```

### `receive_btc`

Receive BTC on Lightning and settle a Fiber invoice.

```json
{
  "jsonrpc": "2.0",
  "method": "receive_btc",
  "params": {
    "fiber_pay_req": "fibb1000..."
  },
  "id": 1
}
```

### `get_cch_order`

Poll order status by payment hash.

```json
{
  "jsonrpc": "2.0",
  "method": "get_cch_order",
  "params": {
    "payment_hash": "0xabcd1234..."
  },
  "id": 1
}
```

### Order statuses

```text
Pending → IncomingAccepted → OutgoingInFlight → OutgoingSuccess → Success
                ↘________________↘______________________________→ Failed
```

---

## Safety notes

- **Expiry cascade**: outgoing final expiry must stay under half of incoming remaining time (static check at creation + dynamic check before send)
- **Preimage verification**: returned preimage must hash to the order’s `payment_hash` (SHA-256)
- **Network matching**: Lightning invoice network must map to the configured CKB/Fiber network (mainnet ↔ mainnet, testnet ↔ testnet, etc.)
- **Hash algorithm**: Fiber invoices for CCH must use `sha256` for LND compatibility
- **Wrapped BTC discovery**: clients should verify invoice `udt_type_script` against a known wrapped BTC Script before paying

---

## License

[MIT](LICENSE)
