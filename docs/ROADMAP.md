# Roadmap

Operator hub around upstream Fiber standalone CCH (`nervos/fiber` via Docker). Do not reimplement CCH.

## Done

- [x] Pin Fiber image; Compose stack: Fiber + standalone CCH + local regtest LND
- [x] Configs for Fiber testnet (Fibt) and cWBTC Script
- [x] `make up` / `make down` bootstrap path

## Next

- [ ] Point LND at Bitcoin testnet/mainnet for real swaps (network must match Fiber currency)
- [ ] Fund cWBTC + open Fiber channels ([faucet guide](https://faucet-cwbtc.ckb.dev/guide.html))
- [ ] Prove `send_btc` / `receive_btc` to `Success` on testnet
- [ ] Operator hardening: RPC auth, backups, monitoring, mainnet checklist

## References

- [Module `Cch` RPC](https://www.fiber.world/docs/api-reference/cross-chain/cch)
- [Cross-Chain HTLC (standalone)](https://www.fiber.world/docs/res/cross-chain-htlc#standalone-mode)
- [cWBTC faucet](https://faucet-cwbtc.ckb.dev/)
