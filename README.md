# sBTC Starter

This is a basic repository for getting started experimenting with sBTC.

sBTC is under heavy development, and the bridging functionality will change, but sBTC will still be a SIP-010 token, which means developers can still start experimenting with and building applications that use sBTC.

This is a very basic repository that includes the sBTC token contract as it currently exists, along with the Clarity Bitcoin library that sBTC uses to read and verify data from the Bitcoin chain.

Finally, this repo includes a simple DeFi contract that will allow you to begin learning how to interact with sBTC and to use as an example.

## Getting Started

The easiest way to begin experimenting is to use the [Hiro Platform](https://platform.hiro.so) and import this repo into it.

The Platform comes pre-loaded with everything you need for Stacks development, and the process laid out here is the same as if you were to get this set up locally.

In that case, I recommend using [Clarinet](https://www.hiro.so/clarinet) to get your local environment set up.

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

In this scenario, we can open up a new console instance by running `clarinet console` and then minting sBTC with `(contract-call? .sbtc mint u100000000 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)`. This represents 100,000,000 sats, which is 1 BTC, or 1 sBTC in this case.

This principal corresponds to the first principal generated when you start the console.

Then to make sure it worked you can check our balance with `(contract-call? .sbtc get-balance 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)`.

Now you can call any of the functions in the `lagoon.clar` contract to test it out and begin to write your own.

## Deposit

Let's start by depositing 1,000,000 sats into the Lagoon pool with `(contract-call? .lagoon deposit u1000000)`.

Now we want to mint some more sBTC to a different user, and have them deposit as well. We can do that with the following commands:

First we mint the sBTC.

`(contract-call? .sbtc mint u100000000 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)`

Then we need to switch to that principal's context in the console.

`::set_tx_sender ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5`

This is an example of a utility function we can use to interact with the mocknet running in the console. Run `::help` within the console to see what else you can do.

Now we can deposit as this new user.

`(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.lagoon deposit u1000000)`

Note that we need to prefix our contract with the deployer principal since we have switched contexts to another principal.

## Borrowing

Now let's borrow some sBTC as this same user.

`(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.lagoon borrow u10000)`

If you look at that function, this will set a block interaction time and calculate any already owed interest.

When we go to repay this loan, we can repay the amount we owe plus our accrued interest.

Let's first advance the chain tip and then see how much we owe.

`::advance_chain_tip 200`

Now we can see how much we owe.

`(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.lagoon get-amount-owed)`

This will show us how much we owe including what we borrowed and how much interest we have accrued.

## Repay Loan

Now let's repay our loan plus the interest.

`(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.lagoon repay u11000)`

## Claim Yield

Finally, let's switch back to our original depositor.

`::set_tx_sender ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM`

And claim our yield.

`(contract-call? .lagoon claim-yield)`

And we can see that 1,000 sats were transferred, since there was a pool reserve of 2,000 and we are responsible for half the deposits in the pool.

## Building Your Bitcoin DeFi App

This was a very basic, simplistic example of how to use sBTC to build a DeFi app. This of course is not a production-ready DeFi contract.

If you are interested in building out your own Bitcoin DeFi project, here are some places to go for inspiration on how Bitcoin DeFi works, what is needed in the ecosystem, as well as some existing projects to learn from.

- [Bitcoin DeFi for Developers](https://www.hiro.so/books/a-developers-guide-to-bitcoin-defi)
- [Zest](https://www.zestprotocol.com/)
- [Hermetica](https://hermetica.fi/)
- [Bitflow](https://www.bitflow.finance/)
- [Velar](https://www.velar.co/)

## Payment Streaming Examples

Start a new stream
`(contract-call? .stream stream-to 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 u100000 {start-block: u5, stop-block: u100} u100)`

`::get_block_height` to see current block height.

`::advance_chain_tip 20` to set new block height.

`(contract-call? .stream balance-of u0 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)` to check balance.

`::set_tx_sender ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5` to set new context.

`(contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.stream withdraw u0)` to withdraw

`::get_assets_maps` to check new balance
