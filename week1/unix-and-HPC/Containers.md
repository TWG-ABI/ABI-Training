<p align="center">
  <img src="linux_banner_image.png" alt="ABI Summer School 2026 · WEEK 1: Linux / HPC" width="100%" />
</p>

<style>
/* Clean, modern, high-contrast code blocks with pretty borders */
div.sourceCode, pre.sourceCode, pre, pre code, div.cell-code pre {
  background-color: #f8f9fa !important;
  color: #212529 !important;
  border: 1px solid #dee2e6 !important;
  border-left: 4px solid #31BAE9 !important;
  border-radius: 6px !important;
}
/* Ensure comments and shebangs (#) are crisp, legible, and distinct */
code span.co, code span.c, code span.ch, code span.cm, code span.c1 {
  color: #2e7d32 !important;
  font-weight: 600 !important;
  opacity: 1 !important;
}
</style>

# Introduction to Containers

## What is a Container?

A container is a lightweight, portable package that bundles an application together with everything it needs to run — libraries, tools, system packages, and configuration — into a single unit that behaves the same way on any machine.

Without containers, getting software to run on a new machine means manually installing the right versions of every dependency and hoping nothing conflicts with what's already installed. With containers, you package the entire environment once and run it anywhere.

```
┌─────────────────────────────────────┐
│         Your Container              │
│  ┌───────────────────────────────┐  │
│  │     Your Application          │  │
│  │  ┌─────────┐ ┌─────────┐      │  │
│  │  │ Python  │ │ NumPy   │      │  │
│  │  │ 3.11    │ │ 1.24    │ ...  │  │
│  │  └─────────┘ └─────────┘      │  │
│  └───────────────────────────────┘  │
│       Operating System Layer        │
│         (Ubuntu 22.04)              │
└─────────────────────────────────────┘
       Runs the same everywhere:
       laptop, cloud, HPC cluster
```

A container image is a read-only template. When you "run" an image, you create a container — a live instance of that template. You can run many containers from the same image, and each one is isolated from the others.

:::info Why should you care?
If you've ever said "it works on my machine" and then spent hours debugging it on the cluster, containers eliminate that problem entirely. The environment that works on your laptop is the same environment that runs on ACE HPC.
:::

## Containers vs. Virtual Machines

You may be familiar with Virtual Machines (VMs). Both VMs and containers provide isolation, but they work differently:

- A **Virtual Machine** includes an entire guest operating system on top of a hypervisor. This makes VMs heavy (gigabytes), slow to start (minutes), and resource-intensive.
- A **Container** shares the host operating system's kernel and only packages the application and its dependencies. This makes containers lightweight (megabytes), fast to start (seconds), and nearly as performant as running natively.

For HPC workloads where performance matters, containers add negligible overhead compared to running software directly on the host.

## Docker and Apptainer

Two container platforms matter for HPC work:

### Docker

