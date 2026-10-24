# Q8 variants — prompt wording plan

Last updated: 2026-10-24

Branch: `variations_temp`

Status: implemented in `Question-8-CNI-Network-Policy/variants.bash`.

## Goal

Make the printed Question 8 variant prompt read essentially like the original
`questions` text on `origin/variations_setup`, while making the
"The CNI you choose must" section match the CNI the active variant expects.

Decisions taken:

- Both Flannel and Calico remain listed under "Choose one of the following".
- The prompt keeps the original wording and structure; the `tht` typo is
  fixed to `that`.
- A short run-details note shows the cluster pod subnet and the edits the
  validator requires.
- Item 3 is qualified with the variant's release so the requirement list
  points to exactly one of the two listed CNIs.

## Prompt text

### Variant 1

```text
============================================================
 Question 8: CNI & Network Policy (Variant 1/2)
============================================================

Install and configure a CNI of your choice that meets the specified requirements,
Choose one of the following:

Flannel (v0.26.1) using the manifest kube-flannel.yml
(https://github.com/flannel-io/flannel/releases/download/v0.26.1/kube-flannel.yml)

or

Calico (v3.28.2) using the manifest tigera-operator.yaml
(https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml)

The CNI you choose must
1. Let pods communicate with each other
2. Support network policy enforcement
3. Install from manifest (release v3.28.2)

Run details:
- Cluster pod subnet: <POD_SUBNET>
- In custom-resources.yaml, set the IP pool CIDR to <POD_SUBNET> and
  set spec.calicoNetwork.bgp to Disabled; this cluster's underlay does
  not exchange BGP.

Verify all nodes are Ready and the CoreDNS pods are Running.

Video Link - https://youtu.be/Uc04Ui4x3EM
============================================================
```

### Variant 2

```text
============================================================
 Question 8: CNI & Network Policy (Variant 2/2)
============================================================

Install and configure a CNI of your choice that meets the specified requirements,
Choose one of the following:

Flannel (v0.26.1) using the manifest kube-flannel.yml
(https://github.com/flannel-io/flannel/releases/download/v0.26.1/kube-flannel.yml)

or

Calico (v3.28.2) using the manifest tigera-operator.yaml
(https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml)

The CNI you choose must
1. Let pods communicate with each other
2. Use a VXLAN overlay (backend type "vxlan") with no BGP requirement
3. Install from manifest (release v0.26.1)

Run details:
- Cluster pod subnet: <POD_SUBNET>
- In kube-flannel.yml, change net-conf.json Network from 10.244.0.0/16
  to <POD_SUBNET> and keep the backend type "vxlan".

Verify all nodes are Ready and the CoreDNS pods are Running.

Video Link - https://youtu.be/Uc04Ui4x3EM
============================================================
```

## Code changes

Only `Question-8-CNI-Network-Policy/variants.bash` was changed:

1. Added fixed constants for both CNI options so the shared list is not
   duplicated:
   - `FLANNEL_VERSION`, `FLANNEL_MANIFEST_NAME`, `FLANNEL_MANIFEST_URL`
   - `CALICO_VERSION`, `CALICO_MANIFEST_NAME`, `CALICO_MANIFEST_URL`,
     `CALICO_EXTRA_MANIFEST_URL`
2. Pointed `variant_config` at those constants instead of repeating the URLs
   and versions.
3. Rewrote `variant_question` with one shared options block, then a small
   `case` that selects:
   - the requirement line (policy enforcement vs VXLAN/no BGP),
   - the release qualifier for item 3,
   - the run-details edits.
4. Replaced the header comment that said variant 2 must not name the CNI; it
   is no longer true now that both options are printed.

No changes needed to:

- `validate.bash` — same variant values and checks.
- `cleanup.bash`, `LabSetUp.bash` — same setup/cleanup flow.
- `Questions.bash` — generic study text, not printed for variant labs.
- `SolutionNotes.bash` — already covers the CIDR/BGP and `net-conf.json`
  edits.

## Verification

Non-destructive (completed):

- `bash -n` on `variants.bash`, `LabSetUp.bash`, and `validate.bash`: pass.
- Rendered both prompts with `POD_SUBNET=192.168.0.0/16`; both outputs match
  the proposed text below and both invalid-variant calls return `rc=1`.
- Variant config values are unchanged: Calico `v3.28.2` with policy required;
  Flannel `v0.26.1` with policy not required.

Full contract check (not run in this environment; destructive and requires a
disposable cluster):

- `scripts/cleanup-question.sh 8`
- For each variant: `scripts/run-question.sh 8 <v>`, confirm the printed
  text, validate before solving (expected failure), install the solution,
  validate after (expected 22/22), cleanup.

## Resolved decision

Item 3 is qualified with the release so the "must" list uniquely selects the
correct CNI even though both options are printed. The alternative of leaving
item 3 as exactly `3. Install from manifest` was not used because the
requirement list alone would not rule out the other CNI.
