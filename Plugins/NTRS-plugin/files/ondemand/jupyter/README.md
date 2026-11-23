# JupyterLab batch-connect app

This system app is adapted from the official OSC Jupyter batch-connect example:

- Repository: https://github.com/OSC/bc_example_jupyter
- Source revision: `94d29b4ba705cfe3b17df8ce78f584a4a2f986c5`
- OnDemand 4.2 tutorial: https://osc.github.io/ood-documentation/latest/tutorials/tutorials-interactive-apps/add-jupyter.html

The app was customized for this single-host Rocky 9 training cluster:

- It launches JupyterLab rather than the legacy Jupyter Notebook interface.
- It uses the isolated `/opt/jupyterlab` Python environment instead of Lmod.
- It uses current Jupyter `ServerApp` and `IdentityProvider` configuration.
- The `snellius` cluster and `rome` partition are fixed.
- Slurm enforces the one-hour limit; the CPU selector is capped from discovered
  target resources when Ansible renders `form.yml.j2`.
- Notebooks start in the trainee's home directory.
- `copy_environment: true` gives the job Slurm's normal `--export=ALL` behavior.
  This also avoids the Slurm 25.11 `--export=NONE` namespace failure seen in
  containers without `CAP_SYS_ADMIN`; no container capability is added by the
  production playbook.
- Ansible installs `template/script.sh.erb` as executable because OnDemand runs
  the generated `script.sh` directly.

The OSC MIT license and Jupyter icon are retained in this directory.
