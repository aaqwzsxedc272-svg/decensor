# Jasna on a cloud GPU

A small Docker wrapper for running the official [Jasna](https://github.com/Kruk2/jasna) Linux NVIDIA release on a rented GPU machine. It downloads the official release on first start and runs Jasna's existing command-line interface; it does not modify or repackage Jasna.

> **This is a GPU worker, not a hosted website.** You connect to your cloud machine with its terminal/SSH, place media in `workspace/`, and run Jasna there. Nothing opens an unauthenticated upload or processing endpoint to the internet.

## What you need

- A Linux x86-64 cloud VM/pod with an NVIDIA GPU supported by Jasna. The GPU must be passed through to the container; host NVIDIA driver **580+** is required.
- Docker Engine, Docker Compose v2, and NVIDIA Container Toolkit (for a self-managed VM). A cloud provider's custom-container GPU template may supply these for you.
- About **80 GB of local disk** for the release, models, and model-engine compilation. The first startup downloads several GB and the first model/engine setup can take a while.
- Jasna itself recommends RTX-class GPUs; data-center GPUs such as A100, H100 and B200 are not supported. Review the official [system requirements](https://github.com/Kruk2/jasna#what-you-need) and [cloud GPU notes](https://github.com/Kruk2/jasna/blob/main/docs/en/cloud.md) before renting.

The default runtime is pinned to Jasna **v0.12.3**. That is the version used by the official Linux NVIDIA bundle configuration in this project. You can pin another published release with `JASNA_VERSION` (for example `v0.12.2`) or opt into the latest release with `JASNA_VERSION=latest`.

## Run on a GPU VM with Docker Compose

Clone this repository on the GPU machine, or copy it there, then:

```bash
mkdir -p workspace
# Copy/upload your source video to ./workspace/input.mp4 first.
docker compose run --rm jasna bash
```

The first run fetches the official Linux NVIDIA release from GitHub, verifies that the expected files are present, and installs Jasna on the container's local disk. Inside the shell:

```bash
# Optional: activate supporter models without putting the code in shell history.
read -rsp "License code: " JASNA_LICENSE_CODE; echo
jasna --license-code "$JASNA_LICENSE_CODE"
unset JASNA_LICENSE_CODE

# Free BasicVSR++ restoration
jasna --input /workspace/input.mp4 --output /workspace/restored.mp4

# Exit when done. The output is in ./workspace/restored.mp4 on the host.
exit
```

The supporter license code is optional; BasicVSR++ is free. Follow Jasna's official [license and cloud guidance](https://github.com/Kruk2/jasna/blob/main/docs/en/cloud.md) for activation and model choices. In particular, supporter models need internet access while in use, and LTX is currently not supported on RunPod/Modal (the upstream guide recommends Vast for LTX).

You can run a one-off job without opening a shell:

```bash
docker compose run --rm jasna jasna \
  --input /workspace/input.mp4 \
  --output /workspace/restored.mp4 \
  --restoration-model-name basicvsrpp
```

Compose mounts `./workspace` for input/output and keeps Jasna's activation configuration in a private Docker named volume. The application and generated GPU engines stay on the container's local disk, not on the mounted media folder. Recreating the container removes those local files, so first startup/model preparation may need to happen again. Do not share or publish the `jasna-config` volume.

### Change Jasna version

```bash
JASNA_VERSION=v0.12.2 docker compose run --rm jasna jasna --version
```

The first build only creates the small OS wrapper image; the multi-gigabyte Jasna runtime download happens when the container starts. For repeat jobs, keep using the same container/pod so its local installation and compiled engines survive.

## Run on a cloud provider

For a provider that accepts a custom Docker image, build this image on a machine with Docker, publish it to a registry the provider can pull from, then select that image in a GPU pod. Configure the pod to:

1. Use an NVIDIA GPU with the supported driver and expose all driver capabilities (`NVIDIA_DRIVER_CAPABILITIES=all`).
2. Keep the image's writable container filesystem on local SSD (at least 80 GB); do not install Jasna under a network-mounted workspace.
3. Mount a private media folder at `/workspace` and, if you want activation to survive pod restarts, persist `/root/jasna-config` as a **private** volume. Do not expose ports; use the provider's terminal or SSH.
4. Start the container with its default command (`bash`) or override it with a Jasna CLI command. The entrypoint installs the selected official release before starting that command.

Build the image with:

```bash
docker build -t YOUR-REGISTRY/jasna-cloud:0.12.3 .
docker push YOUR-REGISTRY/jasna-cloud:0.12.3
```

Cloud-provider container and volume settings vary. The upstream guide has provider-specific caveats and a direct install path if a provider does not support custom images: [Jasna Cloud GPUs](https://github.com/Kruk2/jasna/blob/main/docs/en/cloud.md).

## Troubleshooting

- **`nvidia-smi` or GPU unavailable in the container:** fix GPU passthrough/NVIDIA Container Toolkit at the host or pod level. This image cannot install a host driver.
- **Driver too old / unsupported GPU:** choose a supported RTX-class GPU and host driver 580 or newer.
- **No video encoder:** some rented GPUs cannot encode video. Test the machine with Jasna's [official encoder check](https://github.com/Kruk2/jasna/blob/main/docs/en/cloud.md#check-the-video-encoder) before activating a license.
- **Not enough disk:** use a larger local SSD. The official NVIDIA release archive itself is several gigabytes, and extraction plus model/engine files need additional space.
- **LTX does not start:** check Jasna's current cloud limitations; some providers inject libraries that are incompatible with LTX. BasicVSR++ has broader provider support.

## License and upstream

Jasna's public application is licensed under [AGPL-3.0](https://github.com/Kruk2/jasna/blob/main/LICENSE). Model files and bundled third-party components have their own terms; see upstream [licensing](https://github.com/Kruk2/jasna/blob/main/LICENSING.md). This repository contains only the Docker wrapper and fetches official runtime archives directly from [Kruk2/jasna releases](https://github.com/Kruk2/jasna/releases).
