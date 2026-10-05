Invariant_INV2_solvency caught mutation:
```
Failing tests:
Encountered 1 failing test in test/invariant/StakingInvariants.t.sol:StakingInvariants
[FAIL: INV-2: protocol holds less staking-token than it owes: 0 < 183835738879878646066098]
[Sequence] (original: 1, shrunk: 1)                                                                                                                                                                                                                           
sender=0x0000000000000000000000000000000000004132 addr=[test/invariant/StakingHandler.sol:StakingHandler]0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f calldata=stake(uint256,uint256,uint256) args=[125802540830529804584637 [1.258e23], 19836259227177247352104859048344772975583598 [1.983e43], 2023949983437309991284713063185770183835738879878646066098 [2.023e57]]                                                                                                                                                      
invariant_INV2_solvency() (runs: 0, calls: 0, reverts: 0)
```

Invariant_INV5_ownership caught mutation:
```
Failing tests:
Encountered 1 failing test in test/invariant/StakingInvariants.t.sol:StakingInvariants
[FAIL: INV-5: owner diverged from the authorized-transfer ghost: 0xA4d4c1f8a763Ef6a0140D04291eCEef913Ffc272 != 0xaA10a84CE7d9AE517a52c6d5cA153b369Af99ecF]
        [Sequence] (original: 6, shrunk: 1)                                                                                                                                                                                                                           
                sender=0x69e261bb6BBD9920E0a426Ae518e3ffc9c177411 addr=[test/invariant/StakingHandler.sol:StakingHandler]0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f calldata=outsiderCallsEverything(uint256,uint256,uint256) args=[110, 604800 [6.048e5], 1]         
 invariant_INV5_ownership() (runs: 0, calls: 0, reverts: 0)                                                                                                                                                                                                           

Encountered a total of 1 failing tests, 0 tests succeeded
```

Invariant_INV8_exitGuarantee caught mutation:
```
Failing tests:
Encountered 1 failing test in test/invariant/StakingInvariants.t.sol:StakingInvariants
[FAIL: INV-8: an actor with a stake could not exit]
        [Sequence] (original: 15, shrunk: 2)                                                                                                                                                                                                                          
                sender=0x0000000000000000000000000000000000000B92 addr=[test/invariant/StakingHandler.sol:StakingHandler]0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f calldata=stake(uint256,uint256,uint256) args=[641242133878145407993810016599451698275980 [6.412e41], 99402300271860265772858660445053734915909249818748780164195262015441 [9.94e67], 1498]                                                                                                                                                                              
                sender=0x0000000000000000000000000000000000003E2C addr=[test/invariant/StakingHandler.sol:StakingHandler]0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f calldata=exitProbe(uint256,uint256) args=[2852, 17505 [1.75e4]]                                   
 invariant_INV8_exitGuarantee() (runs: 0, calls: 0, reverts: 0)                                                                                                                                                                                                       

Encountered a total of 1 failing tests, 0 tests succeeded
```

