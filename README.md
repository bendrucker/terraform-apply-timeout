# terraform-apply-timeout

> Demonstrates how Terraform behaves when it is interrupted before completion

## Reproduction

The reproduction in this repository runs as an [Actions workflow](./.github/workflows/terraform.yml) on each push. It verifies that the resulting state matches the behavior described below, using a local (file) backend.

### Module

The module in this repository includes:

* `null_resource`, which will apply effectively instantly
* `time_sleep`, which is configured to take 1 minute to create

This provides a module that can be interrupted, with one completed resource and one incomplete. Sending the relevant signal after a delay is implemented using [`timeout`](https://man7.org/linux/man-pages/man1/timeout.1.html).

### Apply

At the start of an apply, Terraform writes the _resources_ to the state file. This records the declared resources and key statically evaluable properties, namely:

* `type`
* `name`
* `provider`

However, at this stage, the `instances` for the resources are unchanged and will be empty for new objects. Given the two resources in this module, `.resources[*]` has two results, but `.resources[*].instances[*]` has zero.

### `TERM`

Upon receiving a `TERM` signal, Terraform attempts to reconcile/write its state and gracefully shut down. Any resources that could not be created are removed. Any resource _instances_ that were created are added/updated.

Given the two resources in this module, `.resources[*]` has one result, and `.resources[0].instances[*]` also has one.

### `KILL`

Upon being sent a `KILL` signal, which cannot be handled, Terraform is immediately terminated. The resulting state is identical to what was allocated at the beginning of the [apply](#apply). 

Given the two resources in this module, `.resources[*]` has two results, but `.resources[*].instances[*]` has zero.

In some test runs, the `KILL` behavior has been identical to `TERM`, suggesting that this behavior may be non-deterministic. Given that `KILL` should be immediate from the perspective of the process, this is unexpected and requires further investigation. 

## Implications

Sending a `KILL` to Terraform should be avoided wherever possible, as it may cause data loss and pipeline breakage. Since the `null_resource` is a noop, the module in this repository could be re-applied without issue. In a real-world case, Terraform may be creating/destroying objects in a remote API and then failing to track those objects in state, at best creating an orphaned. For resources that have API-enforced uniqueness requirements (e.g., on a `name`), the pipeline is broken by an untracked resource creation, since a retry will fail with a conflict error.

Signaling Terraform with `TERM` first allows it to track the progress of the apply, even if the result is ultimately a (partial) failure. In most cases, Terraform should exit on its own. But after a grace period of several seconds, a `KILL` can be sent to ensure the process exits in cases where it is entirely hung/broken.
