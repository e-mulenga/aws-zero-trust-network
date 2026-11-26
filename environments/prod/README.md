# prod environment

| | prod |
|---|---|
| Encryption | Landing Zone CMKs required (`require_cmk = true`): the plan fails until the Landing Zone exports them |
| Firewall deletion protection | on |

Setup: copy each `*.example` here to its name without `.example` (git-ignored), fill in the Landing Zone values, then:

```bash
scripts/tf.sh prod cluster init && scripts/tf.sh prod cluster apply
scripts/tf.sh prod data init && scripts/tf.sh prod data apply
scripts/tf.sh prod zerotrust init && scripts/tf.sh prod zerotrust apply
```
