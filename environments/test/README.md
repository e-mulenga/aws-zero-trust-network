# test environment

| | test |
|---|---|
| Encryption | AWS-managed keys (cost-optimised) |
| Firewall deletion protection | off |

Setup: copy each `*.example` here to its name without `.example` (git-ignored), fill in the Landing Zone values, then:

```bash
scripts/tf.sh test cluster init && scripts/tf.sh test cluster apply
scripts/tf.sh test data init && scripts/tf.sh test data apply
scripts/tf.sh test zerotrust init && scripts/tf.sh test zerotrust apply
```
