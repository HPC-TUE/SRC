# NTRS plugin

Deploys the **Not The Real Snellius** training cluster on a single Rocky Linux 9
host: OpenHPC Slurm, Lmod, EESSI, and Open OnDemand with JupyterLab and an XFCE
desktop.

## Usage

Run the playbook on the target host as root. Its Ansible dependencies are
available as Rocky Linux 9 and EPEL 9 RPM packages; Ansible Galaxy is not
required:

```bash
dnf install -y epel-release
dnf install -y ansible-core ansible-collection-ansible-posix
ansible-playbook setup-not-the-real-snellius.yml
```

The playbook targets `localhost` with a local connection; no inventory, SSH
connection, or `become` is used. EPEL provides `ansible.posix` 1.6.2, satisfying
the minimum version declared in `requirements.yml`. Rerunning the playbook is
idempotent.

## What it configures

- An OpenHPC 3.x Slurm controller and compute node on `localhost`, partition
  `rome` with a one-hour limit and shared (non-exclusive) CPUs.
- Slurm cgroup enforcement of allocated CPUs, memory, swap, and devices using
  the stacked `task/cgroup,task/affinity` plugins and a managed `cgroup.conf`.
- Lmod with the default OpenHPC modulefiles removed and the EESSI 2023.06,
  2025.06, and 2026.06 modulefiles when CVMFS can be mounted.
- PAM-authenticated Open OnDemand with an SCC-branded dashboard, JupyterLab, and
  an XFCE desktop through the VNC batch-connect template.
- 75 training accounts `HPCuser01`-`HPCuser75` with passwordless SSH keys.

The playbook contains the full configuration and its verification tasks; see the
comments in `setup-not-the-real-snellius.yml` for details.
