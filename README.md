# sBTC Starter

This is a basic repository for getting started experimenting with sBTC.

sBTC is under heavy development, and the bridging functionality will change, but sBTC will still be a SIP-010 token, which means developers can still start experimenting with and building applications that use sBTC.

This is a very basic repository that includes the sBTC token contract as it currently exists, along with the Clarity Bitcoin library that sBTC uses to read and verify data from the Bitcoin chain.

Finally, this repo includes a simple DeFi contract that will allow you to begin learning how to interact with sBTC and to use as an example.

## Minting sBTC

Since minting sBTC will require first checking that a corresponding amount of BTC has been deposited into the sBTC threshold wallet, we need a way to bypass that in our local contract for experimentation purposes.

As a result, the `sbtc.clar` contract used in this repo uses a modified `mint` function that does not first check to see whether the relevant Bitcoin transaction exists.

This is very simple, we just need to comment out a few things.

First is the `try!` function that makes that check:

`(try! (verify-txid-exists-on-burn-chain deposit-txid burn-chain-height merkle-proof tx-index block-header))`

And the next `asserts` statement that makes sure this Bitcoin transaction was not already used.

`(asserts! (map-insert amounts-by-btc-tx deposit-txid (to-int amount)) err-btc-tx-already-used)`

Finally, there are several parameters that the `mint` function accepts and passes in to verify the Bitcoin transaction that we don't need.

These lines comes pre-commented in this repo with comment explanations, but it would be beneficial to check out the [actual sBTC contract](https://github.com/stacks-network/sbtc/blob/main/romeo/asset-contract/contracts/asset.clar) to compare.

Now we can simply call this function from the same address that deployed the contract in order to mint sBTC to whatever address we want.

From there, it's a matter of using the usual [SIP-010 functions](https://docs.stacks.co/clarity/functions#ft-burn) to interact with our mock sBTC token. Take a look at the [Clarity book](https://book.clarity-lang.org/ch10-03-sip010-ft-standard.html) for more info on using fungible tokens on Stacks.

## Getting Started

The easiest way to begin experimenting is to use the [Hiro Platform](https://platform.hiro.so) and import this repo into it.

The Platform comes pre-loaded with everything you need for Stacks development, and the process laid out here is the same as if you were to get this set up locally.

In that case, I recommend using [Clarinet](https://www.hiro.so/clarinet) to get your local environment set up.
