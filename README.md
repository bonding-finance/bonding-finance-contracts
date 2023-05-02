# Bonding Finance Contracts

## stETH Perpetual Vaults

Bonding Finance perpetual vaults tokenize the ETH APR, allowing users to effectively long/short the ETH yield. We will initially launch with stETH, since it is by far the most popular LSD right now. However, our smart contracts are compatible with any rebasing token.

### Deposit

Users can mint Deposit Tokens (`dToken`) and Yield Tokens (`yToken`) by depositing stETH. For example, when a user deposits 1 stETH, they will receive 1 dToken and 1 yToken. The dToken represents the user's original deposit. The yToken represents all future stETH yield received via the rebase mechanism.

### Redeem

Users can always redeem their original deposit by burning equal amounts of dTokens and yTokens. For example, if a user redeems 5 dTokens and 5 yTokens, they will receive 5 stETH. Note that the user will receive back exactly the same number of stETH they deposited and will not receive the rebase rewards since the rebase yield has been directed to the yTokens.

### Earning Yield

To capture the stETH yield, users need to stake their yTokens in the staking contract. Once staked, users will be able to claim stETH rewards after every stETH rebase (once a day at 12PM UTC). Each yToken will earn the daily staking rate of each stETH. For example if a user stakes `10 yTokens` and the next stETH rebase APR is `5%`, then the user will earn `10 * (0.05 / 365)` ETH that day.

## Deployments

| Contract           | Address |
|--------------------|---------|
| Factory            | TBD     |
| stETH Vault        | TBD     |
| stETH Bond Staking | TBD     |
| BND                | TBD     |
| esBND              | TBD     |


## Commands

Compile smart contracts

```
npm run compile
```

Run tests

```
npm run test
```

Run coverage

```
npm run coverage
```

## Licensing

Bonding Finance smart contracts are licensed under the Business Source License 1.1 (`BUSL-1.1`) as described [here](./LICENSE).