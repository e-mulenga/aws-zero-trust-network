# dev environment

| | dev |
|---|---|
| Encryption | AWS-managed keys (cost-optimised) |
| Firewall deletion protection | off |

Setup: copy each `*.example` here to its name without `.example` (git-ignored), fill in the Landing Zone values, then:

```bash
scripts/tf.sh dev cluster init && scripts/tf.sh dev cluster apply
scripts/tf.sh dev data init && scripts/tf.sh dev data apply
scripts/tf.sh dev zerotrust init && scripts/tf.sh dev zerotrust apply
```
