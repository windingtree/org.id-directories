#  ArbitrableDirectory 
## Overview

ArbitrableDirectory is a type of ORGiD directory but with the support of [Kleros arbitration](https://developer.kleros.io/en/latest/).
In order to add new organizaion to the directory its owner should make a request and deposit required amount of Lif tokens. Anyone who is against this organization being in the directory can challenge it. Then the requester, or someone else on his behalf, can accept the challenge, thus creating a dispute in Kleros arbitrator, where the jurors will decide should the organization be in the directory or not. Juror's decision can be appealed.

## Make a request

- function `requestToAdd(bytes32)`
- arguments:
    - `ID of the organization`
- events: 
    - `OrganizationSubmitted`

The function requires a Lif deposit which value is defined by `requesterDeposit` storage parameter.
Once the request has been successfully made the deposit gets stored within the contract and the organization becomes open to challenge.

## Challenge the organization

- function `challengeOrganization(bytes32, string)`
- arguments:
    - `ID of the organization`
    - `A link to evidence using its URI`
- events:
    - `Evidence`. Not emitted if the evidence URI is not provided.

The function requires ETH deposit which value is defined by `challengeBaseDeposit` storage parameter and the cost of the arbitration.
If the organization doesn't get challenged for the duration of `executionTimeout` then it can be included in the directory with `executeTimeout` function, but once registered it can be challenged again. The organization can have only one ongoing challenge at a time.

## Accept the challenge

- function `acceptChallenge(bytes32, string)`
- arguments:
    - `ID of the organization`
    - `A link to evidence using its URI`
- events:
    - `Dispute`
    - `Evidence`. Not emitted if the evidence URI is not provided.

The function requires ETH deposit which value is defined by `challengeBaseDeposit` storage parameter and the cost of the arbitration.
Accepting the challenge creates a dispute in arbitrator contract. If the challenge is not accepted for the duration of `responseTimeout` then the organization can be removed from the directory with `executeTimeout` function. If the organization wasn't in the directory and only had a registration request, then its request gets declined.
The winner of the dispute gets the ETH deposit of the losing party (minus arbitration fees), and the challenger also gets the Lif deposit of the requester. When arbitrator refuses to arbitrate the requester and challenger get their deposits back (minus an equal share of arbitration fees spent on dispute creation) and the organization's state is kept as it was before the dispute, e.g. if it was registered, it stays registered and if it was not registered yet, then it will not be added.

## Appeal mechanism

Challenger and requester can appeal the dispute ruling by depositing an appeal fee within dispute's `appealPeriod`. Appeal fees can be crowdfunded and the sum of both fees will be distributed proportionally between crowdfunders who contributed to the winning side. If appeal funding is successful the dispute will be arbitrated again.

- function `fundAppeal(bytes32, Party)`
- arguments: 
    - `ID of the organization`
    - `Index of the party that gets the appeal contribution`. 1: Requester, 2: Challenger.

If a side does not pay its fees, it is assumed to have lost the dispute. The side currently losing must pay its fees during the first half of the `appealPeriod`.

## Lif stake withdrawal

The owner of the organization has an option to withdraw deposited Lif tokens. In order to avoid malicious ORGs from withdrawing in response to a challenge, a short period of time (`withdrawTimeout`) is required between the time the withdrawal request is made and executed. The organization is removed from the directory in the process.

- function makeWithdrawalRequest(bytes32)1
- arguments:
`ID of the organization`
- events: 
    - `OrganizationRemoved`

The organization can still be challenged until `withdrawTimeout` has expired.