[Docker](https://www.docker.com/) is the industry standard for building and distributing container images. It provides:

- A simple build syntax (the **Dockerfile**)
- A massive ecosystem of pre-built images on [Docker Hub](https://hub.docker.com/)
- Excellent developer tooling

However, Docker requires root (administrator) privileges to run. On shared HPC systems where users don't have root access, Docker cannot be used directly.

### Apptainer

[Apptainer](https://apptainer.org/) (formerly Singularity) was built specifically for HPC. It solves the root privilege problem:

- **Runs as your normal user** — no root required
- **Integrates with SLURM** — works seamlessly in batch job scripts
- **Runs Docker images directly** — pull any Docker image and run it with Apptainer
- **Near-native performance** — minimal overhead, direct access to host hardware (GPUs, high-speed networks)

**On ACE HPC, we use Apptainer to run containers.**

The practical workflow is: build your containers with Docker on your workstation, push them to a registry, then pull and run them with Apptainer on ACE HPC.

## The Container Workflow on ACE HPC

```
  Your Workstation (Docker)              ACE HPC (Apptainer + SLURM)
 ┌──────────────────────────┐          ┌──────────────────────────┐
 │ 1. Write Dockerfile      │          │ 4. Pull image            │
 │ 2. Build image           │  ──────> │ 5. Convert to .sif       │
 │ 3. Push to registry      │          │ 6. Run with SLURM        │
 └──────────────────────────┘          └──────────────────────────┘
                    │
              Docker Hub or
              GitHub Container
              Registry
```

1. **Write** a Dockerfile describing your software environment
2. **Build** the container image on your workstation (where you have Docker)
3. **Push** the image to a container registry (Docker Hub, GitHub Container Registry)
4. **Pull** the image on ACE HPC using Apptainer
5. **Convert** — Apptainer automatically converts Docker images to its native `.sif` format
6. **Run** your containerized application through SLURM job scripts

## Quick Start: Run Your First Container

Log into ACE HPC and try this:

```bash
# Load the Apptainer module
module load apptainer

# Pull a Python container from Docker Hub
apptainer pull docker://python:3.11-slim

# Run Python inside the container
apptainer exec python_3.11-slim.sif python -c "
import sys
print('Hello from inside a container!')
print(f'Python version: {sys.version}')
import os
print(f'User: {os.environ.get(\"USER\", \"unknown\")}')
print(f'Hostname: {os.uname().nodename}')
"
```

Notice two things: (1) you didn't install Python — it came from the container, and (2) your username and host environment are visible inside the container. This is Apptainer's design — it runs as *you*, not as root.

## Prerequisites

To follow these tutorials, you'll need:

- **Basic Linux command-line skills** — navigating directories, editing files, running commands
- **A programming language** — the examples use Python, but the concepts apply to any language

For building containers (covered in the next section), you'll also need:

- [Docker Desktop](https://docs.docker.com/get-docker/) installed on your local machine
- A free [Docker Hub](https://hub.docker.com/signup) account

## Tutorial Roadmap

This tutorial series has three sections:

| Section | What You'll Learn |
|---------|-------------------|
| [Containerize Your Code](containerize-code) | Write a Dockerfile, build an image, push it to a registry |
| [Advanced Build Topics](advanced-builds) | Multi-stage builds, multi-architecture builds |
| [Containers on HPC Clusters](containers-hpc) | Apptainer on ACE HPC, SLURM job scripts, MPI and GPU containers |

## References

- [Apptainer User Guide](https://apptainer.org/docs/user/latest/)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/) — public registry of container images
- [BioContainers](https://biocontainers.pro/) — pre-built containers for bioinformatics tools
- [NVIDIA NGC Catalog](https://catalog.ngc.nvidia.com/) — GPU-optimized containers


---

# Containerize Your Code

In this tutorial, you will write a Dockerfile, build a container image, test it locally, and push it to Docker Hub so it can be used on ACE HPC. We'll work through a single example from start to finish.

## What is a Dockerfile?

A Dockerfile is a plain text file that contains a sequence of instructions for building a container image. Each instruction creates a **layer** in the image. Docker reads the Dockerfile top-to-bottom, executing each instruction in order, and the result is an image you can run anywhere.

Here are the core instructions:

| Instruction | What it does |
|-------------|-------------|
| `FROM` | Sets the base image — your starting point |
| `RUN` | Executes a command during the build (install packages, compile code, etc.) |
| `COPY` | Copies files from your machine into the image |
| `ENV` | Sets an environment variable that persists when the container runs |
| `WORKDIR` | Sets the working directory for subsequent instructions |
| `CMD` | Defines the default command when the container starts |
| `ENTRYPOINT` | Configures the container to run as an executable |

Let's see how these work together in practice.

## The Example: A Monte Carlo Simulation

We'll containerize a Python script that estimates the value of Pi using a Monte Carlo method. This is a common computational technique — generate random points in a square, count how many fall inside a circle, and use the ratio to estimate Pi.

### Project Setup

On your local workstation (where Docker is installed), create a project directory:

```bash
$ mkdir ~/monte-carlo && cd ~/monte-carlo
```

### The Application Code

Create a file called `estimate_pi.py`:

```python
#!/usr/bin/env python3
"""Estimate Pi using a Monte Carlo method."""

import argparse
import numpy as np
import time
import json
import os

def estimate_pi(num_samples):
    """Generate random points in a unit square, count those inside the unit circle."""
    x = np.random.uniform(0, 1, num_samples)
    y = np.random.uniform(0, 1, num_samples)
    inside_circle = np.sum(x**2 + y**2 <= 1)
    return 4 * inside_circle / num_samples

def main():
    parser = argparse.ArgumentParser(description="Estimate Pi using Monte Carlo simulation")
    parser.add_argument("samples", type=int, nargs="?", default=1_000_000,
                        help="Number of random samples (default: 1,000,000)")
    parser.add_argument("--output", "-o", type=str, default=None,
                        help="Path to write JSON results")
    parser.add_argument("--seed", type=int, default=None,
                        help="Random seed for reproducibility")
    args = parser.parse_args()

    if args.seed is not None:
        np.random.seed(args.seed)

    print(f"Estimating Pi with {args.samples:,} samples...")
    start = time.time()
    pi_estimate = estimate_pi(args.samples)
    elapsed = time.time() - start

    error = abs(pi_estimate - np.pi)
    print(f"  Estimate: {pi_estimate:.8f}")
    print(f"  Actual:   {np.pi:.8f}")
    print(f"  Error:    {error:.8f}")
    print(f"  Time:     {elapsed:.3f}s")

    if args.output:
        results = {
            "samples": args.samples,
            "estimate": pi_estimate,
            "error": error,
            "elapsed_seconds": elapsed,
        }
        with open(args.output, "w") as f:
            json.dump(results, f, indent=2)
        print(f"  Results written to {args.output}")

if __name__ == "__main__":
    main()
```

Test it locally to make sure it works:

```bash
$ python estimate_pi.py 100000
```

### The Requirements File

Create `requirements.txt` with pinned versions for reproducibility:

```
numpy==1.24.3
```

:::tip Why pin versions?
Using `numpy==1.24.3` instead of just `numpy` ensures that anyone building this container — today or six months from now — gets the exact same version. Without pinning, `pip install numpy` installs whatever the latest version is at build time, which can break your code if the API changes.
:::

### Writing the Dockerfile

Now we translate the manual setup steps into a Dockerfile. Create a file called `Dockerfile` (no extension):

```dockerfile
FROM python:3.11-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY estimate_pi.py /app/estimate_pi.py
RUN chmod +x /app/estimate_pi.py

ENV PATH="/app:$PATH"

WORKDIR /app

CMD ["python", "estimate_pi.py"]
```

Let's walk through each instruction:

**`FROM python:3.11-slim`** — We start from the official Python 3.11 image, using the `-slim` variant which strips out compilers and docs we don't need. This is ~125 MB instead of ~1 GB for the full image. Avoid `python:latest` — the meaning of "latest" changes over time, making your builds non-reproducible.

**`RUN apt-get update && apt-get install ...`** — Installs system-level build tools that numpy needs for compilation. The `--no-install-recommends` flag skips optional packages, and `rm -rf /var/lib/apt/lists/*` cleans up the package cache. These are combined into a single `RUN` instruction because each `RUN` creates a new image layer — combining them keeps the image smaller.

**`COPY requirements.txt ...` then `RUN pip install ...`** — We copy the requirements file *before* the application code. This is intentional: Docker caches each layer, and layers only rebuild when their inputs change. If you change `estimate_pi.py` but not `requirements.txt`, Docker reuses the cached pip install layer instead of reinstalling all dependencies. This can save minutes on every rebuild.

**`COPY estimate_pi.py ...` then `RUN chmod +x ...`** — Copies the application code and makes it executable.

**`ENV PATH="/app:$PATH"`** — Adds `/app` to the system PATH so you can run `estimate_pi.py` directly without specifying the full path.

**`WORKDIR /app`** — Sets the working directory. Any subsequent commands (and the default command when the container starts) run from this directory.

**`CMD ["python", "estimate_pi.py"]`** — The default command. When you run the container without specifying a command, it executes this. You can override it at runtime by appending a different command.

### Building the Image

From the `~/monte-carlo` directory (where your Dockerfile lives), run:

```bash
$ docker build --platform linux/amd64 -t ianwasukira/monte-carlo:0.1 . 
```
- `--platform` tells docker to build the image for a specific target operating platform, Intel/AMD Linux systems
- `-t ianwasukira/monte-carlo:0.1` specifies the account docker should push the image to & tags the image with a name and version
- `.` tells Docker to use the current directory as the build context (it looks for a file named `Dockerfile` here)

```
[+] Building 0.5s (10/10) FINISHED                                                                                                                                                             docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                                                           0.0s
 => => transferring dockerfile: 244B                                                                                                                                                                           0.0s
 => [internal] load metadata for docker.io/library/ubuntu:24.04                                                                                                                                                0.4s
 => [internal] load .dockerignore                                                                                                                                                                              0.0s
 => => transferring context: 2B                                                                                                                                                                                0.0s
 => [1/5] FROM docker.io/library/ubuntu:24.04@sha256:d1e2e92c075e5ca139d51a140fff46f84315c0fdce203eab2807c7e495eff4f9                                                                                          0.0s
 => => resolve docker.io/library/ubuntu:24.04@sha256:d1e2e92c075e5ca139d51a140fff46f84315c0fdce203eab2807c7e495eff4f9                                                                                          0.0s
 => [internal] load build context                                                                                                                                                                              0.0s
 => => transferring context: 92B                                                                                                                                                                               0.0s
 => CACHED [2/5] RUN apt-get update && apt-get upgrade -y                                                                                                                                                      0.0s
 => CACHED [3/5] RUN apt-get install -y python3                                                                                                                                                                0.0s
 => CACHED [4/5] COPY pi.py /code/pi.py                                                                                                                                                                        0.0s
 => CACHED [5/5] RUN chmod +rx /code/pi.py                                                                                                                                                                     0.0s
 => exporting to image                                                                                                                                                                                         0.0s
 => => exporting layers                                                                                                                                                                                        0.0s
 => => exporting manifest sha256:02282c6a660f0cddec59ad57f11bad9be4fa447572128d5a50109d8e8359a478                                                                                                              0.0s
 => => exporting config sha256:d8631be9d908addfd25f392d8cbf70240021c301bc79553e48d6af70067c8450                                                                                                                0.0s
 => => exporting attestation manifest sha256:e2a61ec11f0ea3d3b8c9d38e65039e1c0b9a74f5059478c7b5dcc73d449ee288                                                                                                  0.0s
 => => exporting manifest list sha256:efa123ce9ceaac09819d6f6a0d591c5b39209b61ba4a8d3657a8eac08edfcbd8                                                                                                         0.0s
 => => naming to docker.io/ianwasukira/monte-carlo:0.1                                                                                                                                                         0.0s
```

You should see Docker execute each instruction. Subsequent builds will be much faster because of layer caching — Docker skips unchanged layers.

Verify the image was created:

```bash
$ docker images monte-carlo
```

```
REPOSITORY    TAG    IMAGE ID       CREATED          SIZE
monte-carlo   0.1    a1b2c3d4e5f6   30 seconds ago   198MB
```

### Testing the Container

Run the container with the default command:

```bash
$ docker run --rm monte-carlo:0.1
```

The `--rm` flag removes the container after it exits (otherwise stopped containers accumulate). You should see output like:

```
Estimating Pi with 1,000,000 samples...
  Estimate: 3.14132400
  Actual:   3.14159265
  Error:    0.00026865
  Time:     0.024s
```

Override the default to pass arguments:

```bash
$ docker run --rm monte-carlo:0.1 python estimate_pi.py 10000000 --seed 42
```

Write output to a file using a **bind mount** — this maps a directory on your host into the container so data persists after the container exits:

```bash
$ mkdir -p ~/monte-carlo/output

$ docker run --rm \
    -v ~/monte-carlo/output:/output \
    monte-carlo:0.1 \
    python estimate_pi.py 5000000 --output /output/results.json

$ cat ~/monte-carlo/output/results.json
```

Start an interactive shell inside the container to explore:

```bash
$ docker run --rm -it monte-carlo:0.1 /bin/bash
```

From inside the container, you can run `python`, check installed packages with `pip list`, inspect the filesystem, and so on. Type `exit` to leave.

### Using .dockerignore

When Docker builds an image, it sends the entire build context (the `.` directory) to the Docker daemon. If your project directory contains large data files, `.git` history, or output files, these are unnecessarily copied and slow down the build.

Create a `.dockerignore` file to exclude them:

```
.git
__pycache__
*.pyc
output/
*.log
```

This works exactly like `.gitignore` — any matching files are excluded from the build context.

### Pushing to a Container Registry

Your image currently lives only on your local machine. To use it on ACE HPC, push it to a container registry.

### Docker Hub

```bash
# Log in (you'll be prompted for your Docker Hub credentials)
$ docker login

# Tag the image with your Docker Hub username
$ docker tag monte-carlo:0.1 ianwasukira/monte-carlo:0.1

# Push
$ docker push ianwasukira/monte-carlo:0.1
```

```
The push refers to repository [docker.io/ianwasukira/monte-carlo]
b73415306fae: Pushed
4f4fb700ef54: Mounted from ianwasukira/pi-estimator
66a4bbbfab88: Pushed
3fc31d9c7e98: Pushed
3cc646d3f0dd: Pushed
9dd65c448696: Pushed
0.1: digest: sha256:7e702eccde1d6c730f65a47d45ce7078a54519a232dd6b84137ba14f2f4705f4 size: 856
```
Navigate to [Docker Hub](https://hub.docker.com/repositories) on your preferred web browser, and go to your repositories.

![Image Pushed to DockerHub](/img/docker-hub-push.png)

Alternatively, you can use the GitHub Coontainer Registry (GHCR);

### GitHub Container Registry

```bash
# Log in using a personal access token
$ echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Tag for GHCR
$ docker tag monte-carlo:0.1 ghcr.io/yourusername/monte-carlo:0.1

# Push
$ docker push ghcr.io/yourusername/monte-carlo:0.1
```

### Pulling on ACE HPC

Once pushed, Apptainer can convert the Docker image to its native `.sif` format. `apptainer pull` downloads and converts the image — the result is a single portable file you can reference in your job scripts:

```
$ module load apptainer
$ apptainer pull docker://iawasukira/monte-carlo:0.1
INFO:    Converting OCI blobs to SIF format
INFO:    Starting build...
INFO:    Fetching OCI image...
28.4MiB / 28.4MiB [=============================================================================================================================================================================] 100 % 3.5 MiB/s 0s
13.2MiB / 13.2MiB [=============================================================================================================================================================================] 100 % 3.5 MiB/s 0s
41.1MiB / 41.1MiB [=============================================================================================================================================================================] 100 % 3.5 MiB/s 0s
INFO:    Extracting OCI image...
INFO:    Inserting Apptainer configuration...
INFO:    Creating SIF file...
INFO:    To see mksquashfs output with progress bar enable verbose logging
```

This creates a file called `monte-carlo_0.1.sif`. See the next section for how to pull and run this correctly inside a SLURM job.

### Running Containers with SLURM

:::danger Do not run containers on the head node
The commands shown above (`apptainer pull` and `apptainer run`) are for illustration only. **Do not run them directly on the head node.** The head node is a shared login environment — running compute workloads there slows it down for everyone and may get your session terminated by the system administrators.

All container execution must happen inside a SLURM job script submitted to the compute cluster.
:::

The `apptainer pull` step (converting the Docker image to a `.sif` file) can be resource-intensive and should also be done inside a job. Here is the correct approach for pulling and running the Monte Carlo container:

```bash
#!/bin/bash
#SBATCH --job-name=monte-carlo
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=monte-carlo-%j.out
#SBATCH --error=monte-carlo-%j.err

module load apptainer

# Pull the image from Docker Hub (only needed once; skip if .sif already exists)
if [ ! -f monte-carlo_0.1.sif ]; then
    apptainer pull docker://ianwasukira/monte-carlo:0.1
fi

# Run the simulation inside the container
apptainer run monte-carlo_0.1.sif 1000000 --output results.json
```

Submit it with:

```bash
$ sbatch monte-carlo.sh
```

The full workflow for running containers on ACE HPC, including bind mounts and GPU access, is covered in [Containers on HPC Clusters](containers-hpc).

---
**Next:** [Containers on HPC Clusters](containers-hpc) — pull your images on ACE HPC with Apptainer, write SLURM job scripts, and run MPI and GPU workloads.

---

# Containers on HPC Clusters

This tutorial covers deploying containers on ACE HPC using Apptainer and SLURM. You'll learn how to pull and run Docker images, write batch job scripts for containerized workloads, and run MPI and GPU jobs inside containers.

## How Apptainer Differs from Docker

If you've followed the previous tutorials, you've been using Docker on your workstation. Apptainer works differently in a few important ways:

| | Docker | Apptainer |
|-|--------|-----------|
| **Privileges** | Requires root (admin) access | Runs as your normal user |
| **Image format** | Layered images stored in a daemon | Single `.sif` file you can copy and move |
| **Directory mounts** | Must be explicitly specified with `-v` | Automatically mounts `$HOME`, `$PWD`, and `/tmp` |
| **User identity** | Runs as root inside the container by default | Runs as *you* — same UID, same permissions |
| **Where to build** | On your workstation | Pull pre-built images (no `sudo` on HPC) |

The key takeaway: you **build** containers with Docker on your workstation (where you have root), then **run** them with Apptainer on the cluster (where you don't).

## Introduction to Apptainer

### Loading the Module

Apptainer is available as a module on ACE HPC. Start an interactive session on a compute node before working with containers — don't pull or run containers on the login node:

```bash
# Request an interactive session
$ salloc --ntasks=1 --mem=4G --time=01:00:00

# Load Apptainer
$ module load apptainer

# Verify
$ apptainer --version
```

### Pulling an Image

Apptainer can pull any Docker image and convert it to its native `.sif` format:

```bash
# Pull the Monte Carlo image we built in previous tutorials
$ apptainer pull docker://yourusername/monte-carlo:0.1

# This creates: monte-carlo_0.1.sif
$ ls -lh monte-carlo_0.1.sif
```

The `.sif` file is a single, portable file containing the entire container. You can copy it, move it, share it — it's just a file.

To pull to a specific directory or with a custom filename:

```bash
$ mkdir -p ~/containers
$ apptainer pull ~/containers/monte-carlo.sif docker://yourusername/monte-carlo:0.1
```

:::note Cache management
Apptainer caches downloaded layers in `~/.apptainer/cache`. This counts toward your `$HOME` quota. Clean the cache regularly if you are pulling many images:
```bash
apptainer cache clean
```
You can check cache size with `apptainer cache list`.
:::

### Running Containers

:::danger Do not run containers on the head node
The commands below are for reference only. **Never run `apptainer exec`, `apptainer run`, or `apptainer shell` on the head node for actual compute work.** The head node is a shared login environment — running workloads there degrades it for all users and may result in your session being terminated.

All container execution must be done inside a SLURM job. Use `sbatch` for batch jobs or `salloc` for interactive sessions on a compute node. See the [SLURM Batch Jobs](#slurm-batch-jobs) section below for the correct approach.
:::

Apptainer has three commands for running containers:

**`apptainer exec`** — Run a specific command inside the container. This is what you'll use most often:

```bash
# Run the Monte Carlo simulation
$ apptainer exec monte-carlo_0.1.sif python /app/estimate_pi.py 5000000

# Check what Python version is inside the container
$ apptainer exec monte-carlo_0.1.sif python --version

# List installed packages
$ apptainer exec monte-carlo_0.1.sif pip list
```

**`apptainer shell`** — Start an interactive shell inside the container for exploration and debugging:

```bash
$ apptainer shell monte-carlo_0.1.sif
Apptainer> python --version
Apptainer> ls /app/
Apptainer> cat /etc/os-release
Apptainer> exit
```

Notice that inside the shell, you're still *you* — your home directory is accessible, your files are there, and you have the same permissions as outside. This is different from Docker, where you'd typically be root.

**`apptainer run`** — Execute the container's default command (its `CMD` or `ENTRYPOINT`):

```bash
$ apptainer run monte-carlo_0.1.sif
```


### Interactive Shell Sessions with srun

When you need to explore a container interactively — inspect its filesystem, test commands, or debug a failing job — use `srun` to get an interactive session on a compute node first, then launch `apptainer shell` from there.

```bash
# Request an interactive session on a compute node
$ srun --ntasks=1 --cpus-per-task=2 --mem=4G --time=01:00:00 --pty bash
```

Once your shell lands on a compute node, load Apptainer and open the container:

```bash
$ module load apptainer
$ apptainer shell ~/containers/monte-carlo.sif
```

You'll drop into the container's environment:

```
Apptainer> python --version
Python 3.11.x
Apptainer> pip list
Apptainer> ls /app/
Apptainer> python /app/estimate_pi.py 100000
Apptainer> exit
```

If you need a GPU node for interactive debugging:

```bash
$ srun --ntasks=1 --cpus-per-task=4 --mem=16G --time=01:00:00 \
     --gres=gpu:1 --partition=gpu --pty bash

# Then inside the compute node:
$ module load apptainer
$ apptainer shell --nv ~/containers/gpu-benchmark.sif
```

:::tip
`apptainer shell` inherits your home directory and current working directory automatically, so your data and scripts are accessible inside the container without any extra `--bind` flags.
:::

## SLURM Batch Jobs

On an HPC cluster, you don't run jobs interactively — you write a batch script that specifies the resources you need and the commands to run, then submit it to the scheduler. The scheduler runs your job when resources become available.

### The Example: Monte Carlo Batch Job

Create a file called `monte-carlo.slurm`:

```bash
#!/bin/bash
#SBATCH --job-name=monte-carlo
#SBATCH --output=monte-carlo_%j.out
#SBATCH --error=monte-carlo_%j.err
#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G

# Load Apptainer
module load apptainer

# Define paths
CONTAINER=~/containers/monte-carlo.sif
OUTPUT_DIR=mc_results_$SLURM_JOB_ID

# Create output directory
mkdir -p $OUTPUT_DIR

echo "Job $SLURM_JOB_ID started on $(hostname) at $(date)"
echo "Container: $CONTAINER"
echo "Output:    $OUTPUT_DIR"

# Run the simulation
apptainer exec \
    --bind $OUTPUT_DIR:/output \
    $CONTAINER python /app/estimate_pi.py 50000000 \
        --trials 20 \
        --output /output/results.json

echo "Job completed at $(date)"
echo "Results:"
cat $OUTPUT_DIR/results.json
```

Let's walk through the key parts:

**`#SBATCH` directives** tell SLURM what resources to allocate. `%j` in the output/error filenames is replaced with the job ID, so each run produces uniquely named log files.

**`module load apptainer`** makes the `apptainer` command available. Always include this in your job script — modules loaded in your interactive session aren't inherited by batch jobs.

**`mkdir -p $OUTPUT_DIR`** creates a job-specific output directory. Using `$SLURM_JOB_ID` in the path keeps results from different runs separate.

**`--bind $OUTPUT_DIR:/output`** mounts the scratch directory as `/output` inside the container. The Python script writes to `/output/results.json`, which actually lands on scratch.

Submit the job:

```bash
$ sbatch monte-carlo.slurm
```

Monitor it:

```bash
# Check job status
$ squeue -u $USER

# Once completed, view the output
$ cat monte-carlo_*.out
$ cat mc_results_*/results.json
```

<!-- TODO: Add a screenshot showing squeue output with the container job running -->

## MPI Containers

MPI (Message Passing Interface) enables running a single program across multiple nodes, with processes communicating over the high-speed network. MPI containers require special handling because the MPI library inside the container must be compatible with the host system's MPI and network drivers.

### The Concept

The recommended approach is the **hybrid model**: the container includes MPI libraries, but the *host* MPI launcher (`mpirun` or the cluster's equivalent) starts the processes. This lets the host handle network configuration and process placement while the container provides the application environment.

```
  Host System                    Container
┌─────────────────┐          ┌──────────────────┐
│  mpirun / ibrun │ launches │  Your app + MPI  │
│  (host MPI)     │ ───────> │  (container MPI) │
│                 │          │                  │
│  Manages:       │          │  Provides:       │
│  - Network      │          │  - Application   │
│  - Process      │          │  - Dependencies  │
│    placement    │          │  - Compatible MPI│
└─────────────────┘          └──────────────────┘
```

**Important:** The MPI version inside the container should match or be newer than the host's MPI version. Using the same major version of OpenMPI generally works.

### The Example: Parallel Pi Estimation

We'll create a version of the Monte Carlo simulation that distributes work across multiple MPI processes. Each process estimates Pi with a portion of the total samples, and the results are combined.

On your workstation, create the project:

```bash
mkdir ~/monte-carlo-mpi && cd ~/monte-carlo-mpi
```

Create `estimate_pi_mpi.py`:

```python
#!/usr/bin/env python3
"""Parallel Monte Carlo Pi estimation using MPI."""

from mpi4py import MPI
import numpy as np
import time
import socket
import argparse

def monte_carlo_pi(num_samples):
    x = np.random.uniform(0, 1, num_samples)
    y = np.random.uniform(0, 1, num_samples)
    inside = np.sum(x**2 + y**2 <= 1)
    return inside

def main():
    comm = MPI.COMM_WORLD
    rank = comm.Get_rank()
    size = comm.Get_size()

    parser = argparse.ArgumentParser()
    parser.add_argument("samples", type=int, nargs="?", default=10_000_000)
    args = parser.parse_args()

    # Each process handles an equal share of the samples
    samples_per_rank = args.samples // size
    np.random.seed(rank * 1000 + 42)

    if rank == 0:
        print(f"Estimating Pi with {args.samples:,} total samples across {size} processes")
        start = time.time()

    # Each rank computes its portion
    local_inside = monte_carlo_pi(samples_per_rank)

    # Combine results across all ranks
    total_inside = comm.reduce(local_inside, op=MPI.SUM, root=0)

    if rank == 0:
        pi_estimate = 4 * total_inside / (samples_per_rank * size)
        elapsed = time.time() - start
        print(f"  Estimate: {pi_estimate:.8f}")
        print(f"  Error:    {abs(pi_estimate - np.pi):.8f}")
        print(f"  Time:     {elapsed:.3f}s")
        print(f"  Speedup:  {size} processes")

    # Every rank reports its hostname for verification
    print(f"  Rank {rank}/{size} on {socket.gethostname()}: {local_inside:,} hits "
          f"from {samples_per_rank:,} samples")

if __name__ == "__main__":
    main()
```

Create the `Dockerfile`:

```dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
        openmpi-bin \
        libopenmpi-dev \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir mpi4py numpy

WORKDIR /app
COPY estimate_pi_mpi.py .
RUN chmod +x estimate_pi_mpi.py

CMD ["python3", "estimate_pi_mpi.py"]
```

Build and push:

```bash
$ docker build --platform linux/amd64 -t yourusername/monte-carlo-mpi:0.1 .
[+] Building 51.6s (12/12) FINISHED                                                                                                                                                            docker:desktop-linux
 => [internal] load build definition from Dockerfile                                                                                                                                                           0.0s
 => => transferring dockerfile: 446B                                                                                                                                                                           0.0s
 => [internal] load metadata for docker.io/library/ubuntu:22.04                                                                                                                                                1.0s
 => [auth] library/ubuntu:pull token for registry-1.docker.io                                                                                                                                                  0.0s
 => [internal] load .dockerignore                                                                                                                                                                              0.0s
 => => transferring context: 2B                                                                                                                                                                                0.0s
 => [1/6] FROM docker.io/library/ubuntu:22.04@sha256:3ba65aa20f86a0fad9df2b2c259c613df006b2e6d0bfcc8a146afb8c525a9751                                                                                          1.1s
 => => resolve docker.io/library/ubuntu:22.04@sha256:3ba65aa20f86a0fad9df2b2c259c613df006b2e6d0bfcc8a146afb8c525a9751                                                                                          0.0s
 => => sha256:b1cba2e842ca52b95817f958faf99734080c78e92e43ce609cde9244867b49ed 29.54MB / 29.54MB                                                                                                               0.8s
 => => extracting sha256:b1cba2e842ca52b95817f958faf99734080c78e92e43ce609cde9244867b49ed                                                                                                                      0.3s
 => [internal] load build context                                                                                                                                                                              0.0s
 => => transferring context: 1.54kB                                                                                                                                                                            0.0s
 => [2/6] RUN apt-get update     && apt-get install -y --no-install-recommends         python3         python3-pip         openmpi-bin         libopenmpi-dev     && rm -rf /var/lib/apt/lists/*              40.4s
 => [3/6] RUN pip3 install --no-cache-dir mpi4py numpy                                                                                                                                                         2.5s
 => [4/6] WORKDIR /app                                                                                                                                                                                         0.0s
 => [5/6] COPY estimate_pi_mpi.py .                                                                                                                                                                            0.0s
 => [6/6] RUN chmod +x estimate_pi_mpi.py                                                                                                                                                                      0.1s
 => exporting to image                                                                                                                                                                                         6.3s
 => => exporting layers                                                                                                                                                                                        6.3s
 => => exporting manifest sha256:6ef2c750407397b709e1b0d616052e9fc6626b5a221b03302676f83ff1d2b6f0                                                                                                              0.0s
 => => exporting config sha256:99c2625718bb3a900f9e2efe51abf1c10f9c6e4b5b25806b543864a2feb55fcc                                                                                                                0.0s
 => => exporting attestation manifest sha256:5562fc2c080dc34fe0944bca9d807260209078cafb8b83021c9cddea0a9c157a                                                                                                  0.0s
 => => exporting manifest list sha256:2b9a09f20de16bc9187464b0cc04c7c33db9da1239d9991588ddf2395030bb86                                                                                                         0.0s
 => => naming to docker.io/ianwasukira/monte-carlo-mpi:0.1                                                                                                                                                     0.0s
```

```
docker push yourusername/monte-carlo-mpi:0.1
The push refers to repository [docker.io/yourusername/monte-carlo-mpi]
54c6a19e1ba5: Pushed
195d96c8233d: Pushed
7125307ec0a6: Pushed
64861010b1bc: Pushed
16a2ff661819: Pushed
b1cba2e842ca: Pushed
658d7018384c: Pushed
0.1: digest: sha256:2b9a09f20de16bc9187464b0cc04c7c33db9da1239d9991588ddf2395030bb86 size: 856
```

Test locally with Docker before using cluster :

```bash
# Single process
$ docker run --rm yourusername/monte-carlo-mpi:0.1 \
    mpirun -n 1 python3 /app/estimate_pi_mpi.py 5000000

# Two processes (if Docker has access to multiple cores)
$ docker run --rm yourusername/monte-carlo-mpi:0.1 \
    mpirun -n 2 python3 /app/estimate_pi_mpi.py 5000000
```

On ACE HPC, pull the image and create a batch script called `mpi-pi.slurm`:

```bash
#!/bin/bash
#SBATCH --job-name=mpi-pi
#SBATCH --output=mpi-pi_%j.out
#SBATCH --error=mpi-pi_%j.err
#SBATCH --time=00:30:00
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --mem=16G

module load apptainer
module load openmpi

CONTAINER=~/containers/monte-carlo-mpi.sif

echo "MPI Pi estimation: $SLURM_NTASKS total tasks across $SLURM_NNODES nodes"

# Use the HOST mpirun to launch container processes.
# This ensures proper network configuration and process placement.
mpirun -np $SLURM_NTASKS apptainer exec $CONTAINER \
    python3 /app/estimate_pi_mpi.py 100000000
```

Submit:

```bash
$ sbatch mpi_pi.slurm
Submitted batch job 1197
$ cat mpi-pi_1197.out
MPI Pi estimation: 8 total tasks across 1 nodes
Estimating Pi with 100,000,000 total samples across 8 processes
  Rank 5/8 on kla-ac-cpu-45: 9,818,024 hits from 12,500,000 samples
  Rank 6/8 on kla-ac-cpu-45: 9,813,591 hits from 12,500,000 samples
  Rank 7/8 on kla-ac-cpu-45: 9,814,575 hits from 12,500,000 samples
  Rank 1/8 on kla-ac-cpu-45: 9,817,978 hits from 12,500,000 samples
  Rank 2/8 on kla-ac-cpu-45: 9,818,049 hits from 12,500,000 samples
  Rank 3/8 on kla-ac-cpu-45: 9,818,775 hits from 12,500,000 samples
  Rank 4/8 on kla-ac-cpu-45: 9,817,634 hits from 12,500,000 samples
  Estimate: 3.14142368
  Error:    0.00016897
  Time:     2.563s
  Speedup:  8 processes
  Rank 0/8 on kla-ac-cpu-45: 9,816,966 hits from 12,500,000 samples
```

See each rank report its hostname — ranks on the same node share a hostname, ranks on different nodes report different hostnames. This confirms MPI is communicating across nodes.

## GPU Containers

GPU containers let you run CUDA workloads (deep learning, molecular dynamics, etc.) inside a container. Apptainer exposes the host's NVIDIA GPUs to the container with the `--nv` flag.

### The Concept

The `--nv` flag tells Apptainer to bind-mount the host's NVIDIA driver libraries and GPU devices into the container. The container must include CUDA libraries that are compatible with the host's NVIDIA driver version. As a rule: the host driver must be **equal to or newer** than the CUDA version in the container.

You don't need to install NVIDIA drivers inside the container — `--nv` injects them from the host at runtime.

### The Example: GPU Matrix Benchmark

We'll create a container that benchmarks GPU performance with a matrix multiplication using PyTorch, then compare it to CPU performance.

On your workstation, create `gpu_benchmark.py`:

```python
#!/usr/bin/env python3
"""Benchmark matrix multiplication on CPU vs GPU."""

import torch
import time
import argparse
import os

def benchmark(device, size, iterations):
    """Run matrix multiplication benchmark on the given device."""
    a = torch.randn(size, size, device=device)
    b = torch.randn(size, size, device=device)

    # Warm-up
    torch.matmul(a, b)
    if device.type == "cuda":
        torch.cuda.synchronize()

    start = time.time()
    for _ in range(iterations):
        torch.matmul(a, b)
    if device.type == "cuda":
        torch.cuda.synchronize()
    elapsed = time.time() - start

    # FLOPS for matrix multiplication: 2 * N^3 per multiply
    flops = 2 * size**3 * iterations / elapsed
    return elapsed, flops

def main():
    parser = argparse.ArgumentParser(description="GPU matrix multiplication benchmark")
    parser.add_argument("--size", type=int, default=4096, help="Matrix size NxN")
    parser.add_argument("--iterations", type=int, default=10)
    parser.add_argument("--no-gpu", action="store_true", help="Skip GPU benchmark")
    args = parser.parse_args()

    job_id = os.environ.get("SLURM_JOB_ID", "local")
    print(f"Matrix Benchmark (Job: {job_id})")
    print(f"  PyTorch: {torch.__version__}")
    print(f"  Matrix size: {args.size}x{args.size}")
    print(f"  Iterations: {args.iterations}")
    print()

    # CPU benchmark
    cpu_time, cpu_flops = benchmark(torch.device("cpu"), args.size, args.iterations)
    print(f"  CPU: {cpu_time:.3f}s ({cpu_flops/1e9:.1f} GFLOPS)")

    # GPU benchmark
    if not args.no_gpu and torch.cuda.is_available():
        print(f"  CUDA: {torch.version.cuda}")
        for i in range(torch.cuda.device_count()):
            props = torch.cuda.get_device_properties(i)
            print(f"  GPU {i}: {props.name} ({props.total_memory / 1e9:.1f} GB)")

        gpu_time, gpu_flops = benchmark(torch.device("cuda"), args.size, args.iterations)
        print(f"  GPU: {gpu_time:.3f}s ({gpu_flops/1e12:.2f} TFLOPS)")
        print(f"  Speedup: {cpu_time/gpu_time:.1f}x")
    elif args.no_gpu:
        print("  GPU: skipped (--no-gpu)")
    else:
        print("  GPU: not available. Did you use the --nv flag?")

if __name__ == "__main__":
    main()
```

Create the `Dockerfile`:

```dockerfile
FROM nvidia/cuda:12.2.0-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python3 \
        python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu121

WORKDIR /app
COPY gpu_benchmark.py .

CMD ["python3", "gpu_benchmark.py"]
```

Build and push:

```bash
$ docker build -t yourusername/gpu-benchmark:0.1 .
$ docker push yourusername/gpu-benchmark:0.1
```

On ACE HPC, pull the image and create `gpu-bench.slurm`:

```bash
#!/bin/bash
#SBATCH --job-name=gpu-bench
#SBATCH --output=gpu-bench_%j.out
#SBATCH --error=gpu-bench_%j.err
#SBATCH --time=00:15:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --gres=gpu:1
#SBATCH --partition=gpu

module load apptainer

CONTAINER=~/containers/gpu-benchmark.sif

echo "GPU Benchmark - Job $SLURM_JOB_ID on $(hostname)"

# The --nv flag exposes the host GPU to the container
apptainer exec --nv $CONTAINER python3 /app/gpu_benchmark.py --size 8192 --iterations 20
```

Submit:

```bash
$ sbatch gpu-bench.slurm
```

The output will show CPU GFLOPS vs GPU TFLOPS — typically a 30–100x speedup for matrix operations, depending on the GPU model and matrix size.

Without `--nv`, the container cannot see the GPU and `torch.cuda.is_available()` returns `False`. This is the most common mistake when running GPU containers.

<!-- TODO: Add a screenshot showing the GPU benchmark output comparing CPU vs GPU performance -->

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| `command not found` inside container | Binary isn't in the container's `$PATH` | Check with `apptainer exec container.sif which python` or use the full path |
| GPU not detected | Missing `--nv` flag | Add `--nv` to the `apptainer exec` command |
| GPU not detected | No GPU allocated by SLURM | Add `#SBATCH --gres=gpu:1` and `#SBATCH --partition=gpu` |
| MPI processes all on same node | Not using host MPI launcher | Use `mpirun -np $SLURM_NTASKS apptainer exec ...` not `apptainer exec ... mpirun` |
| Host environment leaking in | Host `$PATH` or Python paths interfere | Use `--cleanenv` to start with a clean environment |

## Quick Reference

```bash
# Load the module
module load apptainer

# Pull a Docker image
apptainer pull docker://image:tag
apptainer pull custom_name.sif docker://image:tag

# Run a command in a container
apptainer exec image.sif command args

# Interactive shell
apptainer shell image.sif

# Run with GPU
apptainer exec --nv image.sif command

# Run with custom bind mounts
apptainer exec --bind /host/path:/container/path:ro image.sif command

# Run with clean environment
apptainer exec --cleanenv image.sif command

# Pass environment variables
apptainer exec --env KEY=VALUE image.sif command

# Inspect image metadata
apptainer inspect image.sif

# Manage cache
apptainer cache list
apptainer cache clean
```

---

*ABI Summer School 2026 · Week 1: Linux & HPC*
