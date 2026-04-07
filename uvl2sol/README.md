## uvl2sol

Example usage:

```
 python3 uvl2sol_require.py token.uvl --infra DiamondCut,DiamondLoupe,Ownership
```

The "infra" features are specific to this paper Diamond pattern modifications.
Copy the output of the script into the `isValidProduct` function of `SPL.sol` -- the output should be the entire function implementation.